#!/usr/local/bin/python3

import argparse
import hashlib
import importlib
import json
import logging
import os
import queue
import select
import signal
import socket
import sqlite3
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Dict, Set

try:
    yara_module = importlib.import_module("yara")
except Exception:
    yara_module = None


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_file(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as file_handle:
        for chunk in iter(lambda: file_handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_remove(path: str) -> None:
    try:
        os.remove(path)
    except FileNotFoundError:
        pass
    except OSError:
        logging.exception("remove failed: %s", path)


def parse_bool(value: object) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on", "y"}
    return False


class HashCache:
    def __init__(self, db_path: str, ttl_seconds: int, whitelist: Set[str]):
        self.db_path = db_path
        self.ttl_seconds = ttl_seconds
        self.whitelist = {value.lower() for value in whitelist}
        self._lock = threading.Lock()
        self._init_db()

    def _conn(self) -> sqlite3.Connection:
        return sqlite3.connect(self.db_path, timeout=5)

    def _init_db(self) -> None:
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        with self._conn() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS hash_cache (
                    sha256 TEXT PRIMARY KEY,
                    verdict TEXT NOT NULL,
                    expires_at INTEGER NOT NULL,
                    updated_at INTEGER NOT NULL
                )
                """
            )
            conn.execute("CREATE INDEX IF NOT EXISTS idx_hash_cache_expires ON hash_cache(expires_at)")

    def prune(self) -> None:
        now = int(time.time())
        with self._lock:
            with self._conn() as conn:
                conn.execute("DELETE FROM hash_cache WHERE expires_at < ?", (now,))

    def is_whitelisted(self, digest: str) -> bool:
        return digest.lower() in self.whitelist

    def is_recent_safe(self, digest: str) -> bool:
        now = int(time.time())
        with self._lock:
            with self._conn() as conn:
                row = conn.execute(
                    "SELECT verdict, expires_at FROM hash_cache WHERE sha256 = ?",
                    (digest.lower(),),
                ).fetchone()
        return row is not None and row[0] == "safe" and int(row[1]) >= now

    def mark_safe(self, digest: str) -> None:
        now = int(time.time())
        expires = now + self.ttl_seconds
        with self._lock:
            with self._conn() as conn:
                conn.execute(
                    """
                    INSERT INTO hash_cache (sha256, verdict, expires_at, updated_at)
                    VALUES (?, 'safe', ?, ?)
                    ON CONFLICT(sha256) DO UPDATE SET verdict='safe', expires_at=excluded.expires_at, updated_at=excluded.updated_at
                    """,
                    (digest.lower(), expires, now),
                )


def scan_with_clamd(clamd_socket: str, file_path: str, timeout_seconds: int = 20) -> Dict[str, str]:
    result = {"status": "error", "signature": ""}
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(timeout_seconds)
        client.connect(clamd_socket)
        payload = f"SCAN {file_path}\n".encode("utf-8")
        client.sendall(payload)

        response = b""
        while True:
            chunk = client.recv(4096)
            if not chunk:
                break
            response += chunk
            if b"\n" in response:
                break

    text = response.decode("utf-8", errors="ignore").strip()
    if text.endswith("OK"):
        result["status"] = "clean"
        return result

    if "FOUND" in text:
        result["status"] = "infected"
        marker = ": "
        if marker in text:
            signature = text.split(marker, 1)[1].replace(" FOUND", "").strip()
            result["signature"] = signature
        return result

    result["signature"] = text
    return result


def scan_with_yara_cli(yara_bin: str, rules_path: str, file_path: str, timeout_seconds: int = 20) -> Dict[str, str]:
    result = {"status": "error", "signature": ""}
    try:
        proc = subprocess.run(
            [yara_bin, "-w", rules_path, file_path],
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
        )
    except Exception as exc:
        result["signature"] = str(exc)
        return result

    stdout_text = (proc.stdout or "").strip()
    stderr_text = (proc.stderr or "").strip()

    if stdout_text:
        first_line = stdout_text.splitlines()[0]
        rule_name = first_line.split()[0].strip() if first_line else ""
        result["status"] = "infected"
        result["signature"] = rule_name or "yara_match"
        return result

    if proc.returncode in (0, 1) and not stderr_text:
        result["status"] = "clean"
        return result

    result["signature"] = stderr_text or f"yara_exit_{proc.returncode}"
    return result


def extract_source_ip(file_path: str) -> str:
    sidecar = f"{file_path}.meta"
    if os.path.exists(sidecar):
        try:
            with open(sidecar, "r", encoding="utf-8") as file_handle:
                data = json.load(file_handle)
            if isinstance(data, dict) and isinstance(data.get("source_ip"), str):
                return data["source_ip"].strip()
        except Exception:
            logging.exception("failed to parse sidecar metadata: %s", sidecar)
    return ""


@dataclass
class ScanTask:
    file_path: str
    digest: str
    source_ip: str


class AntiVirusEngine:
    def __init__(self, config: Dict[str, object]):
        self.config = config
        self.extract_dir = "/var/run/av_extract"
        self.max_file_size_bytes = int(config.get("max_file_size_mb", 10)) * 1024 * 1024
        self.queue_size = int(config.get("queue_size", 50))
        self.worker_threads = int(config.get("worker_threads", 4))
        self.block_duration_seconds = int(config.get("block_duration_seconds", 3600))
        self.response_mode = str(config.get("response_mode", "block_ip")).strip().lower()
        if self.response_mode not in {"block_ip", "alert_only", "drop_only"}:
            self.response_mode = "block_ip"
        self.enable_yara = parse_bool(config.get("enable_yara", False))
        self.yara_rules_path = str(config.get("yara_rules_path", "/usr/local/share/antivirus/yara/signature-base.yar"))
        self.yara_cli = "/usr/local/bin/yara"
        self.yara_runtime = "disabled"
        self.yara_compiled = None
        self.clamd_socket = "/var/run/clamav/clamd.sock"
        self.events_log = str(config.get("events_log", "/var/log/antivirus_events.log"))
        self.stats_file = str(config.get("stats_file", "/var/run/antivirus/stats.json"))
        self.task_queue: "queue.Queue[ScanTask]" = queue.Queue(maxsize=self.queue_size)
        self.stop_event = threading.Event()
        self.workers = []
        self.scan_thread: threading.Thread | None = None
        self.kqueue: select.kqueue | None = None
        self.kqueue_fd: int | None = None
        self.known_files: Dict[str, tuple[int, int]] = {}
        self.stats_lock = threading.Lock()
        self.stats = {
            "started_at": utc_now(),
            "queued": 0,
            "scanned": 0,
            "infected": 0,
            "clean": 0,
            "dropped_queue_full": 0,
            "dropped_oversize": 0,
            "dropped_cached": 0,
            "dropped_errors": 0,
            "blocked_ips": 0,
            "yara_infected": 0,
            "alert_only_actions": 0,
            "drop_only_actions": 0,
        }

        whitelist = set(config.get("whitelist", [])) if isinstance(config.get("whitelist", []), list) else set()
        self.cache = HashCache(
            db_path=str(config.get("cache_db", "/var/run/antivirus/hash_cache.db")),
            ttl_seconds=int(config.get("cache_ttl_seconds", 86400)),
            whitelist=whitelist,
        )

        os.makedirs(self.extract_dir, exist_ok=True)
        os.makedirs(os.path.dirname(self.events_log), exist_ok=True)
        os.makedirs(os.path.dirname(self.stats_file), exist_ok=True)
        self.init_yara_runtime()

    def init_yara_runtime(self) -> None:
        if not self.enable_yara:
            return

        if not os.path.isfile(self.yara_rules_path):
            logging.warning("yara enabled but rules file missing: %s", self.yara_rules_path)
            self.enable_yara = False
            return

        if yara_module is not None:
            try:
                self.yara_compiled = yara_module.compile(filepath=self.yara_rules_path)
                self.yara_runtime = "python"
                logging.info("yara runtime enabled via python module")
                return
            except Exception:
                logging.exception("failed to compile yara rules via python module")

        if os.path.isfile(self.yara_cli) and os.access(self.yara_cli, os.X_OK):
            self.yara_runtime = "cli"
            logging.info("yara runtime enabled via cli")
            return

        logging.warning("yara enabled but runtime unavailable (missing python yara module and cli binary)")
        self.enable_yara = False

    def scan_with_yara(self, file_path: str) -> Dict[str, str]:
        if not self.enable_yara:
            return {"status": "clean", "signature": ""}

        if self.yara_runtime == "python" and self.yara_compiled is not None:
            try:
                matches = self.yara_compiled.match(file_path, timeout=20)
                if matches:
                    signature = ",".join([match.rule for match in matches[:3]])
                    return {"status": "infected", "signature": signature or "yara_match"}
                return {"status": "clean", "signature": ""}
            except Exception as exc:
                return {"status": "error", "signature": str(exc)}

        if self.yara_runtime == "cli":
            return scan_with_yara_cli(self.yara_cli, self.yara_rules_path, file_path)

        return {"status": "error", "signature": "yara_runtime_unavailable"}

    def update_stats(self, key: str, delta: int = 1) -> None:
        with self.stats_lock:
            self.stats[key] = int(self.stats.get(key, 0)) + delta
            self.stats["updated_at"] = utc_now()
            with open(self.stats_file, "w", encoding="utf-8") as file_handle:
                json.dump(self.stats, file_handle, indent=2, ensure_ascii=False)

    def write_event(self, payload: Dict[str, str]) -> None:
        payload["timestamp"] = utc_now()
        with open(self.events_log, "a", encoding="utf-8") as file_handle:
            file_handle.write(json.dumps(payload, ensure_ascii=False) + "\n")

    def enqueue_if_needed(self, file_path: str) -> None:
        if not os.path.isfile(file_path):
            return
        if file_path.endswith(".meta"):
            return

        try:
            size = os.path.getsize(file_path)
            if size <= 0:
                safe_remove(file_path)
                return
            if size > self.max_file_size_bytes:
                self.update_stats("dropped_oversize")
                safe_remove(file_path)
                return

            digest = sha256_file(file_path)
            if self.cache.is_whitelisted(digest) or self.cache.is_recent_safe(digest):
                self.update_stats("dropped_cached")
                safe_remove(file_path)
                return

            task = ScanTask(file_path=file_path, digest=digest, source_ip=extract_source_ip(file_path))
            try:
                self.task_queue.put_nowait(task)
                self.update_stats("queued")
            except queue.Full:
                self.update_stats("dropped_queue_full")
                safe_remove(file_path)
                logging.warning("scan queue full, dropping %s", file_path)
        except Exception:
            self.update_stats("dropped_errors")
            logging.exception("enqueue failed for %s", file_path)
            safe_remove(file_path)

    def block_ip(self, source_ip: str) -> None:
        if not source_ip:
            return
        try:
            subprocess.run(
                [
                    "/usr/local/sbin/configctl",
                    "antivirus",
                    "block_ip",
                    source_ip,
                    str(self.block_duration_seconds),
                ],
                check=False,
                timeout=10,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            self.update_stats("blocked_ips")
        except Exception:
            logging.exception("failed to block source ip %s", source_ip)

    def handle_infected(self, source_ip: str) -> str:
        if self.response_mode == "alert_only":
            self.update_stats("alert_only_actions")
            return "alert_only"

        if self.response_mode == "drop_only":
            self.update_stats("drop_only_actions")
            return "drop_only"

        self.block_ip(source_ip)
        return "block_ip"

    def worker_loop(self) -> None:
        while not self.stop_event.is_set():
            try:
                task = self.task_queue.get(timeout=1)
            except queue.Empty:
                continue

            clamd_verdict = {"status": "error", "signature": ""}
            yara_verdict = {"status": "skipped", "signature": ""}
            verdict = {"status": "error", "signature": ""}
            detection_engine = "clamd"
            response_action = "none"
            try:
                clamd_verdict = scan_with_clamd(self.clamd_socket, task.file_path)
                verdict = clamd_verdict

                if self.enable_yara and clamd_verdict["status"] in {"clean", "error"}:
                    yara_verdict = self.scan_with_yara(task.file_path)
                    if yara_verdict["status"] == "infected":
                        verdict = yara_verdict
                        detection_engine = "yara"
                        self.update_stats("yara_infected")

                if verdict["status"] == "clean":
                    if clamd_verdict["status"] == "clean" and yara_verdict["status"] in {"clean", "skipped"}:
                        self.cache.mark_safe(task.digest)
                    self.update_stats("clean")
                elif verdict["status"] == "infected":
                    self.update_stats("infected")
                    response_action = self.handle_infected(task.source_ip)
                else:
                    self.update_stats("dropped_errors")

                self.update_stats("scanned")
                self.write_event(
                    {
                        "sha256": task.digest,
                        "result": verdict["status"],
                        "detection_engine": detection_engine,
                        "response_action": response_action,
                        "signature": verdict.get("signature", ""),
                        "clamd_result": clamd_verdict.get("status", "error"),
                        "yara_result": yara_verdict.get("status", "skipped"),
                        "source_ip": task.source_ip,
                        "file_path": task.file_path,
                    }
                )
            except Exception:
                self.update_stats("dropped_errors")
                logging.exception("scan failed for %s", task.file_path)
            finally:
                safe_remove(task.file_path)
                safe_remove(f"{task.file_path}.meta")
                self.task_queue.task_done()

    def scan_extract_dir(self) -> None:
        current: Dict[str, tuple[int, int]] = {}
        try:
            with os.scandir(self.extract_dir) as entries:
                for entry in entries:
                    if not entry.is_file(follow_symlinks=False):
                        continue
                    if entry.name.endswith(".meta"):
                        continue

                    stat_result = entry.stat(follow_symlinks=False)
                    marker = (int(stat_result.st_mtime_ns), int(stat_result.st_size))
                    current[entry.path] = marker

                    if self.known_files.get(entry.path) != marker:
                        self.enqueue_if_needed(entry.path)
        except FileNotFoundError:
            os.makedirs(self.extract_dir, exist_ok=True)
        except Exception:
            logging.exception("failed to scan extract dir: %s", self.extract_dir)

        self.known_files = current

    def setup_kqueue(self) -> bool:
        if not hasattr(select, "kqueue"):
            logging.warning("kqueue not available, fallback to periodic directory scan")
            return False

        self.kqueue_fd = os.open(self.extract_dir, os.O_RDONLY)
        self.kqueue = select.kqueue()

        event = select.kevent(
            self.kqueue_fd,
            filter=select.KQ_FILTER_VNODE,
            flags=select.KQ_EV_ADD | select.KQ_EV_ENABLE | select.KQ_EV_CLEAR,
            fflags=(
                select.KQ_NOTE_WRITE
                | select.KQ_NOTE_EXTEND
                | select.KQ_NOTE_ATTRIB
                | select.KQ_NOTE_LINK
                | select.KQ_NOTE_RENAME
                | select.KQ_NOTE_DELETE
            ),
        )
        self.kqueue.control([event], 0, 0)
        return True

    def event_loop(self) -> None:
        while not self.stop_event.is_set():
            if self.kqueue is None:
                self.scan_extract_dir()
                time.sleep(1)
                continue

            try:
                events = self.kqueue.control(None, 1, 1)
                if events:
                    self.scan_extract_dir()
                    for event in events:
                        if event.fflags & (select.KQ_NOTE_DELETE | select.KQ_NOTE_RENAME):
                            if self.kqueue_fd is not None:
                                os.close(self.kqueue_fd)
                            self.kqueue_fd = os.open(self.extract_dir, os.O_RDONLY)
                            register = select.kevent(
                                self.kqueue_fd,
                                filter=select.KQ_FILTER_VNODE,
                                flags=select.KQ_EV_ADD | select.KQ_EV_ENABLE | select.KQ_EV_CLEAR,
                                fflags=(
                                    select.KQ_NOTE_WRITE
                                    | select.KQ_NOTE_EXTEND
                                    | select.KQ_NOTE_ATTRIB
                                    | select.KQ_NOTE_LINK
                                    | select.KQ_NOTE_RENAME
                                    | select.KQ_NOTE_DELETE
                                ),
                            )
                            self.kqueue.control([register], 0, 0)
                else:
                    self.scan_extract_dir()
            except FileNotFoundError:
                os.makedirs(self.extract_dir, exist_ok=True)
            except Exception:
                logging.exception("kqueue event loop error")
                time.sleep(1)

    def start(self) -> None:
        logging.info(
            "antivirusd starting, dir=%s queue=%s workers=%s yara_enabled=%s yara_runtime=%s",
            self.extract_dir,
            self.queue_size,
            self.worker_threads,
            self.enable_yara,
            self.yara_runtime,
        )
        self.cache.prune()
        self.update_stats("queued", 0)

        self.scan_extract_dir()
        self.setup_kqueue()
        self.scan_thread = threading.Thread(target=self.event_loop, daemon=True)
        self.scan_thread.start()

        for _ in range(self.worker_threads):
            worker = threading.Thread(target=self.worker_loop, daemon=True)
            worker.start()
            self.workers.append(worker)

    def stop(self) -> None:
        self.stop_event.set()

        if self.scan_thread is not None:
            self.scan_thread.join(timeout=5)

        try:
            if self.kqueue is not None:
                self.kqueue.close()
                self.kqueue = None
            if self.kqueue_fd is not None:
                os.close(self.kqueue_fd)
                self.kqueue_fd = None
        except Exception:
            logging.exception("kqueue cleanup failed")

        for worker in self.workers:
            worker.join(timeout=2)


def load_config(path: str) -> Dict[str, object]:
    with open(path, "r", encoding="utf-8") as file_handle:
        data = json.load(file_handle)
    if not isinstance(data, dict):
        raise RuntimeError("invalid config format")
    return data


def main() -> int:
    parser = argparse.ArgumentParser(description="Industrial AntiVirus sidecar daemon")
    parser.add_argument("-c", "--config", default="/usr/local/etc/antivirusd.conf")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[logging.StreamHandler(sys.stdout)],
    )

    try:
        config = load_config(args.config)
    except Exception as exc:
        logging.error("failed to load config: %s", exc)
        return 1

    if not bool(config.get("enabled", False)):
        logging.info("antivirusd disabled by config, exiting")
        return 0

    engine = AntiVirusEngine(config)
    should_stop = threading.Event()

    def on_signal(_signum, _frame):
        should_stop.set()

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)

    engine.start()
    try:
        while not should_stop.is_set():
            time.sleep(1)
    finally:
        engine.stop()
        logging.info("antivirusd stopped")

    return 0


if __name__ == "__main__":
    sys.exit(main())