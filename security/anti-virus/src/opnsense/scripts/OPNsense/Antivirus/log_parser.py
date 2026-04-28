#!/usr/local/bin/python3

import os
import re
import sqlite3
import time
import xml.etree.ElementTree as ET


ACCESS_LOG = "/var/log/c-icap/access.log"
CONFIG_FILE = "/conf/config.xml"
DB_DIR = "/var/db/antivirus"
DB_FILE = os.path.join(DB_DIR, "events.db")
LINE_RE = re.compile(
    r"(?P<date>[^,]+),\s*(?P<src_ip>[^,]+),\s*(?P<method>[^,]+),\s*"
    r"(?P<url>.*?),\s*VIRUS FOUND:\s*(?P<signature>.+)$"
)


def config_value(path, default=""):
    try:
        root = ET.parse(CONFIG_FILE).getroot()
    except (ET.ParseError, FileNotFoundError):
        return default

    node = root.find(path)
    return node.text.strip() if node is not None and node.text else default


def retention_days():
    try:
        return int(config_value("./OPNsense/antivirus/general/log_retention_days", "90"))
    except ValueError:
        return 90


def parse_timestamp(value):
    value = value.strip()
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y/%m/%d %H:%M:%S", "%a %b %d %H:%M:%S %Y"):
        try:
            return int(time.mktime(time.strptime(value, fmt)))
        except ValueError:
            pass
    try:
        return int(float(value))
    except ValueError:
        return int(time.time())


def init_db():
    os.makedirs(DB_DIR, mode=0o750, exist_ok=True)
    with sqlite3.connect(DB_FILE) as db:
        db.execute(
            """
            CREATE TABLE IF NOT EXISTS detections (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts INTEGER NOT NULL,
                src_ip TEXT,
                url TEXT,
                signature TEXT,
                action TEXT DEFAULT 'blocked'
            )
            """
        )
        db.execute("CREATE INDEX IF NOT EXISTS idx_ts ON detections(ts)")
        db.execute("CREATE INDEX IF NOT EXISTS idx_src_ip ON detections(src_ip)")
        db.execute("CREATE INDEX IF NOT EXISTS idx_sig ON detections(signature)")
        db.commit()


def insert_detection(match):
    with sqlite3.connect(DB_FILE) as db:
        db.execute(
            "INSERT INTO detections (ts, src_ip, url, signature, action) VALUES (?, ?, ?, ?, ?)",
            (
                parse_timestamp(match.group("date")),
                match.group("src_ip").strip(),
                match.group("url").strip(),
                match.group("signature").strip(),
                "blocked",
            ),
        )
        cutoff = int(time.time()) - retention_days() * 86400
        db.execute("DELETE FROM detections WHERE ts < ?", (cutoff,))
        db.commit()


def follow(path):
    position = 0
    while True:
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as handle:
                handle.seek(position)
                while True:
                    line = handle.readline()
                    if line:
                        position = handle.tell()
                        yield line.rstrip("\n")
                    else:
                        time.sleep(1)
                        if not os.path.exists(path) or os.path.getsize(path) < position:
                            position = 0
                            break
        except FileNotFoundError:
            time.sleep(2)


def main():
    init_db()
    for line in follow(ACCESS_LOG):
        match = LINE_RE.search(line)
        if match:
            insert_detection(match)


if __name__ == "__main__":
    main()
