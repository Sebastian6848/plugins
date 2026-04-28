#!/usr/local/bin/python3

import datetime
import os
import socket
import subprocess
import xml.etree.ElementTree as ET


CONFIG_FILE = "/conf/config.xml"
HEALTH_LOG = "/var/db/antivirus/healthcheck.log"
CLAMD_SOCKET = "/var/run/clamav/clamd.sock"
CICAP_HOST = "127.0.0.1"
CICAP_PORT = 1344


def config_value(path, default=""):
    try:
        root = ET.parse(CONFIG_FILE).getroot()
    except (ET.ParseError, FileNotFoundError):
        return default

    node = root.find(path)
    return node.text.strip() if node is not None and node.text else default


def enabled():
    return config_value("./OPNsense/antivirus/general/enabled", "0") == "1"


def icap_port():
    value = config_value("./OPNsense/antivirus/general/icap_port", str(CICAP_PORT))
    try:
        return int(value)
    except ValueError:
        return CICAP_PORT


def tcp_connects(host, port, timeout=3):
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def write_log(message):
    os.makedirs(os.path.dirname(HEALTH_LOG), mode=0o750, exist_ok=True)
    timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
    with open(HEALTH_LOG, "a", encoding="utf-8") as handle:
        handle.write(f"{timestamp} {message}\n")


def main():
    if not enabled():
        return

    clamd_ok = os.path.exists(CLAMD_SOCKET)
    cicap_ok = tcp_connects(CICAP_HOST, icap_port())

    if clamd_ok and cicap_ok:
        write_log("ok")
        return

    write_log(f"unhealthy clamd={clamd_ok} cicap={cicap_ok}; starting antivirus")
    subprocess.run(["/usr/local/sbin/configctl", "antivirus", "start"], check=False)


if __name__ == "__main__":
    main()
