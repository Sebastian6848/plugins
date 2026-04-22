#!/usr/local/bin/python3

import ipaddress
import os
import tempfile
import xml.etree.ElementTree as ET

CONFIG_PATH = '/conf/config.xml'
OUTPUT_PATH = '/usr/local/etc/suricata/custom_industrial.rules'

L7_PROTOCOLS = {'modbus_tcp', 'dnp3', 'eip', 'mqtt'}
CANONICAL_CATEGORY_ORDER = ['read_only', 'write_single', 'write_multiple', 'diagnostic']

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
        try:
            sequence = int((item.findtext('sequence') or '99999').strip())
        except ValueError:
            sequence = 99999

        parsed.append({
            'sequence': sequence,
            'source': (item.findtext('source') or 'any').strip() or 'any',
            'destination': (item.findtext('destination') or 'any').strip() or 'any',
            'protocol': protocol,
            'description': (item.findtext('description') or '').strip(),
            'allowed_function_codes': function_values,
            'strict_dpi': strict_dpi,
        })

    parsed.sort(
        key=lambda row: (
            row['sequence'],
            row['protocol'],
            row['source'],
            row['destination'],
            row['description'],
        )
    )

    return parsed


def parse_apply_metadata():
    revision = ''
    timestamp = ''

    if not os.path.exists(CONFIG_PATH):
        return revision, timestamp

    tree = ET.parse(CONFIG_PATH)
    root = tree.getroot()
    general = root.find('./OPNsense/IndustrialWhitelist/general')
    if general is None:
        return revision, timestamp

    revision = (general.findtext('last_apply_revision') or '').strip()
    timestamp = (general.findtext('last_apply_timestamp') or '').strip()
    return revision, timestamp


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

    selected = set(categories)
    for category in CANONICAL_CATEGORY_ORDER:
        if category not in selected:
            continue
        for code in mapping.get(category, []):
            if code not in values:
                values.append(code)

    return values


def build_msg(revision, text):
    tag = revision if revision else 'unknown'
    return f'[IndustrialWhitelist][rev:{tag}] {text}'


def render_pass_rule(protocol, src, dst, function_value, sid, description, revision):
    short_desc = description if description else 'rule'
    if protocol == 'modbus_tcp':
        return (
            f'pass modbus {src} any -> {dst} 502 '
            f'(msg:"{build_msg(revision, f"L7 allow Modbus function {function_value} ({short_desc})")}"; '
            f'modbus: function {function_value}; sid:{sid}; rev:1;)'
        )

    if protocol == 'dnp3':
        return (
            f'pass dnp3 {src} any -> {dst} 20000 '
            f'(msg:"{build_msg(revision, f"L7 allow DNP3 function {function_value} ({short_desc})")}"; '
            f'dnp3_func:{function_value}; sid:{sid}; rev:1;)'
        )

    if protocol == 'eip':
        return (
            f'pass tcp {src} any -> {dst} 44818 '
            f'(msg:"{build_msg(revision, f"L7 allow EIP/CIP service {function_value} ({short_desc})")}"; '
            f'app-layer-protocol:enip; cip_service:{function_value}; sid:{sid}; rev:1;)'
        )

    return (
        f'pass tcp {src} any -> {dst} [1883,8883] '
        f'(msg:"{build_msg(revision, f"L7 allow MQTT type {function_value} ({short_desc})")}"; '
        f'app-layer-protocol:mqtt; mqtt.type:{function_value}; sid:{sid}; rev:1;)'
    )


def render_drop_rule(protocol, src, dst, sid, revision):
    if protocol == 'modbus_tcp':
        return (
            f'drop modbus {src} any -> {dst} 502 '
            f'(msg:"{build_msg(revision, "L7 blocked unauthorized Modbus command")}"; sid:{sid}; rev:1;)'
        )

    if protocol == 'dnp3':
        return (
            f'drop dnp3 {src} any -> {dst} 20000 '
            f'(msg:"{build_msg(revision, "L7 blocked unauthorized DNP3 command")}"; sid:{sid}; rev:1;)'
        )

    if protocol == 'eip':
        return (
            f'drop tcp {src} any -> {dst} [44818,2222] '
            f'(msg:"{build_msg(revision, "L7 blocked unauthorized EIP/CIP operation")}"; app-layer-protocol:enip; sid:{sid}; rev:1;)'
        )

    return (
        f'drop tcp {src} any -> {dst} [1883,8883] '
        f'(msg:"{build_msg(revision, "L7 blocked unauthorized MQTT operation")}"; app-layer-protocol:mqtt; sid:{sid}; rev:1;)'
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


def merge_anti_spoof_policy(policy, protocol, strict_dpi):
    wanted_action = 'drop' if strict_dpi else 'alert'

    for tuple_item in anti_spoof_tuples(protocol):
        key = (tuple_item['proto'], tuple_item['port'], tuple_item['app'])
        previous = policy.get(key)
        if previous == 'drop':
            continue
        if previous is None or wanted_action == 'drop':
            policy[key] = wanted_action


def render_anti_spoof_rules(policy, sid, revision):
    rendered = []
    sorted_items = sorted(policy.items(), key=lambda entry: (entry[0][0], int(entry[0][1]), entry[0][2]))

    for (proto, port, app), action in sorted_items:
        message_prefix = '[Industrial Whitelist] Blocked Forged Protocol on Port' if action == 'drop' else '[Industrial Whitelist] Alert: Non-standard Protocol on Port'
        rendered.append(
            (
                f"{action} {proto} any any -> any {port} "
                f"(msg:\"{build_msg(revision, f'{message_prefix} {port}')}\"; "
                f"app-layer-protocol:!{app}; sid:{sid}; rev:1;)"
            )
        )
        sid += 1

    return rendered, sid


def generate_rules(revision):
    compiled = []
    warnings = []
    sid = 1100000
    anti_spoof_policy = {}
    pass_seen = set()
    deny_seen = set()

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
            pass_key = (rule['protocol'], src, dst, function_value)
            if pass_key in pass_seen:
                continue

            pass_seen.add(pass_key)
            compiled.append(render_pass_rule(rule['protocol'], src, dst, function_value, sid, rule['description'], revision))
            sid += 1

        if function_values:
            deny_key = (rule['protocol'], src, dst)
            if deny_key not in deny_seen:
                deny_seen.add(deny_key)
                compiled.append(render_drop_rule(rule['protocol'], src, dst, sid, revision))
                sid += 1

        merge_anti_spoof_policy(anti_spoof_policy, rule['protocol'], rule['strict_dpi'])

    anti_spoof_rules, sid = render_anti_spoof_rules(anti_spoof_policy, sid, revision)
    compiled.extend(anti_spoof_rules)

    return compiled, warnings


def validate_compiled_rules(lines):
    for index, line in enumerate(lines):
        if line.count('(') != line.count(')'):
            raise ValueError(f'unbalanced parentheses in rule line {index + 1}')
        if 'sid:' not in line:
            raise ValueError(f'missing sid in rule line {index + 1}')


def write_output(lines, revision, timestamp):
    directory = os.path.dirname(OUTPUT_PATH)
    if directory and not os.path.exists(directory):
        os.makedirs(directory, exist_ok=True)

    validate_compiled_rules(lines)

    with tempfile.NamedTemporaryFile('w', delete=False, dir=directory, encoding='utf-8') as handle:
        tmp_path = handle.name
        handle.write('# Auto-generated by IndustrialWhitelist plugin\n')
        handle.write('# Do not edit manually\n')
        handle.write(f'# apply_revision: {revision or "unknown"}\n')
        handle.write(f'# apply_timestamp: {timestamp or "unknown"}\n\n')
        for line in lines:
            handle.write(line + '\n')

    os.replace(tmp_path, OUTPUT_PATH)


def main():
    revision, timestamp = parse_apply_metadata()
    rules, warnings = generate_rules(revision)
    write_output(rules, revision, timestamp)

    print(f'generated {len(rules)} suricata rules at {OUTPUT_PATH}')
    for warning in warnings:
        print(f'warning: {warning}')


if __name__ == '__main__':
    main()
