from generators import action, build, csv_ints, header, msg


READ_FUNCTION_CODES = (1,)
WRITE_FUNCTION_CODES = (2, 3, 4, 5)
DEFAULT_PORT = 20000


def function_codes(rule):
    configured = csv_ints(rule.get("function_codes"), "DNP3 function code")
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


def object_groups(rule):
    return csv_ints(rule.get("dnp3_object_group"), "DNP3 object group")


def generate(rule_index, rule):
    src_ip, dst_ip, dst_port = header(rule, "tcp", DEFAULT_PORT)
    act = action(rule)
    result = []
    functions = function_codes(rule)
    groups = object_groups(rule)
    sequence = functions or [None]
    group_sequence = groups or [None]

    serial = 0
    for function_code in sequence:
        for group in group_sequence:
            options = ["flow:to_server,established", "app-layer-protocol:dnp3"]
            suffix = ""
            if function_code is not None:
                options.append("dnp3_func:%d" % function_code)
                suffix = "fc %d" % function_code
            if group is not None:
                options.append("dnp3_obj:%d,0" % group)
                suffix = ("%s group %d" % (suffix, group)).strip()
            result.append(build(
                act,
                "tcp",
                src_ip,
                dst_ip,
                dst_port,
                msg(rule, suffix),
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
        "IndProto default DNP3 block",
        sid,
        ["flow:to_server,established", "app-layer-protocol:dnp3"],
    )]
