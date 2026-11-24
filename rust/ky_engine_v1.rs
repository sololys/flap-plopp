//! KY Engine v1 (κ_27) — Fail-Closed Meta-Engine Kernel (Zero-Float Reference)
//! Authority: NONE | Architecture: x_{t+1} = Ω(Π_K(Φ(x_t)))
//! Lifecycle: ○ (RAW) -> ◇ (ESTIMATE) -> □ (STRUCT) -> ⬡ (VIABILITY) -> ◉ (COMMITTED)

#![forbid(unsafe_code)]

use std::collections::HashMap;

// ============================================================================
// DOMENE & TYPER
// ============================================================================

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LifecycleState {
    Raw,       // ○
    Estimate,  // ◇
    Struct,    // □
    Viability, // ⬡
    Committed, // ◉
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GateStatus {
    Open,
    Hold,
    Kill,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FailureCode {
    None,
    IllegalStateTransition,
    SyntaxError,
    StructureInvalid,
    HashChainBroken,
    Inadmissible,
    AuditFailed,
    NonReproducible,
    HighUncertainty,
}

#[derive(Debug, Clone)]
pub struct Record {
    pub object_id: u64,
    pub payload: String,
    pub lifecycle_state: LifecycleState,
    pub gate_status: GateStatus,
    pub structure_valid: bool,
    pub admissibility_flag: bool,
    pub audit_required: bool,
    pub audit_pass: bool,
    pub reproducible: bool,
    pub uncertainty_high: bool,
    pub irreversible: bool,
    pub failure_code: FailureCode,
    pub integrity_hash: u64,
}

#[derive(Debug, Clone)]
pub struct WitnessEvent {
    pub event_id: u64,
    pub object_id: u64,
    pub prev_hash: u64,
    pub event_hash: u64,
    pub operation: &'static str,
    pub result: GateStatus,
    pub reason_code: FailureCode,
    pub timestamp: u64,
}

// ============================================================================
// 1. PARSER — Leser KY-setning og rå input
// ============================================================================

pub struct RawInput {
    pub object_id: u64,
    pub expression: String,
    pub audit_flag: bool,        // #
    pub irreversible_flag: bool, // !
}

pub struct Parser;

impl Parser {
    /// Parser en KY-streng: f.eks. "object:light_bridge | anchored | audit_signed # ! ▶"
    pub fn parse(object_id: u64, input: &str) -> Result<RawInput, FailureCode> {
        let trimmed = input.trim();
        if trimmed.is_empty() {
            return Err(FailureCode::SyntaxError);
        }

        let audit_flag = trimmed.contains('#');
        let irreversible_flag = trimmed.contains('!');
        let execute_flag = trimmed.contains('▶');

        if !execute_flag {
            return Err(FailureCode::SyntaxError);
        }

        Ok(RawInput {
            object_id,
            expression: trimmed.to_string(),
            audit_flag,
            irreversible_flag,
        })
    }
}

// ============================================================================
// 2. TYPECHECKER — Verifiserer at tilstandsoverganger er lovlige (T_K)
// ============================================================================

pub struct Typechecker;

impl Typechecker {
    /// Kun ○ -> ◇ -> □ -> ⬡ -> ◉ er tillatt. Alt annet gir KILL.
    pub fn verify_transition(
        from: LifecycleState,
        to: LifecycleState,
    ) -> Result<LifecycleState, FailureCode> {
        match (from, to) {
            (LifecycleState::Raw, LifecycleState::Estimate) => Ok(to),
            (LifecycleState::Estimate, LifecycleState::Struct) => Ok(to),
            (LifecycleState::Struct, LifecycleState::Viability) => Ok(to),
            (LifecycleState::Viability, LifecycleState::Committed) => Ok(to),
            _ => Err(FailureCode::IllegalStateTransition),
        }
    }
}

// ============================================================================
// 3. GENERATOR (Φ) — Genererer kandidattilstand (RAW -> ESTIMATE)
// ============================================================================

pub struct GeneratorPhi;

impl GeneratorPhi {
    pub fn generate(raw: RawInput) -> Result<Record, FailureCode> {
        let next_state = Typechecker::verify_transition(
            LifecycleState::Raw,
            LifecycleState::Estimate,
        )?;

        Ok(Record {
            object_id: raw.object_id,
            payload: raw.expression,
            lifecycle_state: next_state,
            gate_status: GateStatus::Hold,
            structure_valid: false,
            admissibility_flag: false,
            audit_required: raw.audit_flag,
            audit_pass: false,
            reproducible: false,
            uncertainty_high: false,
            irreversible: raw.irreversible_flag,
            failure_code: FailureCode::None,
            integrity_hash: 0,
        })
    }
}

// ============================================================================
// 4. PROJECTOR (Π_K) — Validerer struktur og kjerne-regler (ESTIMATE -> STRUCT -> VIABILITY)
// ============================================================================

pub trait WorldRules {
    fn check_structure(&self, payload: &str) -> bool;
    fn check_admissibility(&self, payload: &str) -> bool;
    fn check_audit(&self, payload: &str) -> bool;
    fn check_reproducible(&self, payload: &str) -> bool;
    fn check_uncertainty(&self, payload: &str) -> bool;
}

pub struct ProjectorPi;

impl ProjectorPi {
    pub fn project<R: WorldRules>(
        mut candidate: Record,
        rules: &R,
        prev_hash: u64,
    ) -> Result<Record, FailureCode> {
        // Steg 1: ESTIMATE -> STRUCT
        candidate.lifecycle_state = Typechecker::verify_transition(
            candidate.lifecycle_state,
            LifecycleState::Struct,
        )?;
        candidate.structure_valid = rules.check_structure(&candidate.payload);

        // Steg 2: STRUCT -> VIABILITY
        candidate.lifecycle_state = Typechecker::verify_transition(
            candidate.lifecycle_state,
            LifecycleState::Viability,
        )?;
        candidate.admissibility_flag = rules.check_admissibility(&candidate.payload);
        candidate.audit_pass = if candidate.audit_required {
            rules.check_audit(&candidate.payload)
        } else {
            true
        };
        candidate.reproducible = rules.check_reproducible(&candidate.payload);
        candidate.uncertainty_high = rules.check_uncertainty(&candidate.payload);
        candidate.integrity_hash =
            Self::compute_hash(prev_hash, candidate.object_id, &candidate.payload);

        Ok(candidate)
    }

    /// Deterministisk FNV-1a 64-bit hash for kjedet integritet
    pub fn compute_hash(prev_hash: u64, id: u64, payload: &str) -> u64 {
        let mut hash: u64 = 0xcbf29ce484222325;
        for b in prev_hash
            .to_le_bytes()
            .iter()
            .chain(id.to_le_bytes().iter())
            .chain(payload.as_bytes())
        {
            hash ^= *b as u64;
            hash = hash.wrapping_mul(0x100000001b3);
        }
        hash
    }
}

// ============================================================================
// 5. GATE (Ω) — Avgjørelsesport: OPEN / HOLD / KILL
// ============================================================================

pub struct GateOmega;

impl GateOmega {
    pub fn evaluate(mut record: Record, hash_chain_valid: bool) -> Record {
        if !record.structure_valid {
            record.gate_status = GateStatus::Kill;
            record.failure_code = FailureCode::StructureInvalid;
        } else if !hash_chain_valid {
            record.gate_status = GateStatus::Kill;
            record.failure_code = FailureCode::HashChainBroken;
        } else if !record.admissibility_flag {
            record.gate_status = GateStatus::Kill;
            record.failure_code = FailureCode::Inadmissible;
        } else if record.audit_required && !record.audit_pass {
            record.gate_status = GateStatus::Kill;
            record.failure_code = FailureCode::AuditFailed;
        } else if !record.reproducible {
            record.gate_status = GateStatus::Kill;
            record.failure_code = FailureCode::NonReproducible;
        } else if record.uncertainty_high {
            record.gate_status = GateStatus::Hold;
            record.failure_code = FailureCode::HighUncertainty;
        } else {
            record.gate_status = GateStatus::Open;
            record.failure_code = FailureCode::None;
        }
        record
    }
}

// ============================================================================
// 6. WITNESS LOG — Hash-lenket, uforanderlig hendelseshistorikk
// ============================================================================

pub struct WitnessLog {
    pub events: Vec<WitnessEvent>,
    pub head_hash: u64,
}

impl Default for WitnessLog {
    fn default() -> Self {
        Self::new()
    }
}

impl WitnessLog {
    pub fn new() -> Self {
        Self {
            events: Vec::new(),
            head_hash: 0x0000_0000_0000_0000,
        }
    }

    pub fn verify_chain(&self) -> bool {
        let mut expected_prev = 0u64;
        for ev in &self.events {
            if ev.prev_hash != expected_prev {
                return false;
            }
            let recomputed = ProjectorPi::compute_hash(ev.prev_hash, ev.event_id, ev.operation);
            if ev.event_hash != recomputed {
                return false;
            }
            expected_prev = ev.event_hash;
        }
        expected_prev == self.head_hash
    }

    pub fn append(
        &mut self,
        object_id: u64,
        operation: &'static str,
        result: GateStatus,
        reason_code: FailureCode,
        timestamp: u64,
    ) -> u64 {
        let event_id = (self.events.len() + 1) as u64;
        let prev_hash = self.head_hash;
        let event_hash = ProjectorPi::compute_hash(prev_hash, event_id, operation);

        self.events.push(WitnessEvent {
            event_id,
            object_id,
            prev_hash,
            event_hash,
            operation,
            result,
            reason_code,
            timestamp,
        });

        self.head_hash = event_hash;
        event_hash
    }
}

// ============================================================================
// 7. COMMITTER & ENGINE LOOP — x_{t+1} = Ω(Π_K(Φ(x_t)))
// ============================================================================

pub struct KyEngine<R: WorldRules> {
    pub rules: R,
    pub world_state: HashMap<u64, Record>,
    pub blueprints: HashMap<u64, Record>,
    pub witness_log: WitnessLog,
    pub tick: u64,
}

impl<R: WorldRules> KyEngine<R> {
    pub fn new(rules: R) -> Self {
        Self {
            rules,
            world_state: HashMap::new(),
            blueprints: HashMap::new(),
            witness_log: WitnessLog::new(),
            tick: 0,
        }
    }

    pub fn step(&mut self, object_id: u64, raw_input: &str) -> GateStatus {
        self.tick += 1;

        let parsed = match Parser::parse(object_id, raw_input) {
            Ok(p) => p,
            Err(code) => {
                self.witness_log
                    .append(object_id, "PARSE", GateStatus::Kill, code, self.tick);
                return GateStatus::Kill;
            }
        };

        let candidate = match GeneratorPhi::generate(parsed) {
            Ok(c) => c,
            Err(code) => {
                self.witness_log
                    .append(object_id, "PHI_GEN", GateStatus::Kill, code, self.tick);
                return GateStatus::Kill;
            }
        };

        let structured =
            match ProjectorPi::project(candidate, &self.rules, self.witness_log.head_hash) {
                Ok(s) => s,
                Err(code) => {
                    self.witness_log
                        .append(object_id, "PI_PROJ", GateStatus::Kill, code, self.tick);
                    return GateStatus::Kill;
                }
            };

        let chain_valid = self.witness_log.verify_chain();
        let mut gated = GateOmega::evaluate(structured, chain_valid);

        match gated.gate_status {
            GateStatus::Open => {
                match Typechecker::verify_transition(
                    gated.lifecycle_state,
                    LifecycleState::Committed,
                ) {
                    Ok(committed_state) => {
                        gated.lifecycle_state = committed_state;
                        self.blueprints.remove(&object_id);
                        self.world_state.insert(object_id, gated);
                        self.witness_log.append(
                            object_id,
                            "COMMIT",
                            GateStatus::Open,
                            FailureCode::None,
                            self.tick,
                        );
                        GateStatus::Open
                    }
                    Err(code) => {
                        self.witness_log
                            .append(object_id, "TYPECHECK", GateStatus::Kill, code, self.tick);
                        GateStatus::Kill
                    }
                }
            }
            GateStatus::Hold => {
                let reason = gated.failure_code;
                self.blueprints.insert(object_id, gated);
                self.witness_log
                    .append(object_id, "FREEZE_HOLD", GateStatus::Hold, reason, self.tick);
                GateStatus::Hold
            }
            GateStatus::Kill => {
                let reason = gated.failure_code;
                self.blueprints.remove(&object_id);
                self.witness_log.append(
                    object_id,
                    "TERMINATE_KILL",
                    GateStatus::Kill,
                    reason,
                    self.tick,
                );
                GateStatus::Kill
            }
        }
    }
}

// ============================================================================
// VERIFIKASJON: RealityForgeRules & FlapPloppRules (T(T(s))=s, C(t)<R, HOLD, KILL)
// ============================================================================

struct RealityForgeRules;

impl WorldRules for RealityForgeRules {
    fn check_structure(&self, payload: &str) -> bool {
        payload.contains("object:")
    }
    fn check_admissibility(&self, payload: &str) -> bool {
        !payload.contains("infinite_gold")
    }
    fn check_audit(&self, payload: &str) -> bool {
        payload.contains("audit_signed")
    }
    fn check_reproducible(&self, _payload: &str) -> bool {
        true
    }
    fn check_uncertainty(&self, payload: &str) -> bool {
        payload.contains("unanchored")
    }
}

struct FlapPloppRules;

impl WorldRules for FlapPloppRules {
    fn check_structure(&self, payload: &str) -> bool {
        payload.contains("shift:") && payload.contains("T(T(s))=s")
    }
    fn check_admissibility(&self, payload: &str) -> bool {
        // C(t) < R (R = 100): reject overload C(t) >= R
        payload.contains("C<R") && !payload.contains("C>=R")
    }
    fn check_audit(&self, payload: &str) -> bool {
        payload.contains("witness_ok")
    }
    fn check_reproducible(&self, _payload: &str) -> bool {
        true
    }
    fn check_uncertainty(&self, payload: &str) -> bool {
        payload.contains("hold_bubble")
    }
}

fn main() {
    // Suite A: Reality Forge reference checks
    let mut rf = KyEngine::new(RealityForgeRules);
    assert_eq!(rf.step(101, "object:infinite_gold # ! ▶"), GateStatus::Kill);
    assert_eq!(
        rf.step(102, "object:light_bridge | unanchored | audit_signed # ! ▶"),
        GateStatus::Hold
    );
    assert_eq!(
        rf.step(102, "object:light_bridge | anchored | audit_signed # ! ▶"),
        GateStatus::Open
    );
    assert_eq!(rf.world_state.len(), 1);
    assert_eq!(rf.blueprints.len(), 0);
    assert!(rf.witness_log.verify_chain());

    // Illegal lifecycle transition must fail closed
    assert_eq!(
        Typechecker::verify_transition(LifecycleState::Raw, LifecycleState::Committed),
        Err(FailureCode::IllegalStateTransition)
    );

    // Suite B: Flap & Plopp four-law checks (T(T(s))=s, C(t)<R, HOLD, KILL)
    let mut fp = KyEngine::new(FlapPloppRules);
    assert_eq!(
        fp.step(201, "shift:plopp | T(T(s))=s | C>=R | witness_ok # ! ▶"),
        GateStatus::Kill
    );
    assert_eq!(
        fp.step(202, "shift:plopp | T(T(s))=s | C<R | hold_bubble | witness_ok # ! ▶"),
        GateStatus::Hold
    );
    assert_eq!(
        fp.step(202, "shift:splash | T(T(s))=s | C<R | witness_ok # ! ▶"),
        GateStatus::Open
    );
    assert_eq!(fp.world_state.len(), 1);
    assert_eq!(fp.blueprints.len(), 0);
    assert!(fp.witness_log.verify_chain());
    assert!(fp.world_state.get(&202).unwrap().irreversible);

    println!(
        "KY_ENGINE_V1_RUST_PASS rf_events={} fp_events={} chain_valid=true",
        rf.witness_log.events.len(),
        fp.witness_log.events.len()
    );
}
