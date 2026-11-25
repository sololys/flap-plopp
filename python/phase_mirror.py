"""Flap & Plopp — Phase-Mirror Process Consequence Gate v0.1 (Zero-Float Reference).

Enforces the five runtime objects (Candidate, GateDecision, HPISCheck,
RuntimeResult, WitnessRecord), HPIS interlock matrix, append-only SHA-256
witness ledger, and deterministic scenario verification (Run 1 == Run 2)
using exact integer milli-units (0 float).
"""

from dataclasses import asdict, dataclass
from enum import Enum
import hashlib
import json
from typing import List, Tuple


class PortVerdict(str, Enum):
    OPEN = "OPEN"
    HOLD = "HOLD"
    KILL = "KILL"
    TRAP = "TRAP"


class RuntimeOutcome(str, Enum):
    REALIZED = "REALIZED"
    HARDWARE_INCONSISTENCY = "HARDWARE_INCONSISTENCY"
    HELD_FOR_READMISSION = "HELD_FOR_READMISSION"
    KILLED = "KILLED"
    SHADOW_ROUTED = "SHADOW_ROUTED"
    SABOTAGE_INTERLOCK_BYPASS = "SABOTAGE_INTERLOCK_BYPASS"


@dataclass(frozen=True)
class Candidate:
    candidate_id: str
    source_id: str
    action: str
    seq: int
    timestamp: str
    # L2-L4 structure, phase, and stability flags
    structure_valid: bool
    identity_valid: bool
    sequence_valid: bool
    order_valid: bool
    phase_valid: bool
    spectral_valid: bool
    # Exact integer risk vector in milli-units [0, 1000] (0 float)
    risk_milli: int
    uncertainty_milli: int
    exfiltration_milli: int
    sabotage_milli: int
    # Physical interlock line (L6): 0 or 1
    hpis_hw_enable: int


@dataclass(frozen=True)
class GateDecision:
    candidate_id: str
    verdict: PortVerdict
    reason_code: str


@dataclass(frozen=True)
class HPISCheck:
    candidate_id: str
    hpis_enable: int


@dataclass(frozen=True)
class RuntimeResult:
    candidate_id: str
    verdict: PortVerdict
    hpis_enable: int
    outcome: RuntimeOutcome
    reason_code: str


@dataclass(frozen=True)
class WitnessRecord:
    index: int
    candidate_id: str
    source_id: str
    decision: str
    hpis_state: int
    outcome: str
    reason_code: str
    timestamp: str
    prev_hash: str
    event_hash: str


def evaluate_gate(
    c: Candidate, tau_open_milli: int = 300, tau_kill_milli: int = 800
) -> GateDecision:
    # 1. Hard structure and ordering invariants -> KILL
    if not c.structure_valid:
        return GateDecision(c.candidate_id, PortVerdict.KILL, "RAW_TO_COMMIT_SHORTCUT")
    if not c.identity_valid:
        return GateDecision(c.candidate_id, PortVerdict.KILL, "INVALID_SIGNATURE")
    if not c.sequence_valid:
        return GateDecision(c.candidate_id, PortVerdict.KILL, "SEQUENCE_REPLAY")
    if not c.order_valid:
        return GateDecision(c.candidate_id, PortVerdict.KILL, "ORDER_BREACH")
    if not c.spectral_valid:
        return GateDecision(c.candidate_id, PortVerdict.KILL, "UNSTABLE_EIGENMODE")

    # 2. Exfiltration / active probing -> TRAP (mirror room, zero external consequence)
    if c.exfiltration_milli >= tau_kill_milli:
        return GateDecision(c.candidate_id, PortVerdict.TRAP, "EXFILTRATION_ATTEMPT")

    # 3. Sabotage pattern or total risk >= kill threshold -> KILL
    if c.sabotage_milli >= tau_kill_milli or c.risk_milli >= tau_kill_milli:
        return GateDecision(c.candidate_id, PortVerdict.KILL, "SABOTAGE_PATTERN")

    # 4. Unresolved phase or uncertainty/risk above tau_open -> HOLD
    if not c.phase_valid:
        return GateDecision(c.candidate_id, PortVerdict.HOLD, "PHASE_UNRESOLVED")
    if c.uncertainty_milli > tau_open_milli or c.risk_milli > tau_open_milli:
        return GateDecision(c.candidate_id, PortVerdict.HOLD, "UNCERTAINTY_ABOVE_OPEN")

    # 5. All gates passed -> OPEN (requires HPIS=1 to realize)
    return GateDecision(c.candidate_id, PortVerdict.OPEN, "LOW_RISK_PASSAGE")


def evaluate_hpis_matrix(decision: GateDecision, hpis: HPISCheck) -> RuntimeResult:
    v = decision.verdict
    hw = hpis.hpis_enable

    if v == PortVerdict.OPEN and hw == 1:
        outcome = RuntimeOutcome.REALIZED
    elif v == PortVerdict.OPEN and hw == 0:
        outcome = RuntimeOutcome.HARDWARE_INCONSISTENCY
    elif v == PortVerdict.HOLD and hw == 0:
        outcome = RuntimeOutcome.HELD_FOR_READMISSION
    elif v == PortVerdict.KILL and hw == 0:
        outcome = RuntimeOutcome.KILLED
    elif v == PortVerdict.TRAP and hw == 0:
        outcome = RuntimeOutcome.SHADOW_ROUTED
    elif v in (PortVerdict.HOLD, PortVerdict.KILL, PortVerdict.TRAP) and hw == 1:
        outcome = RuntimeOutcome.SABOTAGE_INTERLOCK_BYPASS
    else:
        outcome = RuntimeOutcome.KILLED

    return RuntimeResult(
        candidate_id=decision.candidate_id,
        verdict=v,
        hpis_enable=hw,
        outcome=outcome,
        reason_code=decision.reason_code,
    )


class WitnessLedger:
    GENESIS_HASH = "0" * 64

    def __init__(self) -> None:
        self.records: List[WitnessRecord] = []

    @staticmethod
    def _compute_hash(payload: dict) -> str:
        canonical = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
        return hashlib.sha256(canonical).hexdigest()

    def append(self, c: Candidate, res: RuntimeResult) -> WitnessRecord:
        prev_hash = self.records[-1].event_hash if self.records else self.GENESIS_HASH
        idx = len(self.records)
        base = {
            "index": idx,
            "candidate_id": c.candidate_id,
            "source_id": c.source_id,
            "decision": res.verdict.value,
            "hpis_state": res.hpis_enable,
            "outcome": res.outcome.value,
            "reason_code": res.reason_code,
            "timestamp": c.timestamp,
            "prev_hash": prev_hash,
        }
        event_hash = self._compute_hash(base)
        rec = WitnessRecord(**base, event_hash=event_hash)
        self.records.append(rec)
        return rec

    def verify(self) -> bool:
        expected_prev = self.GENESIS_HASH
        for idx, rec in enumerate(self.records):
            if rec.index != idx or rec.prev_hash != expected_prev:
                return False
            base = {
                "index": rec.index,
                "candidate_id": rec.candidate_id,
                "source_id": rec.source_id,
                "decision": rec.decision,
                "hpis_state": rec.hpis_state,
                "outcome": rec.outcome,
                "reason_code": rec.reason_code,
                "timestamp": rec.timestamp,
                "prev_hash": rec.prev_hash,
            }
            if self._compute_hash(base) != rec.event_hash:
                return False
            expected_prev = rec.event_hash
        return True


def run_mvp_scenarios() -> Tuple[List[RuntimeResult], WitnessLedger]:
    scenarios = [
        # Case 001: normal read -> OPEN + HPIS=1 -> REALIZED
        Candidate("case_001", "proc_reader", "READ_TELEMETRY", 1, "2026-11-25T01:30:00Z",
                  True, True, True, True, True, True, 50, 20, 0, 0, 1),
        # Case 002: unknown config change -> HOLD + HPIS=0 -> HELD_FOR_READMISSION
        Candidate("case_002", "agent_cfg", "SET_PARAM_X", 2, "2026-11-25T01:30:01Z",
                  True, True, True, True, False, True, 250, 450, 0, 50, 0),
        # Case 003: malicious write -> KILL + HPIS=0 -> KILLED
        Candidate("case_003", "proc_untrusted", "WRITE_PROTECTED", 3, "2026-11-25T01:30:02Z",
                  True, True, True, True, True, True, 920, 100, 0, 900, 0),
        # Case 004: exfiltration loop -> TRAP + HPIS=0 -> SHADOW_ROUTED
        Candidate("case_004", "net_worker", "POST_EXTERNAL", 4, "2026-11-25T01:30:03Z",
                  True, True, True, True, True, True, 750, 100, 950, 0, 0),
        # Case 005: physical bypass -> KILL + HPIS=1 -> SABOTAGE_INTERLOCK_BYPASS
        Candidate("case_005", "relay_override", "FORCE_RELAY_ON", 5, "2026-11-25T01:30:04Z",
                  True, True, True, True, True, True, 950, 50, 0, 950, 1),
        # Case 006: OPEN + HPIS=0 -> HARDWARE_INCONSISTENCY
        Candidate("case_006", "proc_reader", "READ_TELEMETRY", 6, "2026-11-25T01:30:05Z",
                  True, True, True, True, True, True, 50, 20, 0, 0, 0),
    ]

    ledger = WitnessLedger()
    results: List[RuntimeResult] = []
    for cand in scenarios:
        decision = evaluate_gate(cand)
        hpis = HPISCheck(cand.candidate_id, cand.hpis_hw_enable)
        res = evaluate_hpis_matrix(decision, hpis)
        ledger.append(cand, res)
        results.append(res)

    return results, ledger


if __name__ == "__main__":
    res_1, led_1 = run_mvp_scenarios()
    res_2, led_2 = run_mvp_scenarios()

    assert res_1 == res_2, "Determinism failure: Run 1 != Run 2"
    assert [r.event_hash for r in led_1.records] == [r.event_hash for r in led_2.records]
    assert led_1.verify(), "Witness chain failed verification"

    expected = [
        RuntimeOutcome.REALIZED,
        RuntimeOutcome.HELD_FOR_READMISSION,
        RuntimeOutcome.KILLED,
        RuntimeOutcome.SHADOW_ROUTED,
        RuntimeOutcome.SABOTAGE_INTERLOCK_BYPASS,
        RuntimeOutcome.HARDWARE_INCONSISTENCY,
    ]
    assert [r.outcome for r in res_1] == expected, "Scenario outcomes mismatch"

    # Tamper detection: mutating one field must break chain verification
    tampered = WitnessLedger()
    tampered.records = list(led_1.records)
    r0 = asdict(tampered.records[0])
    r0["outcome"] = "KILLED"
    tampered.records[0] = WitnessRecord(**r0)
    assert not tampered.verify(), "Tamper detection failed"

    print(
        f"PHASE_MIRROR_V0_1_PASS scenarios=6/6 deterministic=1 chain_valid=1 "
        f"tamper_detected=1 head={led_1.records[-1].event_hash[:16]}"
    )
