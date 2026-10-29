"""Run with python examples/demo.py; no installation or network required."""
import copy
import json
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from my_tool.core.checks import check_claim
from my_tool.core.ledger import EventLedger
from my_tool.utils.files import load_json
from my_tool.utils.console import configure_utf8_output


def main():
    configure_utf8_output()
    claim = load_json(ROOT / "data/claim.json")
    policies = load_json(ROOT / "config/policies.json")
    bad = copy.deepcopy(claim)
    bad["attachments"] = ["invoice"]
    split = copy.deepcopy(claim)
    split["project_codes"] = ["P-DEMO-01", "P-DEMO-02"]
    split["allocations"] = [{"project_code": "P-DEMO-01", "amount": "60.00"},
                            {"project_code": "P-DEMO-02", "amount": "40.00"}]
    conflict = copy.deepcopy(policies[0])
    conflict["version"] = "conflicting-demo"
    output = {
        "说明": "以下均为合成演示；READY_FOR_REVIEW仅表示可交人工审核。",
        "正常预检": check_claim(claim, policies),
        "缺少出差申请": check_claim(bad, policies),
        "跨项目人工确认": check_claim(split, policies),
        "制度版本冲突": check_claim(claim, policies + [conflict])
    }
    with tempfile.TemporaryDirectory(prefix="travel-demo-") as tmp:
        ledger = EventLedger(str(Path(tmp) / "events.db"))
        try:
            output["首次导入"] = ledger.import_csv(ROOT / "data/events.csv")
            output["重复导入"] = ledger.import_csv(ROOT / "data/events.csv")
            output["事件回放"] = ledger.timeline("DEMO-001")
            output["时长"] = ledger.metrics("DEMO-001")
        finally:
            ledger.close()
    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
