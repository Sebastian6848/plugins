import html


ACTION_MAP = {
    "pass": "pass",
    "block": "drop",
}


def clean_message(value):
    value = " ".join((value or "industrial protocol rule").split())
    return html.escape(value.replace('"', "'"), quote=False)


def suricata_address(value):
    value = (value or "").strip()
    if value in ("", "*", "0.0.0.0/0", "::/0"):
        return "any"
    return value


def suricata_port(value, default):
    value = (value or "").strip()
    if value in ("", "*"):
        return str(default)
    return value


def action(rule):
    if (rule.get("log_only") or "").strip() in ("1", "true", "yes", "on"):
        return "alert"
    value = (rule.get("action") or "pass").lower()
    if value not in ACTION_MAP:
        raise ValueError("unsupported action %r" % value)
    return ACTION_MAP[value]


def msg(rule, suffix=""):
    description = rule.get("description") or "industrial protocol rule"
    tags = []
    if (rule.get("log_only") or "").strip() in ("1", "true", "yes", "on"):
        tags.append("[LOG_ONLY]")
    if suffix:
        tags.append(suffix)
    if tags:
        description = "%s %s" % (description, " ".join(tags))
    return clean_message("IndProto %s" % description)


def csv_ints(value, field_name, minimum=0, maximum=255):
    if not (value or "").strip():
        return []
    result = []
    for item in value.split(","):
        item = item.strip()
        if not item:
            continue
        try:
            parsed = int(item, 10)
        except ValueError as exc:
            raise ValueError("invalid %s value %r" % (field_name, item)) from exc
        if parsed < minimum or parsed > maximum:
            raise ValueError("%s value out of range: %d" % (field_name, parsed))
        result.append(parsed)
    return result


def header(rule, proto, default_port):
    return (
        suricata_address(rule.get("src_ip")),
        suricata_address(rule.get("dst_ip")),
        suricata_port(rule.get("dst_port"), default_port),
    )


def build(action_value, proto, src_ip, dst_ip, dst_port, message, sid, options=None):
    opts = ['msg:"%s"' % clean_message(message)]
    if options:
        opts.extend(options)
    opts.extend(["sid:%d" % sid, "rev:1"])
    return "%s %s %s any -> %s %s (%s;)" % (
        action_value,
        proto,
        src_ip,
        dst_ip,
        dst_port,
        "; ".join(opts),
    )
