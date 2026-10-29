"""Behavioral checks for the local reimbursement MVP; no real financial data."""
import copy
import csv
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from my_tool.core.checks import check_claim
from my_tool.core.ledger import EventLedger


def valid_claim():
    return {
        "id": "TEST-001",
        "employee_id": "EMP-TEST",
        "travel_date": "2026-10-20",
        "amount": "100.00",
        "project_codes": ["P-1"],
        "attachments": ["invoice", "travel_approval"],
        "allocations": [{"project_code": "P-1", "amount": "100.00"}],
        "policy_id": "TEST-TRAVEL",
    }


def valid_policy():
    return {
        "policy_id": "TEST-TRAVEL",
        "version": "2026-test-1",
        "effective_from": "2026-01-01",
        "effective_to": "2026-12-31",
        "project_codes": ["P-1", "P-2"],
        "clause": "Synthetic test clause: retain invoice and travel approval.",
        "confirmed": True,
    }


class ClaimChecksTests(unittest.TestCase):
    def setUp(self):
        self.claim = valid_claim()
        self.policies = [valid_policy()]

    def assert_manual(self, claim=None, policies=None):
        result = check_claim(
            self.claim if claim is None else claim,
            self.policies if policies is None else policies,
        )
        self.assertEqual(result["status"], "NEEDS_MANUAL_REVIEW")
        self.assertTrue(result["issues"])
        self.assertTrue(all(i.get("code") and i.get("message") for i in result["issues"]))
        return result

    def test_valid_claim_is_ready_for_human_review_not_approved(self):
        result = check_claim(self.claim, self.policies)
        self.assertEqual(result["claim_id"], "TEST-001")
        self.assertEqual(result["status"], "READY_FOR_REVIEW")
        self.assertEqual(result["issues"], [])
        self.assertEqual(result["policy"]["version"], "2026-test-1")
        self.assertTrue(result["source_preserved"])

    def test_each_missing_required_field_requires_manual_review(self):
        for field in valid_claim():
            with self.subTest(field=field):
                claim = valid_claim()
                del claim[field]
                self.assert_manual(claim)

    def test_each_missing_required_attachment_requires_manual_review(self):
        for attachment in ("invoice", "travel_approval"):
            with self.subTest(attachment=attachment):
                claim = valid_claim()
                claim["attachments"].remove(attachment)
                self.assert_manual(claim)

    def test_invalid_money_is_not_accepted(self):
        for amount in ("NaN", "Infinity", "-1.00", "0.00", "12.345", "not-money"):
            with self.subTest(amount=amount):
                claim = valid_claim()
                claim["amount"] = amount
                claim["allocations"][0]["amount"] = amount
                self.assert_manual(claim)

    def test_allocation_total_must_match_original_amount(self):
        self.claim["allocations"][0]["amount"] = "99.99"
        self.assert_manual()

    def test_allocation_project_must_be_declared(self):
        self.claim["allocations"][0]["project_code"] = "UNDECLARED"
        self.assert_manual()

    def test_multi_project_allocation_always_requires_human_confirmation(self):
        self.claim["project_codes"] = ["P-1", "P-2"]
        self.claim["allocations"] = [
            {"project_code": "P-1", "amount": "60.00"},
            {"project_code": "P-2", "amount": "40.00"},
        ]
        self.assert_manual()

    def test_overlapping_policy_versions_are_not_selected_automatically(self):
        newer = copy.deepcopy(self.policies[0])
        newer["version"] = "2026-test-2"
        newer["effective_from"] = "2026-10-01"
        self.policies.append(newer)
        self.assertIsNone(self.assert_manual()["policy"])

    def test_no_applicable_policy_requires_manual_review(self):
        self.policies[0]["effective_to"] = "2026-09-30"
        self.assertIsNone(self.assert_manual()["policy"])

    def test_unconfirmed_policy_is_not_used(self):
        self.policies[0]["confirmed"] = False
        self.assertIsNone(self.assert_manual()["policy"])

    def test_policy_end_date_is_inclusive(self):
        self.claim["travel_date"] = "2026-12-31"
        self.assertEqual(check_claim(self.claim, self.policies)["status"], "READY_FOR_REVIEW")

    def test_check_does_not_mutate_original_claim_or_policy(self):
        original_claim = copy.deepcopy(self.claim)
        original_policies = copy.deepcopy(self.policies)
        check_claim(self.claim, self.policies)
        self.assertEqual(self.claim, original_claim)
        self.assertEqual(self.policies, original_policies)


COLUMNS = ["event_id", "claim_id", "event_type", "event_time", "source", "source_version"]


def event(event_id, kind, when, claim_id="TEST-001"):
    return {
        "event_id": event_id,
        "claim_id": claim_id,
        "event_type": kind,
        "event_time": when,
        "source": "TEST-ERP",
        "source_version": "snapshot-1",
    }


class EventLedgerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.db = self.directory / "events.db"
        self.ledger = EventLedger(str(self.db))
        self.addCleanup(self.close_ledger)

    def close_ledger(self):
        if self.ledger is not None:
            self.ledger.close()
            self.ledger = None

    def import_rows(self, rows, name="input.csv"):
        path = self.directory / name
        with path.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=COLUMNS)
            writer.writeheader()
            writer.writerows(rows)
        return self.ledger.import_csv(str(path))

    def baseline_events(self):
        return [
            event("e1", "submitted", "2026-10-20T09:00:00+08:00"),
            event("e2", "initial_approved", "2026-10-21T09:00:00+08:00"),
            event("e3", "project_confirmed", "2026-10-21T12:00:00+08:00"),
            event("e4", "review_approved", "2026-10-22T09:00:00+08:00"),
            event("e5", "paid", "2026-10-23T09:00:00+08:00"),
        ]

    def test_out_of_order_csv_reconstructs_timeline_and_distinct_durations(self):
        result = self.import_rows(list(reversed(self.baseline_events())))
        self.assertEqual(result["imported"], 5)
        self.assertEqual([x["event_id"] for x in self.ledger.timeline("TEST-001")],
                         ["e1", "e2", "e3", "e4", "e5"])
        metrics = self.ledger.metrics("TEST-001")
        self.assertEqual(metrics["review_hours"], 48)
        self.assertEqual(metrics["payment_hours"], 72)

    def test_reimport_is_idempotent_and_data_persists_after_reopen(self):
        rows = self.baseline_events()
        self.import_rows(rows)
        again = self.import_rows(rows)
        self.assertEqual(again["imported"], 0)
        self.assertEqual(again["duplicates"], 5)
        self.close_ledger()
        self.ledger = EventLedger(str(self.db))
        self.assertEqual(len(self.ledger.timeline("TEST-001")), 5)

    def test_conflicting_existing_identifier_rolls_back_entire_file(self):
        existing = event("e1", "submitted", "2026-10-20T09:00:00+08:00")
        self.import_rows([existing])
        conflict = dict(existing, event_type="paid")
        with self.assertRaises(ValueError):
            self.import_rows([
                event("new", "initial_approved", "2026-10-21T09:00:00+08:00"),
                conflict,
            ])
        self.assertEqual([x["event_id"] for x in self.ledger.timeline("TEST-001")], ["e1"])

    def test_invalid_row_does_not_leave_partial_import(self):
        for changes in ({"source_version": ""}, {"event_type": "approved_guess"}):
            with self.subTest(changes=changes):
                invalid = event("bad", "review_approved", "2026-10-22T09:00:00+08:00")
                invalid.update(changes)
                with self.assertRaises(ValueError):
                    self.import_rows([self.baseline_events()[0], invalid])
                self.assertEqual(self.ledger.timeline("TEST-001"), [])

    def test_timestamp_without_timezone_is_rejected(self):
        with self.assertRaises(ValueError):
            self.import_rows([event("e1", "submitted", "2026-10-20T09:00:00")])
        self.assertEqual(self.ledger.timeline("TEST-001"), [])

    def test_supplement_submission_does_not_count_as_review_approval(self):
        self.import_rows([
            self.baseline_events()[0],
            event("e2", "supplement_requested", "2026-10-21T09:00:00+08:00"),
            event("e3", "supplement_submitted", "2026-10-22T09:00:00+08:00"),
        ])
        metrics = self.ledger.metrics("TEST-001")
        self.assertIsNone(metrics["review_hours"])
        self.assertIsNone(metrics["payment_hours"])

    def test_different_timezone_offsets_are_ordered_by_instant(self):
        self.import_rows([
            event("e2", "review_approved", "2026-10-20T03:00:00+00:00"),
            event("e1", "submitted", "2026-10-20T10:00:00+08:00"),
        ])
        self.assertEqual([x["event_id"] for x in self.ledger.timeline("TEST-001")], ["e1", "e2"])
        self.assertEqual(self.ledger.metrics("TEST-001")["review_hours"], 1)

    def test_negative_duration_is_not_reported_as_success(self):
        self.import_rows([
            event("e1", "submitted", "2026-10-22T09:00:00+08:00"),
            event("e2", "review_approved", "2026-10-20T09:00:00+08:00"),
        ])
        self.assertIsNone(self.ledger.metrics("TEST-001")["review_hours"])

    def test_unknown_claim_has_no_fabricated_completion_time(self):
        self.assertEqual(self.ledger.timeline("NOT-FOUND"), [])
        self.assertIsNone(self.ledger.metrics("NOT-FOUND")["review_hours"])
        self.assertIsNone(self.ledger.metrics("NOT-FOUND")["payment_hours"])


if __name__ == "__main__":
    unittest.main()
