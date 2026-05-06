from generators import action, build, header, msg


DEFAULT_PORT = 102


def operations(access):
    if access == "read":
        return (("read", "04"),)
    if access == "write":
        return (("write", "05"),)
    if access == "readwrite":
        return (("read", "04"), ("write", "05"))
    raise ValueError("unsupported access value %r" % access)


def generate(rule_index, rule):
    src_ip, dst_ip, dst_port = header(rule, "tcp", DEFAULT_PORT)
    act = action(rule)
    result = []
    for index, item in enumerate(operations((rule.get("access") or "readwrite").lower())):
        name, function_byte = item
        result.append(build(
            act,
            "tcp",
            src_ip,
            dst_ip,
            dst_port,
            msg(rule, "[BETA] %s" % name),
            int(rule["sid_base"]) + index,
            [
                "flow:to_server,established",
                'content:"|03|"; depth:1',
                'content:"|02|"; offset:5; depth:1',
                'content:"|32|"; offset:7; depth:1',
                'content:"|01|"; offset:8; depth:1',
                'content:"|%s|"; offset:17; depth:1' % function_byte,
            ],
        ))
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
        "IndProto default S7comm block [BETA]",
        sid,
        ["flow:to_server,established", 'content:"|03|"; depth:1', 'content:"|32|"; offset:7; depth:1'],
    )]
