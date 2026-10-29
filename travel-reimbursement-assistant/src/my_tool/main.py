"""Local command line interface. Never writes to ERP/OA or payment systems."""
import argparse
import json
import sqlite3
import sys
from pathlib import Path

from .core.checks import check_claim
from .core.ledger import EventLedger
from .utils.files import load_json


def main(argv=None):
    parser = argparse.ArgumentParser(description="差旅报销教学原型：预检和事件回放")
    sub = parser.add_subparsers(dest="command", required=True)
    check = sub.add_parser("check", help="预检JSON单据，不执行审批")
    check.add_argument("claim")
    check.add_argument("--policies", required=True)
    ingest = sub.add_parser("import-events", help="原子导入CSV事件到本地SQLite")
    ingest.add_argument("csv")
    ingest.add_argument("--db", default=".local/events.db")
    for name in ("timeline", "metrics"):
        cmd = sub.add_parser(name)
        cmd.add_argument("claim_id")
        cmd.add_argument("--db", default=".local/events.db")
    args = parser.parse_args(argv)
    try:
        if args.command == "check":
            result = check_claim(load_json(args.claim), load_json(args.policies))
        else:
            path = Path(args.db)
            if args.command != "import-events" and not path.is_file():
                raise ValueError("本地台账不存在，请先 import-events")
            if args.command == "import-events":
                path.parent.mkdir(parents=True, exist_ok=True)
            ledger = EventLedger(str(path))
            try:
                if args.command == "import-events":
                    result = ledger.import_csv(args.csv)
                elif args.command == "timeline":
                    result = ledger.timeline(args.claim_id)
                else:
                    result = ledger.metrics(args.claim_id)
            finally:
                ledger.close()
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (ValueError, OSError, sqlite3.Error) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
