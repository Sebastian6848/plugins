from generators import action, build, csv_ints, header, msg


READ_FUNCTION_CODES = (1, 2, 3, 4, 7, 11, 17, 24)
WRITE_FUNCTION_CODES = (5, 6, 15, 16, 22, 23)
DEFAULT_PORT = 502


def function_codes(rule):
    configured = csv_ints(rule.get("function_codes"), "Modbus function code")
    if configured:
        return configured

    access = (rule.get("access") or "readwrite").lower()
    if access == "read":
        return READ_FUNCTION_CODES
    if access == "write":
        return WRITE_FUNCTION_CODES
    if access == "readwrite":
        return []
    raise ValueError("unsupported access value %r" % access)


def unit_values(value):
    value = (value or "").strip()
    if not value:
        return [None]
    if "-" in value:
        start, end = value.split("-", 1)
        start = int(start, 10)
        end = int(end, 10)
        if start > end:
            raise ValueError("invalid Modbus unit range %r" % value)
        return list(range(start, end + 1))
    return [int(value, 10)]


def modbus_options(function_code=None, unit_id=None):
    options = ["app-layer-protocol:modbus"]
    if unit_id is not None:
        if unit_id < 0 or unit_id > 255:
            raise ValueError("Modbus unit id out of range: %d" % unit_id)
        options.append("modbus.unit_id:%d" % unit_id)
    if function_code is not None:
        options.append("modbus: function %d" % function_code)
    return options


def generate(rule_index, rule):
    src_ip, dst_ip, dst_port = header(rule, "tcp", DEFAULT_PORT)
    act = action(rule)
    result = []
    units = unit_values(rule.get("modbus_unit_id"))
    functions = function_codes(rule)
    sequence = functions or [None]

    serial = 0
    for unit_id in units:
        for function_code in sequence:
            options = ["flow:to_server,established"]
            options.extend(modbus_options(function_code, unit_id))
            suffix = ""
            if function_code is not None:
                suffix += " fc %d" % function_code
            if unit_id is not None:
                suffix += " unit %d" % unit_id
            result.append(build(
                act,
                "tcp",
                src_ip,
                dst_ip,
                dst_port,
                msg(rule, suffix.strip()),
                int(rule["sid_base"]) + serial,
                options,
            ))
            serial += 1
    return result


def default_block(sid, default_action):
    if default_action != "block":
        return []
    return [build(
        "drop",
        "tcp",
        "any",
        "any",
        str(DEFAULT_PORT),
        "IndProto default Modbus block",
        sid,
        ["flow:to_server,established", "app-layer-protocol:modbus"],
    )]
