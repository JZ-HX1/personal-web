"""Offline SQLite event ledger; no ERP writes, payments, or credentials."""

from __future__ import annotations

import csv
from datetime import datetime, timezone
from pathlib import Path
import sqlite3


FIELDS = ("event_id", "claim_id", "event_type", "event_time", "source", "source_version")
EVENT_TYPES = frozenset({
    "submitted", "supplement_requested", "supplement_submitted",
    "initial_approved", "project_confirmed", "review_approved", "paid",
})


def _timestamp(value: str) -> str:
    try:
        stamp = datetime.fromisoformat(value[:-1] + "+00:00" if value.endswith("Z") else value)
        if stamp.tzinfo is None or stamp.utcoffset() is None:
            raise ValueError("missing timezone")
        return stamp.astimezone(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
    except (ValueError, OverflowError) as error:
        raise ValueError("event_time 必须为带时区的有效 ISO 日期时间。") from error


class EventLedger:
    """Import normalized events atomically; duplicates are keyed by source/id."""

    def __init__(self, db_path: str | Path):
        self._connection = sqlite3.connect(str(db_path))
        self._connection.row_factory = sqlite3.Row
        self._connection.execute("""
            CREATE TABLE IF NOT EXISTS events (
                event_id TEXT NOT NULL,
                claim_id TEXT NOT NULL,
                event_type TEXT NOT NULL,
                event_time TEXT NOT NULL,
                source TEXT NOT NULL,
                source_version TEXT NOT NULL,
                PRIMARY KEY (source, event_id)
            )
        """)
        self._connection.commit()

    def import_csv(self, path: str | Path) -> dict:
        """Import UTF-8 (optional BOM) CSV in a single transaction.

        Extra named columns are ignored. Missing fields, duplicate headers,
        malformed rows, unsupported events, and conflicting keys raise
        ValueError and roll back the entire file. Whitespace is stripped and
        timestamps are normalized to UTC before duplicate comparison.
        """
        imported = duplicates = 0
        with open(path, "r", encoding="utf-8-sig", newline="") as stream:
            reader = csv.DictReader(stream)
            headers = reader.fieldnames
            if not headers or len(set(headers)) != len(headers):
                raise ValueError("CSV 缺少表头或存在重复列名。")
            if not set(FIELDS).issubset(headers):
                raise ValueError("CSV 缺少必需列：" + ", ".join(sorted(set(FIELDS) - set(headers))))
            with self._connection:
                for row in reader:
                    if None in row:
                        raise ValueError(f"CSV 第 {reader.line_num} 行的列数超出表头。")
                    event: dict[str, str] = {}
                    for field in FIELDS:
                        value = row.get(field)
                        if not isinstance(value, str) or not value.strip():
                            raise ValueError(f"CSV 第 {reader.line_num} 行缺少有效字段：{field}。")
                        event[field] = value.strip()
                    if event["event_type"] not in EVENT_TYPES:
                        raise ValueError(f"CSV 第 {reader.line_num} 行含未知事件类型。")
                    event["event_time"] = _timestamp(event["event_time"])
                    existing = self._connection.execute(
                        "SELECT * FROM events WHERE source = ? AND event_id = ?",
                        (event["source"], event["event_id"]),
                    ).fetchone()
                    if existing is not None:
                        if dict(existing) != event:
                            raise ValueError(f"CSV 第 {reader.line_num} 行与已存在事件键冲突；整批导入已撤回。")
                        duplicates += 1
                        continue
                    self._connection.execute(
                        "INSERT INTO events (event_id, claim_id, event_type, event_time, source, source_version) "
                        "VALUES (?, ?, ?, ?, ?, ?)",
                        tuple(event[field] for field in FIELDS),
                    )
                    imported += 1
        return {"imported": imported, "duplicates": duplicates}

    def timeline(self, claim_id: str) -> list[dict]:
        """Return a claim's events in UTC chronological order."""
        if not isinstance(claim_id, str) or not claim_id.strip():
            raise ValueError("claim_id 必须为非空字符串。")
        rows = self._connection.execute(
            "SELECT * FROM events WHERE claim_id = ? ORDER BY event_time, event_id, source",
            (claim_id.strip(),),
        ).fetchall()
        return [dict(row) for row in rows]

    def metrics(self, claim_id: str) -> dict:
        """Elapsed calendar hours, not queue time or an inferred approval.

        Measures from the first submitted event to the first explicit review
        approval / paid event. Missing or contradictory milestones yield null.
        No business-day calendar or three-day success threshold is assumed.
        """
        events = self.timeline(claim_id)
        first: dict[str, datetime] = {}
        for event in events:
            first.setdefault(event["event_type"], datetime.fromisoformat(event["event_time"].replace("Z", "+00:00")))
        result = {"review_hours": None, "payment_hours": None, "issues": []}
        submitted = first.get("submitted")
        review = first.get("review_approved")
        paid = first.get("paid")
        if submitted is None:
            result["issues"].append("MISSING_SUBMITTED_EVENT")
            return result
        review_valid = review is not None
        if review is None:
            result["issues"].append("MISSING_REVIEW_APPROVED_EVENT")
        elif review < submitted:
            review_valid = False
            result["issues"].append("REVIEW_BEFORE_SUBMISSION")

        # Validate available forward approval milestones; missing intermediate
        # events are not fabricated. Supplement events never imply approval.
        chain = [first[key] for key in ("submitted", "initial_approved", "project_confirmed", "review_approved") if key in first]
        if any(later < earlier for earlier, later in zip(chain, chain[1:])):
            review_valid = False
            result["issues"].append("INCONSISTENT_APPROVAL_ORDER")
        if review_valid:
            result["review_hours"] = (review - submitted).total_seconds() / 3600
        if paid is None:
            result["issues"].append("MISSING_PAID_EVENT")
        elif not review_valid:
            result["issues"].append("PAYMENT_WITHOUT_VALID_REVIEW")
        elif paid < review or paid < submitted:
            result["issues"].append("PAYMENT_BEFORE_REVIEW")
        else:
            result["payment_hours"] = (paid - submitted).total_seconds() / 3600
        return result

    def close(self) -> None:
        self._connection.close()

    def __enter__(self) -> "EventLedger":
        return self

    def __exit__(self, exc_type, exc_value, traceback) -> None:
        self.close()
