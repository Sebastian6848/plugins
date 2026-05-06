#!/usr/local/bin/python3

import importlib
import os
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, time
from pathlib import Path


DEFAULT_CONFIG_PATH = Path("/conf/config.xml")
LEGACY_CONFIG_PATH = Path("/usr/local/etc/OPNsense/IndProto/IndProto.xml")
CONFIG_PATH = Path(os.environ["INDPROTO_CONFIG"]) if "INDPROTO_CONFIG" in os.environ else None
RULES_PATH = Path(os.environ.get(
    "INDPROTO_RULES",
    "/usr/local/etc/suricata/opnsense.rules/indproto.rules",
))
SURICATA_YAML = Path(os.environ.get(
    "INDPROTO_SURICATA_YAML",
    "/usr/local/etc/suricata/suricata.yaml",
))
RULES_INCLUDE = os.environ.get("INDPROTO_RULES_INCLUDE", "indproto.rules")
CRON_PATH = Path(os.environ.get("INDPROTO_CRON", "/etc/cron.d/indproto"))

SID_RANGES = {
    "modbus": 1000000,
    "nclink": 2000000,
    "dnp3": 3000000,
    "s7comm": 4000000,
}
DEFAULT_BLOCK_SID = 9990000
PROTOCOLS = tuple(SID_RANGES.keys())


def text(node, name, default=""):
    found = node.find(name)
    if found is None or found.text is None:
        return default
    return found.text.strip()


def is_enabled(value):
    return value.strip().lower() in ("1", "true", "yes", "on")


def load_config(path):
    if path is None:
        path = DEFAULT_CONFIG_PATH if DEFAULT_CONFIG_PATH.exists() else LEGACY_CONFIG_PATH
    if not path.exists():
        raise FileNotFoundError("%s not found" % path)
    root = ET.parse(path).getroot()
    indproto = root if root.tag == "IndProto" else root.find("./OPNsense/IndProto")
    if indproto is None:
        indproto = root.find("./IndProto")
    if indproto is None:
        indproto = root.find(".//IndProto")
    if indproto is None:
        raise ValueError("missing <IndProto> configuration node")
    return indproto


def ensure_rule_file_is_loaded(yaml_path, include_line):
    if not yaml_path.exists():
        return False

    content = yaml_path.read_text()
    lines = content.splitlines()
    if any(line.strip() == "- %s" % include_line for line in lines):
        return False

    insert_at = None
    in_rule_files = False
    rule_indent = 0
    last_item = None

    for index, line in enumerate(lines):
        stripped = line.strip()
        if not in_rule_files:
            if stripped == "rule-files:":
                in_rule_files = True
                rule_indent = len(line) - len(line.lstrip())
                insert_at = index + 1
            continue

        if not stripped or stripped.startswith("#"):
            continue

        indent = len(line) - len(line.lstrip())
        if indent <= rule_indent and not stripped.startswith("- "):
            break
        if stripped.startswith("- "):
            last_item = index
            insert_at = index + 1

    entry = " " * (rule_indent + 2) + "- %s" % include_line
    if insert_at is None:
        if lines and lines[-1].strip():
            lines.append("")
        lines.extend(["rule-files:", "  - %s" % include_line])
    elif last_item is None:
        lines.insert(insert_at, entry)
    else:
        lines.insert(insert_at, entry)

    yaml_path.write_text("\n".join(lines) + "\n")
    return True


def parse_clock(value):
    if value == "":
        return None
    try:
        hour, minute = value.split(":", 1)
        return time(int(hour), int(minute))
    except ValueError as exc:
        raise ValueError("invalid time range value %r, expected HH:MM" % value) from exc


def in_time_range(start_value, end_value, now=None):
    start = parse_clock(start_value)
    end = parse_clock(end_value)
    if start is None and end is None:
        return True

    current = (now or datetime.now()).time()
    if start is None:
        return current <= end
    if end is None:
        return current >= start
    if start <= end:
        return start <= current <= end
    return current >= start or current <= end


def node_to_rule(node, rule_index):
    protocol = text(node, "protocol", "modbus").lower()
    if protocol not in PROTOCOLS:
        raise ValueError("unsupported protocol %r in rule %d" % (protocol, rule_index))

    rule = {
        "uuid": node.get("uuid", ""),
        "sid_base": SID_RANGES[protocol] + rule_index * 100,
    }
    for name in (
        "enabled",
        "description",
        "protocol",
        "src_ip",
        "dst_ip",
        "dst_port",
        "action",
        "access",
        "function_codes",
        "dnp3_object_group",
        "modbus_unit_id",
        "time_range_start",
        "time_range_end",
        "log_only",
    ):
        rule[name] = text(node, name, "")
    rule["protocol"] = protocol
    return rule


def update_cron(time_rules_present):
    if not time_rules_present:
        if CRON_PATH.exists():
            CRON_PATH.unlink()
        return False

    content = (
        "SHELL=/bin/sh\n"
        "PATH=/etc:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin\n"
        "* * * * * root /usr/local/sbin/configctl indproto reload\n"
    )
    CRON_PATH.parent.mkdir(parents=True, exist_ok=True)
    if not CRON_PATH.exists() or CRON_PATH.read_text() != content:
        CRON_PATH.write_text(content)
        return True
    return False


def default_block_rules(enabled_protocols, default_action):
    if default_action != "block":
        return []

    result = []
    for index, protocol in enumerate(sorted(enabled_protocols)):
        module = importlib.import_module("generators.%s" % protocol)
        if hasattr(module, "default_block"):
            result.extend(module.default_block(DEFAULT_BLOCK_SID + index, default_action))
    return result


def generate_rules(indproto):
    general = indproto.find("general")
    if general is None:
        raise ValueError("missing <general> configuration node")

    default_action = text(general, "default_action", "pass").lower()
    if default_action not in ("pass", "block"):
        raise ValueError("unsupported default_action %r" % default_action)

    rules = []
    enabled_protocols = set()
    time_rules_present = False
    for rule_index, node in enumerate(indproto.findall("./rules/rule")):
        if not is_enabled(text(node, "enabled", "0")):
            continue

        rule = node_to_rule(node, rule_index)
        has_time_range = bool(rule["time_range_start"] or rule["time_range_end"])
        time_rules_present = time_rules_present or has_time_range
        if has_time_range and not in_time_range(rule["time_range_start"], rule["time_range_end"]):
            continue

        module = importlib.import_module("generators.%s" % rule["protocol"])
        generated = module.generate(rule_index, rule)
        if generated:
            enabled_protocols.add(rule["protocol"])
            rules.extend(generated)

    rules.extend(default_block_rules(enabled_protocols, default_action))
    return rules, time_rules_present


def main():
    try:
        indproto = load_config(CONFIG_PATH)
        general = indproto.find("general")
        if general is None:
            raise ValueError("missing <general> configuration node")

        if not is_enabled(text(general, "enabled", "0")):
            RULES_PATH.parent.mkdir(parents=True, exist_ok=True)
            RULES_PATH.write_text("")
            update_cron(False)
            print("generated 0 indproto rules")
            return 0

        rules, time_rules_present = generate_rules(indproto)
        RULES_PATH.parent.mkdir(parents=True, exist_ok=True)
        RULES_PATH.write_text("\n".join(rules) + ("\n" if rules else ""))
        loaded = ensure_rule_file_is_loaded(SURICATA_YAML, RULES_INCLUDE)
        cron_updated = update_cron(time_rules_present)
        suffix = " and updated suricata.yaml" if loaded else ""
        if cron_updated:
            suffix += " and updated cron"
        print("generated %d indproto rules%s" % (len(rules), suffix))
        return 0
    except Exception as exc:
        print("indproto rule generation failed: %s" % exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
