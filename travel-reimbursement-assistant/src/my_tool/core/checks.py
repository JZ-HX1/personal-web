"""Deterministic pre-review checks for synthetic travel claims.

These checks never approve a claim or change a source record. Amounts use
decimal strings, and policy conflicts require human resolution.
"""

from __future__ import annotations

from datetime import date
from decimal import Decimal, InvalidOperation
import re
from typing import Any


_MONEY = re.compile(r"[0-9]+(?:\.[0-9]{1,2})?\Z")
_DATE = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}\Z")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _date(value: Any) -> date | None:
    if not isinstance(value, str) or not _DATE.fullmatch(value):
        return None
    try:
        return date.fromisoformat(value)
    except ValueError:
        return None


def _money(value: Any) -> Decimal | None:
    if not isinstance(value, str) or not _MONEY.fullmatch(value.strip()):
        return None
    try:
        amount = Decimal(value.strip())
    except InvalidOperation:
        return None
    return amount if amount.is_finite() and amount > 0 else None


def check_claim(claim: dict, policies: list[dict]) -> dict:
    """Return pre-review findings without modifying either input.

    A successful result is READY_FOR_REVIEW, never an approval. All fields in
    the input contract are required. An empty policy project_codes list is
    invalid rather than an implicit wildcard. Unconfirmed applicable rules
    block selection, even if another applicable version is confirmed.
    """
    issues: list[dict[str, str]] = []

    def issue(code: str, message: str) -> None:
        issues.append({"code": code, "message": message})

    def result(claim_id: str | None, policy: dict | None = None) -> dict:
        return {
            "claim_id": claim_id,
            "status": "NEEDS_MANUAL_REVIEW" if issues else "READY_FOR_REVIEW",
            "issues": issues,
            "policy": policy,
            "source_preserved": True,
        }

    if not isinstance(claim, dict):
        issue("INVALID_CLAIM", "报销单必须为对象。")
        return result(None)

    claim_id = claim.get("id") if _text(claim.get("id")) else None
    for field in ("id", "employee_id", "policy_id"):
        if not _text(claim.get(field)):
            issue("MISSING_FIELD", f"缺少有效字段：{field}。")

    travel_date = _date(claim.get("travel_date"))
    if travel_date is None:
        issue("INVALID_TRAVEL_DATE", "出差日期须为有效的 YYYY-MM-DD 日期。")
    amount = _money(claim.get("amount"))
    if amount is None:
        issue("INVALID_AMOUNT", "报销金额须为正数十进制字符串，且最多两位小数。")

    raw_projects = claim.get("project_codes")
    valid_projects = (
        isinstance(raw_projects, list)
        and bool(raw_projects)
        and all(_text(code) for code in raw_projects)
    )
    projects: list[str] = []
    if not valid_projects:
        issue("INVALID_PROJECT_CODES", "项目编码须为非空字符串列表。")
    else:
        projects = [code.strip() for code in raw_projects]
        if len(projects) != len(set(projects)):
            issue("DUPLICATE_PROJECT_CODE", "项目编码列表存在重复项。")
    project_set = set(projects)

    attachments = claim.get("attachments")
    if not isinstance(attachments, list) or not all(_text(item) for item in attachments):
        issue("INVALID_ATTACHMENTS", "附件类型须为字符串列表。")
        attachment_types: set[str] = set()
    else:
        attachment_types = {item.strip() for item in attachments}
    for required in ("invoice", "travel_approval"):
        if required not in attachment_types:
            issue("MISSING_ATTACHMENT", f"缺少附件类型：{required}。")

    allocations = claim.get("allocations")
    allocated_projects: set[str] = set()
    # Sum integer cents: Decimal's default precision must not silently round
    # large inputs while comparing the allocation total.
    allocated_cents = 0
    allocations_valid = isinstance(allocations, list) and bool(allocations)
    if not allocations_valid:
        issue("INVALID_ALLOCATIONS", "费用分摊须为非空列表。")
    else:
        for index, allocation in enumerate(allocations, 1):
            if not isinstance(allocation, dict):
                issue("INVALID_ALLOCATION", f"第 {index} 项分摊须为对象。")
                allocations_valid = False
                continue
            code = allocation.get("project_code")
            if not _text(code):
                issue("INVALID_ALLOCATION_PROJECT", f"第 {index} 项分摊缺少项目编码。")
                allocations_valid = False
            else:
                code = code.strip()
                if code not in project_set:
                    issue("UNKNOWN_ALLOCATION_PROJECT", f"第 {index} 项分摊项目不在本单项目列表中。")
                    allocations_valid = False
                if code in allocated_projects:
                    issue("DUPLICATE_ALLOCATION_PROJECT", f"第 {index} 项重复分摊到同一项目。")
                    allocations_valid = False
                allocated_projects.add(code)
            allocation_amount = _money(allocation.get("amount"))
            if allocation_amount is None:
                issue("INVALID_ALLOCATION_AMOUNT", f"第 {index} 项分摊金额须为正数且最多两位小数。")
                allocations_valid = False
            else:
                allocated_cents += _cents(allocation_amount)
        if project_set - allocated_projects:
            issue("MISSING_PROJECT_ALLOCATION", "部分项目缺少分摊记录。")
            allocations_valid = False
    if allocations_valid and amount is not None and allocated_cents != _cents(amount):
        issue("ALLOCATION_TOTAL_MISMATCH", "分摊金额合计与报销金额不一致。")
    if len(project_set | allocated_projects) > 1:
        issue("MULTI_PROJECT_REVIEW", "跨项目分摊必须由财务人员核对依据并确认。")

    selected_policy = None
    if not isinstance(policies, list):
        issue("INVALID_POLICIES", "制度台账须为列表。")
        return result(claim_id)

    applicable: list[dict] = []
    policy_data_invalid = False
    policy_id = claim.get("policy_id")
    for index, policy in enumerate(policies, 1):
        if not isinstance(policy, dict) or not _text(policy.get("policy_id")):
            issue("INVALID_POLICY_RECORD", f"第 {index} 条制度缺少有效标识。")
            policy_data_invalid = True
            continue
        if policy.get("policy_id") != policy_id:
            continue
        start = _date(policy.get("effective_from"))
        end_raw = policy.get("effective_to")
        end = _date(end_raw) if end_raw is not None else None
        scope = policy.get("project_codes")
        valid_scope = isinstance(scope, list) and bool(scope) and all(_text(p) for p in scope)
        valid = (
            _text(policy.get("version"))
            and _text(policy.get("clause"))
            and isinstance(policy.get("confirmed"), bool)
            and start is not None
            and (end_raw is None or end is not None)
            and (start is None or end is None or end >= start)
            and valid_scope
        )
        if not valid:
            issue("INVALID_POLICY_RECORD", f"第 {index} 条候选制度的版本、条款、日期、范围或确认标记无效。")
            policy_data_invalid = True
            continue
        if travel_date is None or not project_set:
            continue
        if start <= travel_date and (end is None or travel_date <= end):
            if project_set.issubset({p.strip() for p in scope}):
                applicable.append(policy)

    if not applicable:
        issue("NO_APPLICABLE_POLICY", "未找到覆盖出差日期及全部项目的有效制度，须人工确认。")
    if len(applicable) > 1:
        issue("POLICY_CONFLICT", "存在多个适用制度版本，须由制度负责人裁定。")
    if any(not policy["confirmed"] for policy in applicable):
        issue("UNCONFIRMED_POLICY", "适用制度尚未获得人工确认，不生成自动审核结论。")
    if len(applicable) == 1 and applicable[0]["confirmed"] and not policy_data_invalid:
        policy = applicable[0]
        selected_policy = {
            "policy_id": policy["policy_id"],
            "version": policy["version"],
            "effective_from": policy["effective_from"],
            "effective_to": policy.get("effective_to"),
            "project_codes": list(policy["project_codes"]),
            "clause": policy["clause"],
            "confirmed": True,
        }
    return result(claim_id, selected_policy)


def _cents(value: Decimal) -> int:
    """Convert a validated nonnegative fixed-point Decimal exactly."""
    _, digits, exponent = value.as_tuple()
    coefficient = 0
    for digit in digits:
        coefficient = coefficient * 10 + digit
    return coefficient * (10 ** (exponent + 2))
