/*
 * Flap & Plopp — Document 185 KORA Bit-Exact Zero-Float C11 Kernel
 * Type-chain: x_raw -> Phi -> x' -> Pi_K -> x_proj -> G -> Omega -> Witness -> x_commit
 * Enforces 3-zone port (OPEN / HOLD / latched KILL), Q4/Q7 mask, 39 400 ps limit,
 * Poincare return surface Sigma (EPS_ADM=64, EPS_CRIT=256), Schwarz/Maxwell <= 32,
 * and monotonic Witness^2 sequence (0 float).
 */

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

/* Terskler i Q4.12 fastpunkt (4096 = 1.0) og heltalls-pikosekunder */
#define WINDOW_MAX_PS         40800U
#define OPEN_LIMIT_PS         39400U
#define MASKED_NODE_MASK      ((1U << 4) | (1U << 7))

#define EPS_ADM_Q4_12            64U  /* ~0.0156: grensen for ren OPEN */
#define EPS_CRIT_Q4_12          256U  /* ~0.0625: over dette -> latchet KILL */
#define EPS_MAXWELL_Q4_12        32U  /* ~0.0078: Schwarz-integrabilitetskrav */

typedef enum {
    PORT_HOLD = 0, /* 0.00 V DC: Reversibel stase / rekalibrering */
    PORT_OPEN = 1, /* 5.00 V DC: Autorisert energiledning */
    PORT_KILL = 2  /* 0.00 V Latched: Permanent frakobling til entropi */
} ky_port_t;

typedef struct {
    /* Kandidat x' = Phi(x) */
    uint16_t active_nodes_mask;
    uint8_t  swap_layers;
    uint32_t predicted_latency_ps;

    /* Projeksjonsavvik Delta_K (Q4.12) */
    uint16_t delta_k_q4_12;

    /* Poincare-returflate Sigma: m_return vs R(x_return) (Q4.12) */
    int32_t  m_return_q4_12;
    int32_t  r_x_return_q4_12;

    /* Maxwell / Schwarz-port: kryssderiverte i Q4.12 */
    int32_t  dP_dT_V_q4_12;
    int32_t  dS_dV_T_q4_12;

    /* Witness^2: monoton audit-sekvens og trigger */
    uint64_t prev_witness_seq;
    uint64_t next_witness_seq;
    bool     audit_verified;
    bool     level01_authorize;
} kora_candidate_t;

typedef struct {
    ky_port_t port;
    uint32_t  delta_sigma_q4_12;
    uint32_t  delta_maxwell_q4_12;
    uint64_t  committed_seq;
    bool      latched_kill;
} kora_verdict_t;

static inline uint32_t abs_diff_i32(int32_t a, int32_t b) {
    int64_t d = (int64_t)a - (int64_t)b;
    return (uint32_t)(d < 0 ? -d : d);
}

static kora_verdict_t ky_engine_step(const kora_candidate_t *cand, bool already_killed) {
    kora_verdict_t out = {
        .port = PORT_HOLD,
        .delta_sigma_q4_12 = 0U,
        .delta_maxwell_q4_12 = 0U,
        .committed_seq = 0ULL,
        .latched_kill = already_killed
    };

    /* 0. Latchet KILL kan aldri nullstilles uten fysisk reset */
    if (already_killed || !cand) {
        out.port = PORT_KILL;
        out.latched_kill = true;
        return out;
    }

    /* 1. Lov 2: "COMMITTED without audit" -> umiddelbar KILL */
    if (!cand->audit_verified || cand->next_witness_seq != (cand->prev_witness_seq + 1ULL)) {
        out.port = PORT_KILL;
        out.latched_kill = true;
        return out;
    }

    /* 2. Harde maskinvaregrenser i Pi_K (Q4/Q7, SWAP, 40.8 ns-tak) */
    if (((cand->active_nodes_mask & MASKED_NODE_MASK) != 0U) ||
        (cand->swap_layers > 2U) ||
        (cand->predicted_latency_ps > OPEN_LIMIT_PS)) {
        out.port = PORT_KILL;
        out.latched_kill = true;
        return out;
    }

    /* 3. Maxwell-porten (Ligning 23): Integrabilitet foer tilstand */
    out.delta_maxwell_q4_12 = abs_diff_i32(cand->dP_dT_V_q4_12, cand->dS_dV_T_q4_12);
    if (out.delta_maxwell_q4_12 > EPS_MAXWELL_Q4_12) {
        out.port = PORT_KILL;
        out.latched_kill = true;
        return out;
    }

    /* 4. Poincare-returflate Sigma (Ligning 16-19): Kart mot terreng */
    out.delta_sigma_q4_12 = abs_diff_i32(cand->m_return_q4_12, cand->r_x_return_q4_12);

    if (cand->delta_k_q4_12 > EPS_CRIT_Q4_12 || out.delta_sigma_q4_12 > EPS_CRIT_Q4_12) {
        out.port = PORT_KILL;
        out.latched_kill = true;
        return out;
    }

    /* 5. Mellomsone (eps_adm < Delta <= eps_crit) -> HOLD (0.00 V DC) for rekalibrering */
    if (cand->delta_k_q4_12 > EPS_ADM_Q4_12 || out.delta_sigma_q4_12 > EPS_ADM_Q4_12) {
        out.port = PORT_HOLD;
        out.committed_seq = cand->next_witness_seq;
        return out;
    }

    /* 6. Level 01 menneskelig suverenitet: Uten autorisasjon forblir vi i HOLD */
    if (!cand->level01_authorize) {
        out.port = PORT_HOLD;
        out.committed_seq = cand->next_witness_seq;
        return out;
    }

    /* 7. Alle porter groenne -> OPEN (5.00 V DC) og irreversibel commit */
    out.port = PORT_OPEN;
    out.committed_seq = cand->next_witness_seq;
    return out;
}

int main(void) {
    kora_candidate_t base = {
        .active_nodes_mask    = (uint16_t)(0x0FFFU & ~MASKED_NODE_MASK),
        .swap_layers          = 2U,
        .predicted_latency_ps = 39400U,
        .delta_k_q4_12        = 32U,
        .m_return_q4_12       = 1000,
        .r_x_return_q4_12     = 960,   /* delta_sigma = 40 <= 64 */
        .dP_dT_V_q4_12        = 2000,
        .dS_dV_T_q4_12        = 1980,  /* delta_maxwell = 20 <= 32 */
        .prev_witness_seq     = 0ULL,
        .next_witness_seq     = 1ULL,
        .audit_verified       = true,
        .level01_authorize    = true
    };

    /* 1. Nominal OPEN (5.00 V DC) */
    kora_verdict_t v = ky_engine_step(&base, false);
    assert(v.port == PORT_OPEN && !v.latched_kill && v.committed_seq == 1ULL);
    assert(v.delta_sigma_q4_12 == 40U && v.delta_maxwell_q4_12 == 20U);

    /* 2. Poincare drift i mellomsone (64 < 120 <= 256) -> HOLD, deretter rekalibrert -> OPEN */
    kora_candidate_t drift = base;
    drift.prev_witness_seq = 1ULL;
    drift.next_witness_seq = 2ULL;
    drift.r_x_return_q4_12 = 880; /* delta_sigma = 120 */
    v = ky_engine_step(&drift, false);
    assert(v.port == PORT_HOLD && !v.latched_kill && v.committed_seq == 2ULL);

    kora_candidate_t recal = base;
    recal.prev_witness_seq = 2ULL;
    recal.next_witness_seq = 3ULL;
    v = ky_engine_step(&recal, false);
    assert(v.port == PORT_OPEN && !v.latched_kill && v.committed_seq == 3ULL);

    /* 3. Manglende Level 01 autorisasjon -> HOLD */
    kora_candidate_t no_auth = base;
    no_auth.prev_witness_seq  = 3ULL;
    no_auth.next_witness_seq  = 4ULL;
    no_auth.level01_authorize = false;
    v = ky_engine_step(&no_auth, false);
    assert(v.port == PORT_HOLD && !v.latched_kill && v.committed_seq == 4ULL);

    /* 4. Audit / sekvens-brudd -> latchet KILL */
    kora_candidate_t bad_seq = base;
    bad_seq.prev_witness_seq = 4ULL;
    bad_seq.next_witness_seq = 6ULL; /* Hopper over 5 */
    v = ky_engine_step(&bad_seq, false);
    assert(v.port == PORT_KILL && v.latched_kill);

    /* 5. Q4/Q7 maske eller latens > 39 400 ps -> latchet KILL */
    kora_candidate_t bad_hw = base;
    bad_hw.active_nodes_mask |= (1U << 4);
    v = ky_engine_step(&bad_hw, false);
    assert(v.port == PORT_KILL && v.latched_kill);

    /* 6. Schwarz/Maxwell-brudd (> 32) -> latchet KILL */
    kora_candidate_t bad_mx = base;
    bad_mx.dS_dV_T_q4_12 = 1900; /* delta_maxwell = 100 > 32 */
    v = ky_engine_step(&bad_mx, false);
    assert(v.port == PORT_KILL && v.latched_kill && v.delta_maxwell_q4_12 == 100U);

    /* 7. Post-KILL latch-immunitet: gyldig kandidat slipper aldri gjennom etter KILL */
    v = ky_engine_step(&base, true);
    assert(v.port == PORT_KILL && v.latched_kill && v.committed_seq == 0ULL);

    printf("KY_KORA_C11_PASS tests=7/7 zero_float=1 latch_verified=1\n");
    return 0;
}
