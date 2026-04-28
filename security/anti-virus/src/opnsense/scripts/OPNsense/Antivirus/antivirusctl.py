#!/usr/local/bin/python3

import datetime
import hashlib
import json
import os
import re
import shutil
import socket
import sqlite3
import subprocess
import sys
import time
import xml.etree.ElementTree as ET


DB_PATH = "/var/db/opnsense-antivirus/events.sqlite"
STATE_PATH = "/var/db/opnsense-antivirus/parser_state.json"
SQUID_ICAP_PATH = "/usr/local/etc/squid/pre-auth/00-antivirus-icap.conf"
SQUID_TEST_PORT = 31289
CONFIG_XML = "/conf/config.xml"
LOG_SOURCES = {
    "cicap": [
        "/var/log/c-icap/latest.log",
        "/var/log/cicap/latest.log",
        "/var/log/c-icap/access.log",
    ],
    "clamd": [
        "/var/log/clamav/clamd.log",
        "/var/log/clamav/latest.log",
    ],
}


def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def run(command, timeout=60):
    try:
        proc = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    except Exception as exc:
        return 1, "", str(exc)


def emit(data):
    print(json.dumps(data, sort_keys=True))


def ensure_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS detections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts TEXT NOT NULL,
            src_ip TEXT,
            src_port TEXT,
            dst_host TEXT,
            url TEXT,
            filename TEXT,
            mime_type TEXT,
            file_size INTEGER,
            signature TEXT,
            action TEXT NOT NULL,
            engine TEXT,
            source_log TEXT,
            raw_line_hash TEXT UNIQUE,
            created_at TEXT NOT NULL
        )
        """
    )
    conn.commit()
    return conn


def read_config():
    defaults = {
        "enabled": "0",
        "max_scan_size_mb": "50",
        "log_retention_days": "90",
    }
    if not os.path.exists(CONFIG_XML):
        return defaults
    try:
        root = ET.parse(CONFIG_XML).getroot()
        node = root.find("./OPNsense/antivirus")
        if node is None:
            return defaults
        for child in node:
            defaults[child.tag] = child.text or ""
    except Exception:
        pass
    return defaults


def service_status(rc_name):
    rc_path = "/usr/local/etc/rc.d/%s" % rc_name
    if not os.path.exists(rc_path):
        return False
    code, stdout, stderr = run([rc_path, "status"], timeout=10)
    output = (stdout + " " + stderr).lower()
    return code == 0 and ("running" in output or "pid" in output)


def tcp_ready(host, port, timeout=2):
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def socket_ready(path):
    return os.path.exists(path)


def package_installed(pkg_name):
    if shutil.which("pkg") is None:
        return False
    code, _, _ = run(["/usr/sbin/pkg", "info", "-e", pkg_name], timeout=10)
    if code != 0:
        code, _, _ = run(["/usr/local/sbin/pkg", "info", "-e", pkg_name], timeout=10)
    return code == 0


def package_installed_any(*pkg_names):
    return any(package_installed(pkg_name) for pkg_name in pkg_names)


def start_or_reload_squid():
    reload_proxy_templates()
    valid, message = squid_config_valid()
    if not valid:
        return 1, "", message
    if service_status("squid"):
        code, stdout, stderr = squid_reconfigure()
        if code == 0 and tcp_ready("127.0.0.1", SQUID_TEST_PORT):
            return code, stdout, stderr
        rc("restart", "squid")
        if wait_tcp("127.0.0.1", SQUID_TEST_PORT, 20):
            return 0, stdout, stderr
        return 1, stdout, stderr or "squid is running but antivirus test port is not listening"
    pluginctl = "/usr/local/sbin/pluginctl"
    if os.path.exists(pluginctl):
        run([pluginctl, "-c", "webproxy", "start"], timeout=60)
    code, stdout, stderr = rc("onestart", "squid")
    if code != 0:
        code, stdout, stderr = rc("start", "squid")
    if code == 0 and wait_tcp("127.0.0.1", SQUID_TEST_PORT, 20):
        return code, stdout, stderr
    return 1, stdout, stderr or "squid antivirus test port is not listening"


def reload_squid_if_running():
    if service_status("squid"):
        reload_proxy_templates()
        valid, message = squid_config_valid()
        if not valid:
            return 1, "", message
        return squid_reconfigure()
    return 0, "", "squid is not running"


def wait_tcp(host, port, timeout):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if tcp_ready(host, port, timeout=1):
            return True
        time.sleep(1)
    return False


def reload_proxy_templates():
    configctl = "/usr/local/sbin/configctl"
    if os.path.exists(configctl):
        return run([configctl, "template", "reload", "OPNsense/Proxy"], timeout=120)
    return 1, "", "configctl is not installed"


def squid_config_valid():
    squid = "/usr/local/sbin/squid"
    if not os.path.exists(squid):
        return False, "squid binary is not installed"
    code, stdout, stderr = run([squid, "-k", "parse"], timeout=60)
    output = (stdout + "\n" + stderr).strip()
    if code == 0:
        return True, output
    fatal_patterns = [
        "FATAL:",
        "Bungled",
        "ERROR: Directive",
        "ERROR: Invalid",
        "ERROR: Unknown",
        "Cannot open",
        "not found",
    ]
    if not any(pattern.lower() in output.lower() for pattern in fatal_patterns):
        return True, output
    return False, output


def squid_reconfigure():
    squid = "/usr/local/sbin/squid"
    if not os.path.exists(squid):
        return 1, "", "squid binary is not installed"
    code, stdout, stderr = run([squid, "-k", "reconfigure"], timeout=60)
    if code == 0:
        return code, stdout, stderr
    return rc("restart", "squid")


def db_info():
    version = ""
    updated_at = ""
    if shutil.which("freshclam"):
        _, stdout, _ = run(["/usr/local/bin/freshclam", "--version"], timeout=10)
        version = stdout
    db_dir = "/var/db/clamav"
    mtimes = []
    if os.path.isdir(db_dir):
        for name in os.listdir(db_dir):
            if name.endswith((".cvd", ".cld")):
                try:
                    mtimes.append(os.path.getmtime(os.path.join(db_dir, name)))
                except OSError:
                    pass
    if mtimes:
        updated_at = datetime.datetime.fromtimestamp(max(mtimes), datetime.timezone.utc).isoformat()
    return version, updated_at


def detection_summary():
    conn = ensure_db()
    cur = conn.cursor()
    cur.execute(
        "SELECT COUNT(*) FROM detections WHERE ts >= datetime('now','-1 day') AND action IN ('blocked','test_blocked')"
    )
    last_24h = cur.fetchone()[0]
    cur.execute(
        "SELECT COUNT(*) FROM detections WHERE ts >= datetime('now','-7 day') AND action IN ('blocked','test_blocked')"
    )
    last_7d = cur.fetchone()[0]
    cur.execute("SELECT ts || ' ' || COALESCE(signature, '') FROM detections ORDER BY ts DESC LIMIT 1")
    last = cur.fetchone()
    conn.close()
    return {
        "last_24h": last_24h,
        "last_7d": last_7d,
        "last_detection": last[0] if last else None,
    }


def status():
    cfg = read_config()
    enabled = cfg.get("enabled") == "1"
    squid_running = service_status("squid")
    cicap_running = service_status("c-icap")
    clamd_running = service_status("clamav_clamd")
    cicap_listening = tcp_ready("127.0.0.1", 1344)
    clamd_tcp = tcp_ready("127.0.0.1", 3310)
    clamd_socket = socket_ready("/var/run/clamav/clamd.sock")
    db_version, db_updated_at = db_info()
    include_present = os.path.exists(SQUID_ICAP_PATH) and os.path.getsize(SQUID_ICAP_PATH) > 0
    summary = detection_summary()

    if not enabled:
        overall = "disabled"
    elif not include_present or not package_installed_any("os-squid", "os-squid-devel"):
        overall = "misconfigured"
    elif squid_running and cicap_running and cicap_listening and clamd_running and (clamd_tcp or clamd_socket):
        overall = "healthy"
    elif clamd_running and not (clamd_tcp or clamd_socket):
        overall = "starting"
    else:
        overall = "error"

    return {
        "enabled": enabled,
        "overall": overall,
        "squid": {
            "installed": package_installed("squid"),
            "plugin_installed": package_installed_any("os-squid", "os-squid-devel"),
            "running": squid_running,
            "icap_include_present": include_present,
            "icap_runtime_enabled": include_present,
        },
        "cicap": {
            "installed": package_installed("c-icap"),
            "running": cicap_running,
            "listening": cicap_listening,
            "address": "127.0.0.1",
            "port": 1344,
        },
        "clamav": {
            "installed": package_installed("clamav"),
            "clamd_running": clamd_running,
            "socket_ready": clamd_socket,
            "tcp_ready": clamd_tcp,
            "db_version": db_version,
            "db_updated_at": db_updated_at,
        },
        "detections": summary,
    }


def reload_templates():
    return run(["/usr/local/sbin/configctl", "template", "reload", "OPNsense/Antivirus"], timeout=120)


def rc(action, service):
    path = "/usr/local/etc/rc.d/%s" % service
    if os.path.exists(path):
        return run([path, action], timeout=120)
    return 1, "", "%s not installed" % service


def update_db():
    os.makedirs("/var/log/clamav", exist_ok=True)
    if shutil.which("freshclam") is None:
        return {"result": "failed", "message": "freshclam is not installed"}
    code, stdout, stderr = run(["/usr/local/bin/freshclam"], timeout=900)
    return {"result": "ok" if code in (0, 1) else "failed", "stdout": stdout, "stderr": stderr}


def wait_clamd():
    deadline = time.time() + 120
    while time.time() < deadline:
        if tcp_ready("127.0.0.1", 3310) or socket_ready("/var/run/clamav/clamd.sock"):
            return True
        time.sleep(2)
    return False


def start_services():
    cfg = read_config()
    if cfg.get("enabled") != "1":
        return status()
    if not db_info()[1]:
        update_db()
    rc("start", "clamav_freshclam")
    rc("start", "clamav_clamd")
    wait_clamd()
    rc("start", "c-icap")
    for _ in range(15):
        if tcp_ready("127.0.0.1", 1344):
            break
        time.sleep(1)
    start_or_reload_squid()
    return status()


def stop_services():
    if os.path.exists(SQUID_ICAP_PATH):
        try:
            open(SQUID_ICAP_PATH, "w").close()
        except OSError:
            pass
    reload_squid_if_running()
    rc("stop", "c-icap")
    rc("stop", "clamav_clamd")
    return status()


def apply():
    reload_templates()
    cfg = read_config()
    if cfg.get("enabled") == "1":
        return start_services()
    return stop_services()


def repair():
    reload_templates()
    rc("restart", "clamav_clamd")
    wait_clamd()
    rc("restart", "c-icap")
    start_or_reload_squid()
    parse_logs()
    return status()


def insert_event(event):
    conn = ensure_db()
    fields = [
        "ts", "src_ip", "src_port", "dst_host", "url", "filename", "mime_type",
        "file_size", "signature", "action", "engine", "source_log", "raw_line_hash", "created_at"
    ]
    values = [event.get(field) for field in fields]
    conn.execute(
        "INSERT OR IGNORE INTO detections (%s) VALUES (%s)" %
        (",".join(fields), ",".join(["?"] * len(fields))),
        values,
    )
    conn.commit()
    conn.close()


def parse_line(line, source_name, path):
    signature = None
    action = None
    src_ip = None
    url = None
    if "Eicar-Test-Signature" in line:
        signature = "Eicar-Test-Signature"
    found = re.search(r"([A-Za-z0-9_.:/ -]+) FOUND", line)
    if found:
        signature = found.group(1).strip().split()[-1]
    virus = re.search(r"virus[^A-Za-z0-9]+([A-Za-z0-9_.:-]+)", line, re.IGNORECASE)
    if not signature and virus:
        signature = virus.group(1)
    ip_match = re.search(r"(?<![0-9])((?:[0-9]{1,3}\.){3}[0-9]{1,3})(?![0-9])", line)
    if ip_match:
        src_ip = ip_match.group(1)
    url_match = re.search(r"https?://[^\s\"']+", line)
    if url_match:
        url = url_match.group(0)
    if signature:
        action = "test_blocked" if signature == "Eicar-Test-Signature" else "blocked"
    elif "error" in line.lower():
        action = "scan_error"
    if not action:
        return None
    digest = hashlib.sha256((path + line).encode()).hexdigest()
    return {
        "ts": now_iso(),
        "src_ip": src_ip,
        "url": url,
        "signature": signature,
        "action": action,
        "engine": "clamav" if source_name == "clamd" else "c-icap",
        "source_log": path,
        "raw_line_hash": digest,
        "created_at": now_iso(),
    }


def load_state():
    try:
        with open(STATE_PATH) as handle:
            return json.load(handle)
    except Exception:
        return {}


def save_state(state):
    os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
    with open(STATE_PATH, "w") as handle:
        json.dump(state, handle, sort_keys=True)


def parse_logs():
    state = load_state()
    parsed = 0
    for source_name, paths in LOG_SOURCES.items():
        for path in paths:
            if not os.path.exists(path):
                continue
            key = "%s:%s" % (source_name, path)
            stat = os.stat(path)
            last = state.get(key, {})
            offset = int(last.get("offset", 0)) if last.get("inode") == stat.st_ino else 0
            with open(path, errors="ignore") as handle:
                handle.seek(offset)
                for line in handle:
                    event = parse_line(line.strip(), source_name, path)
                    if event:
                        insert_event(event)
                        parsed += 1
                state[key] = {"inode": stat.st_ino, "offset": handle.tell()}
    save_state(state)
    retention = int(read_config().get("log_retention_days") or 90)
    conn = ensure_db()
    conn.execute("DELETE FROM detections WHERE ts < datetime('now', ?)", ("-%d day" % retention,))
    conn.commit()
    conn.close()
    return {"result": "ok", "parsed": parsed}


def dashboard():
    conn = ensure_db()
    cur = conn.cursor()
    data = detection_summary()
    cur.execute(
        "SELECT src_ip, COUNT(*) FROM detections WHERE ts >= datetime('now','-7 day') "
        "AND action IN ('blocked','test_blocked') GROUP BY src_ip ORDER BY COUNT(*) DESC LIMIT 1"
    )
    row = cur.fetchone()
    data["top_client_ip"] = "%s (%s)" % (row[0], row[1]) if row and row[0] else ""
    cur.execute(
        "SELECT signature, COUNT(*) FROM detections WHERE ts >= datetime('now','-7 day') "
        "AND action IN ('blocked','test_blocked') GROUP BY signature ORDER BY COUNT(*) DESC LIMIT 1"
    )
    row = cur.fetchone()
    data["top_signature"] = "%s (%s)" % (row[0], row[1]) if row and row[0] else ""
    conn.close()
    return data


def logs():
    conn = ensure_db()
    cur = conn.cursor()
    cur.execute(
        "SELECT ts, src_ip, url, signature, action, source_log FROM detections "
        "ORDER BY ts DESC LIMIT 100"
    )
    rows = [
        {
            "ts": row[0],
            "src_ip": row[1],
            "url": row[2],
            "signature": row[3],
            "action": row[4],
            "source_log": row[5],
        }
        for row in cur.fetchall()
    ]
    conn.close()
    return {"rows": rows}


def eicar_test():
    url = "http://secure.eicar.org/eicar.com"
    curl = shutil.which("curl") or "/usr/local/bin/curl"
    if not os.path.exists(curl):
        return {"result": "failed_unknown", "message": "curl is not installed"}
    squid_result = start_or_reload_squid()
    if squid_result[0] != 0:
        return {"result": "failed_squid", "message": squid_result[2] or squid_result[1]}
    if not tcp_ready("127.0.0.1", SQUID_TEST_PORT):
        return {"result": "failed_squid", "message": "squid antivirus test port 127.0.0.1:%d is not listening" % SQUID_TEST_PORT}
    code, stdout, stderr = run(
        [curl, "-sS", "-m", "30", "-x", "http://127.0.0.1:%d" % SQUID_TEST_PORT, "-i", url],
        timeout=40,
    )
    output = stdout + stderr
    parse_logs()
    if "Eicar-Test-Signature" in output or "virus" in output.lower() or "blocked" in output.lower():
        insert_event({
            "ts": now_iso(),
            "url": url,
            "signature": "Eicar-Test-Signature",
            "action": "test_blocked",
            "engine": "full-chain",
            "source_log": "eicar_test",
            "raw_line_hash": hashlib.sha256((now_iso() + output).encode()).hexdigest(),
            "created_at": now_iso(),
        })
        return {"result": "passed"}
    st = status()
    if not st["squid"]["running"]:
        result = "failed_squid"
    elif not st["cicap"]["listening"]:
        result = "failed_cicap"
    elif not (st["clamav"]["tcp_ready"] or st["clamav"]["socket_ready"]):
        result = "failed_clamav"
    else:
        result = "failed_unknown"
    return {"result": result, "stdout": stdout[-1000:], "stderr": stderr[-1000:]}


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    if action == "status":
        emit(status())
    elif action == "apply":
        emit(apply())
    elif action == "start":
        emit(start_services())
    elif action == "stop":
        emit(stop_services())
    elif action in ("restart", "reload"):
        emit(apply())
    elif action == "repair":
        emit(repair())
    elif action == "update_db":
        emit(update_db())
    elif action == "parse_logs":
        emit(parse_logs())
    elif action == "dashboard":
        emit(dashboard())
    elif action == "logs":
        emit(logs())
    elif action == "eicar_test":
        emit(eicar_test())
    else:
        emit({"result": "failed", "message": "unknown action"})
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
