#!/usr/local/bin/python3

import os
import sqlite3


DB_DIR = "/var/db/antivirus"
DB_FILE = os.path.join(DB_DIR, "events.db")


def main():
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


if __name__ == "__main__":
    main()
