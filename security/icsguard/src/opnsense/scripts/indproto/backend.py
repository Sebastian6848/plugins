#!/usr/local/bin/python3

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import generate_rules
import log_query


class CapabilityProbe:
    def probe(self):
        available = {
            "suricata_binary": shutil.which("suricata") is not None or Path("/usr/local/bin/suricata").exists(),
            "suricata_rc": Path("/usr/local/etc/rc.d/suricata").exists(),
            "configctl": shutil.which("configctl") is not None or Path("/usr/local/sbin/configctl").exists(),
            "rules_dir_writable": self.dir_writable(generate_rules.RULES_PATH.parent),
            "suricata_yaml": generate_rules.SURICATA_YAML.exists(),
        }
        return {
            "available": available,
            "missing": [name for name, ok in available.items() if not ok],
        }

    def dir_writable(self, path):
        path = Path(path)
        if path.exists():
            return os.access(path, os.W_OK)
        return os.access(path.parent, os.W_OK)


class ConflictDetector:
    def detect(self):
        conflicts = []
        if self.pkg_installed("os-intrusion-detection-content-et-open"):
            conflicts.append({
                "type": "plugin",
                "name": "os-intrusion-detection-content-et-open",
                "message": "additional Suricata rule content plugin detected",
            })
        return conflicts

    def pkg_installed(self, name):
        return subprocess.run(["/usr/local/sbin/pkg", "info", "-e", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


class ServiceManager:
    def restart(self):
        commands = [
            ["/usr/local/sbin/configctl", "ids", "restart"],
            ["/usr/local/sbin/pluginctl", "-s", "suricata", "restart"],
            ["/usr/sbin/service", "suricata", "restart"],
        ]
        errors = []
        for command in commands:
            if not Path(command[0]).exists():
                continue
            result = subprocess.run(command, capture_output=True, text=True)
            if result.returncode == 0:
                return ok({"data": {"method": " ".join(command)}} , "Suricata restarted")
            errors.append((result.stderr or result.stdout or "failed").strip())
        return error(errors[-1] if errors else "no Suricata restart method available")

    def status(self):
        result = subprocess.run(["/bin/pgrep", "-x", "suricata"], capture_output=True, text=True)
        pids = [int(item) for item in result.stdout.split() if item.isdigit()]
        state = "running" if pids else "stopped"
        return ok({
            "components": {"suricata": state},
            "capabilities": CapabilityProbe().probe(),
            "conflicts": ConflictDetector().detect(),
        }, "Suricata %s" % state)


class SuricataRuleBackend:
    def reload(self):
        code = generate_rules.main()
        if code != 0:
            return error("industrial protocol rule generation failed")
        result = ok({
            "capabilities": CapabilityProbe().probe(),
            "conflicts": ConflictDetector().detect(),
        }, "industrial protocol rules generated")
        return result


def ok(data=None, message="ok"):
    payload = {"status": "ok", "message": message}
    if data:
        payload.update(data)
    return payload


def error(message, data=None):
    payload = {"status": "error", "message": message}
    if data:
        payload.update(data)
    return payload


def query_logs(args):
    old_argv = sys.argv
    try:
        sys.argv = ["log_query.py"] + args
        return_code = log_query.main()
        if return_code not in (None, 0):
            return error("log query failed")
        return None
    finally:
        sys.argv = old_argv


def main(argv):
    action = argv[1] if len(argv) > 1 else "status"
    if action == "reload":
        return SuricataRuleBackend().reload()
    if action in ("restart_suricata", "restart"):
        return ServiceManager().restart()
    if action == "status":
        return ServiceManager().status()
    if action == "capabilities":
        return ok({
            "capabilities": CapabilityProbe().probe(),
            "conflicts": ConflictDetector().detect(),
        })
    if action == "log":
        logged = query_logs(argv[2:])
        return logged if logged is not None else None
    return error("unsupported action")


if __name__ == "__main__":
    result = main(sys.argv)
    if result is not None:
        print(json.dumps(result, separators=(",", ":")))
        sys.exit(1 if result.get("status") == "error" else 0)
