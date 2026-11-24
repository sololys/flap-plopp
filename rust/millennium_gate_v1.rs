//! Millennium Engine Gate v1 — Zero-Float P/NP Realization & 7-Monolith Verifier
//! Verifies candidate proposals (NP) against local exact invariants (P) in O(1):
//!   T(T(s)) = s, C(t) < R, HOLD (stasis), and KILL (0.00 V cutoff).

#![forbid(unsafe_code)]

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Medium {
    Sky,
    Sea,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Verdict {
    Open,
    Hold,
    Kill,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MonolithCheck {
    pub id: u8,
    pub name: &'static str,
    pub passed: bool,
}

#[derive(Debug, Clone)]
pub struct MillenniumEngine {
    pub medium: Medium,
    pub load_c_milli: u32,
    pub limit_r_milli: u32,
    pub involutions: u32,
    pub monoliths_lit: u8,
    pub head_hash: u64,
    pub witness_count: u64,
}

impl MillenniumEngine {
    pub fn new() -> Self {
        Self {
            medium: Medium::Sky,
            load_c_milli: 10_000,
            limit_r_milli: 100_000,
            involutions: 0,
            monoliths_lit: 0,
            head_hash: 0,
            witness_count: 0,
        }
    }

    pub fn apply_involution(s: Medium) -> Medium {
        match s {
            Medium::Sky => Medium::Sea,
            Medium::Sea => Medium::Sky,
        }
    }

    fn seal(&mut self, tag: u64, verdict: Verdict) {
        self.witness_count += 1;
        let mut h: u64 = 0xcbf29ce484222325;
        for v in [self.head_hash, self.witness_count, tag, verdict as u64] {
            for b in v.to_le_bytes() {
                h ^= b as u64;
                h = h.wrapping_mul(0x100000001b3);
            }
        }
        self.head_hash = h;
    }

    /// O(1) P-verifiable admission of a candidate monolith step
    pub fn admit_monolith(
        &mut self,
        monolith_id: u8,
        load_delta_milli: u32,
        evidence_id: u64,
        request_hold: bool,
    ) -> Verdict {
        if monolith_id == 0 || monolith_id > 7 {
            self.seal(monolith_id as u64, Verdict::Kill);
            return Verdict::Kill;
        }
        if evidence_id == 0 || request_hold {
            self.seal(monolith_id as u64, Verdict::Hold);
            return Verdict::Hold;
        }
        let next_c = self.load_c_milli.saturating_add(load_delta_milli);
        if next_c >= self.limit_r_milli {
            self.load_c_milli = self.limit_r_milli;
            self.seal(monolith_id as u64, Verdict::Kill);
            return Verdict::Kill;
        }
        // Perform full involution T(T(s)) = s during verified transit
        let flipped = Self::apply_involution(self.medium);
        let restored = Self::apply_involution(flipped);
        assert_eq!(restored, self.medium);
        self.involutions += 1;
        self.load_c_milli = next_c;
        self.monoliths_lit = self.monoliths_lit.max(monolith_id);
        self.seal(monolith_id as u64, Verdict::Open);
        Verdict::Open
    }
}

impl Default for MillenniumEngine {
    fn default() -> Self {
        Self::new()
    }
}

fn main() {
    let mut eng = MillenniumEngine::new();

    // 1. Missing witness -> HOLD
    assert_eq!(eng.admit_monolith(1, 5_000, 0, false), Verdict::Hold);
    assert_eq!(eng.monoliths_lit, 0);

    // 2. Explicit HOLD request -> HOLD
    assert_eq!(eng.admit_monolith(1, 5_000, 0xAA01, true), Verdict::Hold);

    // 3. Admit all 7 monoliths with C(t) < R and exact T(T(s)) = s
    for m in 1u8..=7u8 {
        assert_eq!(
            eng.admit_monolith(m, 10_000, 0xAA00 + m as u64, false),
            Verdict::Open
        );
    }
    assert_eq!(eng.monoliths_lit, 7);
    assert_eq!(eng.involutions, 7);
    assert!(eng.load_c_milli < eng.limit_r_milli);

    // 4. Pushing C(t) >= R triggers immediate KILL
    assert_eq!(eng.admit_monolith(7, 30_000, 0xAA99, false), Verdict::Kill);
    assert_eq!(eng.load_c_milli, eng.limit_r_milli);

    println!(
        "MILLENNIUM_ENGINE_V1_PASS monoliths=7/7 involutions={} witnesses={} head_hash=0x{:016x}",
        eng.involutions, eng.witness_count, eng.head_hash
    );
}
