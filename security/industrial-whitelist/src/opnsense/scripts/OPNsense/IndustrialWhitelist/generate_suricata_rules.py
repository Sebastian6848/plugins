#!/usr/local/bin/python3

import ipaddress
import os
import xml.etree.ElementTree as ET

CONFIG_PATH = '/conf/config.xml'
OUTPUT_PATH = '/usr/local/etc/suricata/custom_industrial.rules'

L7_PROTOCOLS = {'modbus_tcp', 'dnp3', 'eip', 'mqtt'}

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

EIP_FUNCTION_MAP = {
    'read_only': ['14', '76'],
    'write_single': ['16', '77'],
    'write_multiple': ['4', '10'],
    'diagnostic': ['82'],
}

MQTT_FUNCTION_MAP = {
    'read_only': ['SUBSCRIBE', 'UNSUBSCRIBE'],
    'write_single': ['PUBLISH'],
    'write_multiple': ['PUBLISH'],
    'diagnostic': ['CONNECT', 'DISCONNECT', 'PINGREQ', 'PINGRESP'],
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
        strict_dpi = (item.findtext('StrictDPI') or '0').strip() in ('1', 'true', 'True', 'yes', 'on')

        parsed.append({
            'source': (item.findtext('source') or 'any').strip() or 'any',
            'destination': (item.findtext('destination') or 'any').strip() or 'any',
            'protocol': protocol,
            'description': (item.findtext('description') or '').strip(),
            'allowed_function_codes': function_values,
            'strict_dpi': strict_dpi,
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
    protocol_mapping = {
        'modbus_tcp': MODBUS_FUNCTION_MAP,
        'dnp3': DNP3_FUNCTION_MAP,
        'eip': EIP_FUNCTION_MAP,
        'mqtt': MQTT_FUNCTION_MAP,
    }

    mapping = protocol_mapping.get(protocol, {})

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

    if protocol == 'dnp3':
        return (
            f'pass dnp3 {src} any -> {dst} 20000 '
            f'(msg:"IW L7 allow DNP3 function {function_value} ({short_desc})"; '
            f'dnp3_func:{function_value}; sid:{sid}; rev:1;)'
        )

    if protocol == 'eip':
        return (
            f'pass tcp {src} any -> {dst} 44818 '
            f'(msg:"IW L7 allow EIP/CIP service {function_value} ({short_desc})"; '
            f'app-layer-protocol:enip; cip_service:{function_value}; sid:{sid}; rev:1;)'
        )

    return (
        f'pass tcp {src} any -> {dst} [1883,8883] '
        f'(msg:"IW L7 allow MQTT type {function_value} ({short_desc})"; '
        f'app-layer-protocol:mqtt; mqtt.type:{function_value}; sid:{sid}; rev:1;)'
    )


def render_drop_rule(protocol, src, dst, sid):
    if protocol == 'modbus_tcp':
        return (
            f'drop modbus {src} any -> {dst} 502 '
            f'(msg:"IW L7 blocked unauthorized Modbus command"; sid:{sid}; rev:1;)'
        )

    if protocol == 'dnp3':
        return (
            f'drop dnp3 {src} any -> {dst} 20000 '
            f'(msg:"IW L7 blocked unauthorized DNP3 command"; sid:{sid}; rev:1;)'
        )

    if protocol == 'eip':
        return (
            f'drop tcp {src} any -> {dst} [44818,2222] '
            f'(msg:"IW L7 blocked unauthorized EIP/CIP operation"; app-layer-protocol:enip; sid:{sid}; rev:1;)'
        )

    return (
        f'drop tcp {src} any -> {dst} [1883,8883] '
        f'(msg:"IW L7 blocked unauthorized MQTT operation"; app-layer-protocol:mqtt; sid:{sid}; rev:1;)'
    )


def anti_spoof_tuples(protocol):
    mapping = {
        'modbus_tcp': [
            {'proto': 'tcp', 'port': '502', 'app': 'modbus'},
        ],
        'dnp3': [
            {'proto': 'tcp', 'port': '20000', 'app': 'dnp3'},
            {'proto': 'udp', 'port': '20000', 'app': 'dnp3'},
        ],
        'eip': [
            {'proto': 'tcp', 'port': '44818', 'app': 'enip'},
            {'proto': 'udp', 'port': '44818', 'app': 'enip'},
            {'proto': 'udp', 'port': '2222', 'app': 'enip'},
        ],
        'mqtt': [
            {'proto': 'tcp', 'port': '1883', 'app': 'mqtt'},
            {'proto': 'tcp', 'port': '8883', 'app': 'mqtt'},
        ],
    }

    return mapping.get(protocol, [])


def render_anti_spoof_rule(protocol, strict_dpi, sid, anti_spoof_seen):
    action = 'drop' if strict_dpi else 'alert'
    message_prefix = '[Industrial Whitelist] Blocked Forged Protocol on Port' if strict_dpi else '[Industrial Whitelist] Alert: Non-standard Protocol on Port'

    rendered = []
    for tuple_item in anti_spoof_tuples(protocol):
        dedup_key = (action, tuple_item['proto'], tuple_item['port'], tuple_item['app'])
        if dedup_key in anti_spoof_seen:
            continue

        anti_spoof_seen.add(dedup_key)
        rendered.append(
            (
                f"{action} {tuple_item['proto']} any any -> any {tuple_item['port']} "
                f"(msg:\"{message_prefix} {tuple_item['port']}\"; "
                f"app-layer-protocol:!{tuple_item['app']}; sid:{sid}; rev:1;)"
            )
        )
        sid += 1

    return rendered, sid


def generate_rules():
    compiled = []
    warnings = []
    sid = 1100000
    anti_spoof_seen = set()

    for rule in parse_rules():
        src = normalize_suricata_ip(rule['source'])
        dst = normalize_suricata_ip(rule['destination'])
        if src is None or dst is None:
            warnings.append(
                f"skip L7 rule due to non-IP source/destination: {rule['source']} -> {rule['destination']}"
            )
            continue

        function_values = map_protocol_functions(rule['protocol'], rule['allowed_function_codes'])
        for function_value in function_values:
            compiled.append(render_pass_rule(rule['protocol'], src, dst, function_value, sid, rule['description']))
            sid += 1

        if function_values:
            compiled.append(render_drop_rule(rule['protocol'], src, dst, sid))
            sid += 1

        anti_spoof_rules, sid = render_anti_spoof_rule(rule['protocol'], rule['strict_dpi'], sid, anti_spoof_seen)
        compiled.extend(anti_spoof_rules)

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
