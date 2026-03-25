#!/usr/local/bin/python3

import ipaddress
import os
import xml.etree.ElementTree as ET

CONFIG_PATH = '/conf/config.xml'
OUTPUT_PATH = '/usr/local/etc/suricata/custom_industrial.rules'

L7_PROTOCOLS = {'modbus_tcp', 'dnp3'}

MODBUS_FUNCTION_MAP = {
    'read_only': ['1', '2', '3', '4'],
    'write_single': ['5', '6'],
    'write_multiple': ['15', '16'],
    'diagnostic': ['8'],
}

DNP3_FUNCTION_MAP = {
    'read_only': ['read', 'response', 'unsolicited_response'],
    'write_single': ['write', 'select', 'operate'],
    'write_multiple': ['direct_operate', 'direct_operate_nr'],
    'diagnostic': ['cold_restart', 'warm_restart'],
}


def normalize_multi_value(value):
    if value is None:
        return []
    if isinstance(value, list):
        result = []
        for item in value:
            result.extend(normalize_multi_value(item))
        return result

    text = str(value).strip()
    if not text:
        return []

    if ',' in text:
        return [part.strip() for part in text.split(',') if part.strip()]

    return [text]


def parse_rules():
    if not os.path.exists(CONFIG_PATH):
        return []

    tree = ET.parse(CONFIG_PATH)
    root = tree.getroot()

    rules_root = root.find('./OPNsense/IndustrialWhitelist/rules')
    if rules_root is None:
        return []

    parsed = []
    for item in rules_root.findall('rule'):
        enabled = (item.findtext('enabled') or '0').strip()
        if enabled in ('0', '', 'false', 'False'):
            continue

        protocol = (item.findtext('protocol') or 'modbus_tcp').strip()
        if protocol not in L7_PROTOCOLS:
            continue

        function_values = normalize_multi_value(item.findtext('AllowedFunctionCodes'))
        if not function_values:
            continue

        parsed.append({
            'source': (item.findtext('source') or 'any').strip() or 'any',
            'destination': (item.findtext('destination') or 'any').strip() or 'any',
            'protocol': protocol,
            'description': (item.findtext('description') or '').strip(),
            'allowed_function_codes': function_values,
        })

    return parsed


def normalize_suricata_ip(value):
    val = (value or 'any').strip()
    if val.lower() == 'any':
        return 'any'

    if val.startswith('<') and val.endswith('>'):
        return None

    try:
        if '/' in val:
            ipaddress.ip_network(val, strict=False)
        else:
            ipaddress.ip_address(val)
        return val
    except ValueError:
        return None


def map_protocol_functions(protocol, categories):
    values = []
    mapping = MODBUS_FUNCTION_MAP if protocol == 'modbus_tcp' else DNP3_FUNCTION_MAP

    for category in categories:
        for code in mapping.get(category, []):
            if code not in values:
                values.append(code)

    return values


def render_pass_rule(protocol, src, dst, function_value, sid, description):
    short_desc = description if description else 'rule'
    if protocol == 'modbus_tcp':
        return (
            f'pass modbus {src} any -> {dst} 502 '
            f'(msg:"IW L7 allow Modbus function {function_value} ({short_desc})"; '
            f'modbus: function {function_value}; sid:{sid}; rev:1;)'
        )

    return (
        f'pass dnp3 {src} any -> {dst} 20000 '
        f'(msg:"IW L7 allow DNP3 function {function_value} ({short_desc})"; '
        f'dnp3_func:{function_value}; sid:{sid}; rev:1;)'
    )


def render_drop_rule(protocol, src, dst, sid):
    if protocol == 'modbus_tcp':
        return (
            f'drop modbus {src} any -> {dst} 502 '
            f'(msg:"IW L7 blocked unauthorized Modbus command"; sid:{sid}; rev:1;)'
        )

    return (
        f'drop dnp3 {src} any -> {dst} 20000 '
        f'(msg:"IW L7 blocked unauthorized DNP3 command"; sid:{sid}; rev:1;)'
    )


def render_spoof_guard_rules(start_sid):
    return [
        (
            f'drop tcp any any -> any 502 '
            f'(msg:"IW L7 blocked non-Modbus protocol on 502"; app-layer-protocol:!modbus; sid:{start_sid}; rev:1;)'
        ),
        (
            f'drop tcp any any -> any 20000 '
            f'(msg:"IW L7 blocked non-DNP3 protocol on 20000/tcp"; app-layer-protocol:!dnp3; sid:{start_sid + 1}; rev:1;)'
        ),
        (
            f'drop udp any any -> any 20000 '
            f'(msg:"IW L7 blocked non-DNP3 protocol on 20000/udp"; app-layer-protocol:!dnp3; sid:{start_sid + 2}; rev:1;)'
        ),
        (
            f'drop tcp any any -> any 44818 '
            f'(msg:"IW L7 blocked non-ENIP protocol on 44818"; app-layer-protocol:!enip; sid:{start_sid + 3}; rev:1;)'
        ),
        (
            f'drop udp any any -> any 44818 '
            f'(msg:"IW L7 blocked non-ENIP protocol on 44818/udp"; app-layer-protocol:!enip; sid:{start_sid + 4}; rev:1;)'
        ),
        (
            f'drop tcp any any -> any 1883 '
            f'(msg:"IW L7 blocked non-MQTT protocol on 1883"; app-layer-protocol:!mqtt; sid:{start_sid + 5}; rev:1;)'
        ),
        (
            f'drop tcp any any -> any 8883 '
            f'(msg:"IW L7 blocked non-MQTT protocol on 8883"; app-layer-protocol:!mqtt; sid:{start_sid + 6}; rev:1;)'
        ),
    ]


def generate_rules():
    compiled = []
    warnings = []
    sid = 1100000

    for rule in parse_rules():
        src = normalize_suricata_ip(rule['source'])
        dst = normalize_suricata_ip(rule['destination'])
        if src is None or dst is None:
            warnings.append(
                f"skip L7 rule due to non-IP source/destination: {rule['source']} -> {rule['destination']}"
            )
            continue

        function_values = map_protocol_functions(rule['protocol'], rule['allowed_function_codes'])
        if not function_values:
            continue

        for function_value in function_values:
            compiled.append(render_pass_rule(rule['protocol'], src, dst, function_value, sid, rule['description']))
            sid += 1

        compiled.append(render_drop_rule(rule['protocol'], src, dst, sid))
        sid += 1

    compiled.extend(render_spoof_guard_rules(sid))

    return compiled, warnings


def write_output(lines):
    directory = os.path.dirname(OUTPUT_PATH)
    if directory and not os.path.exists(directory):
        os.makedirs(directory, exist_ok=True)

    with open(OUTPUT_PATH, 'w', encoding='utf-8') as handle:
        handle.write('# Auto-generated by IndustrialWhitelist plugin\n')
        handle.write('# Do not edit manually\n\n')
        for line in lines:
            handle.write(line + '\n')


def main():
    rules, warnings = generate_rules()
    write_output(rules)

    print(f'generated {len(rules)} suricata rules at {OUTPUT_PATH}')
    for warning in warnings:
        print(f'warning: {warning}')


if __name__ == '__main__':
    main()
