from generators import action, build, header, msg


DEFAULT_PORT = 8080


def methods(access):
    if access == "read":
        return ("GET",)
    if access == "write":
        return ("POST", "PUT")
    if access == "readwrite":
        return ("GET", "POST", "PUT")
    raise ValueError("unsupported access value %r" % access)


def generate(rule_index, rule):
    src_ip, dst_ip, dst_port = header(rule, "tcp", DEFAULT_PORT)
    act = action(rule)
    result = []
    for index, method in enumerate(methods((rule.get("access") or "readwrite").lower())):
        result.append(build(
            act,
            "http",
            src_ip,
            dst_ip,
            dst_port,
            msg(rule, method),
            int(rule["sid_base"]) + index,
            [
                "flow:to_server,established",
                "http.method",
                'content:"%s"' % method,
                "http.uri",
                'content:"/api/"',
            ],
        ))
    return result


def default_block(sid, default_action):
    if default_action != "block":
        return []
    return [build(
        "drop",
        "http",
        "any",
        "any",
        str(DEFAULT_PORT),
        "IndProto default NCLink block",
        sid,
        ["flow:to_server,established", "http.uri", 'content:"/api/"'],
    )]
