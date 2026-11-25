/*
 * Flap & Plopp — Zero-Float C11 / QNX Neutrino 8.0 Consequence Gate
 * Enforces T(T(s)) = s, C(t) < R, HOLD (never opens on monotonic time alone),
 * and instant 0.00 V KILL on C(t) >= R with an append-only FNV-1a witness log.
 *
 * Host build: cc -std=c11 -O2 -Wall -Wextra -Werror -Wpedantic -msoft-float -mno-sse -mno-sse2
 * QNX build : qcc -Vgcc_ntox86_64 -std=c11 -O2 -Wall -Wextra -Werror
 */

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <assert.h>

enum {
    FP_MED_SKY = 0u,
    FP_MED_SEA = 1u
};

enum {
    FP_STATE_HOLD = 0u,
    FP_STATE_OPEN = 1u,
    FP_STATE_KILL = 2u
};

#define FP_CAPACITY_R_MILLI  100000u /* R = 100.000 in exact milli-units (0 float) */
#define FP_TAU_NUM               27u /* Exact rational threshold tau <= 27/50 (0 float) */
#define FP_TAU_DEN               50u

/* Bilateral Double-Pulse Involution (T^2 = I inside phase space M / HOLD): psi_Rx(psi_Tx(x)) == x */
static inline uint32_t fp_psi_tx(uint32_t x) { return x ^ 0xA5A55A5Au; }
static inline uint32_t fp_psi_rx(uint32_t y) { return y ^ 0xA5A55A5Au; }

/* Boundary gate Omega on dM -> {OPEN, KILL}: checks exact tau_num / tau_den <= 27/50 */
static inline bool fp_omega_tau_admissible(uint32_t tau_num, uint32_t tau_den, uint32_t pulse_word) {
    if (tau_den == 0u) return false;
    bool tau_ok = ((uint64_t)tau_num * (uint64_t)FP_TAU_DEN) <= ((uint64_t)FP_TAU_NUM * (uint64_t)tau_den);
    return tau_ok && (fp_psi_rx(fp_psi_tx(pulse_word)) == pulse_word);
}

typedef struct {
    uint64_t seq;
    uint64_t mono_ns;
    uint64_t prev_hash;
    uint64_t event_hash;
    uint32_t load_c_milli;
    uint8_t  medium;
    uint8_t  state;
    uint8_t  v_out_allow; /* 1 = OPEN, 0 = 0.00 V DC fail-closed */
} fp_witness_t;

typedef struct {
    uint8_t      state;
    uint8_t      medium;
    uint32_t     load_c_milli;
    uint32_t     shift_parity;
    uint32_t     involutions_completed;
    uint64_t     last_mono_ns;
    uint64_t     head_hash;
    uint32_t     log_len;
    fp_witness_t log[32];
} fp_qnx_gate_t;

/* Exact IKS involution F(s) = 1 - s around fixed point 0.5: F(F(s)) == s */
static inline uint8_t fp_apply_T(uint8_t s) {
    return (uint8_t)(1u - (s & 1u));
}

/* Four-indicator product: chi_HPIS * chi_TOR * chi_WORM * chi_RFM */
static inline uint8_t fp_indicator_product(const fp_qnx_gate_t *g, bool chain_ok, bool collision_free) {
    uint8_t chi_hpis = (g->load_c_milli < FP_CAPACITY_R_MILLI) ? 1u : 0u;
    uint8_t chi_tor  = (fp_apply_T(fp_apply_T(g->medium)) == g->medium) ? 1u : 0u;
    uint8_t chi_worm = chain_ok ? 1u : 0u;
    uint8_t chi_rfm  = collision_free ? 1u : 0u;
    return (uint8_t)(chi_hpis & chi_tor & chi_worm & chi_rfm);
}

static uint64_t fp_fnv1a(uint64_t prev_hash, uint64_t seq, uint64_t mono_ns, uint32_t load_c, uint8_t st) {
    uint64_t h = 0xcbf29ce484222325ULL;
    const uint64_t vals[3] = { prev_hash, seq, mono_ns };
    for (uint32_t i = 0u; i < 3u; ++i) {
        uint64_t v = vals[i];
        for (uint32_t b = 0u; b < 8u; ++b) {
            h ^= (v >> (b * 8u)) & 0xFFULL;
            h *= 0x100000001b3ULL;
        }
    }
    for (uint32_t b = 0u; b < 4u; ++b) {
        h ^= (uint64_t)((load_c >> (b * 8u)) & 0xFFu);
        h *= 0x100000001b3ULL;
    }
    h ^= (uint64_t)st;
    h *= 0x100000001b3ULL;
    return h;
}

static void fp_append_log(fp_qnx_gate_t *g, uint64_t mono_ns) {
    if (g->log_len >= 32u) return;
    uint64_t seq = (uint64_t)(g->log_len + 1u);
    uint64_t h = fp_fnv1a(g->head_hash, seq, mono_ns, g->load_c_milli, g->state);
    fp_witness_t *w = &g->log[g->log_len++];
    w->seq          = seq;
    w->mono_ns      = mono_ns;
    w->prev_hash    = g->head_hash;
    w->event_hash   = h;
    w->load_c_milli = g->load_c_milli;
    w->medium       = g->medium;
    w->state        = g->state;
    w->v_out_allow  = (g->state == FP_STATE_OPEN) ? 1u : 0u;
    g->head_hash    = h;
}

static void fp_init(fp_qnx_gate_t *g, uint64_t start_ns) {
    g->state                 = FP_STATE_HOLD;
    g->medium                = FP_MED_SKY;
    g->load_c_milli          = 12000u;
    g->shift_parity          = 0u;
    g->involutions_completed = 0u;
    g->last_mono_ns          = start_ns;
    g->head_hash             = 0ULL;
    g->log_len               = 0u;
    fp_append_log(g, start_ns);
}

static bool fp_open_with_witness(fp_qnx_gate_t *g, uint64_t mono_ns, uint64_t evidence_id) {
    if (g->state != FP_STATE_HOLD || evidence_id == 0ULL || mono_ns < g->last_mono_ns) {
        return false;
    }
    if (g->load_c_milli >= FP_CAPACITY_R_MILLI) {
        g->state = FP_STATE_KILL;
        fp_append_log(g, mono_ns);
        return false;
    }
    g->last_mono_ns = mono_ns;
    g->state = FP_STATE_OPEN;
    fp_append_log(g, mono_ns);
    return true;
}

/* Doc 176 Triadic Realization & Design Invalidity (U_safe == empty -> KILL, t >= t* -> HOLD) */
static uint8_t fp_eval_triadic(
    const fp_qnx_gate_t *g,
    uint64_t mono_ns,
    uint64_t horizon_ns,
    bool u_safe_nonempty
) {
    if (!u_safe_nonempty || g->load_c_milli >= FP_CAPACITY_R_MILLI) {
        return FP_STATE_KILL; /* Design Invalidity or C(t) >= R -> 0.00 V KILL */
    }
    if (mono_ns >= horizon_ns || fp_apply_T(fp_apply_T(g->medium)) != g->medium) {
        return FP_STATE_HOLD; /* Epistemic horizon expired (t >= t*) -> HOLD */
    }
    return FP_STATE_OPEN;
}

/* Doc 178 Rev^2: Dom(F) intersect D2 == empty -> ANTI_REVERSIBLE_VIOLATION triggers 0.00 V KILL */
static bool fp_deny_anti_reversible(
    fp_qnx_gate_t *g,
    uint64_t mono_ns,
    bool committed_in_d2,
    bool asserts_involution
) {
    if (committed_in_d2 && asserts_involution) {
        g->state = FP_STATE_KILL;
        fp_append_log(g, mono_ns);
        return false;
    }
    return true;
}

/* Doc 181 (SPEC-385) Crash^3 Tri-System Collision Arbiter (0 float):
 *   S1 = Pi_K o Phi_H (eps_k_milli), S2 = Omega_E-TOR (pi >= 27/50), S3 = R_Witness (eps_w)
 * Enforces constitutional priority KILL > HOLD > OPEN with post-KILL latch immunity. */
static uint8_t fp_eval_crash3(
    fp_qnx_gate_t *g,
    uint64_t mono_ns,
    uint32_t eps_k_milli,
    uint32_t pi_num,
    uint32_t pi_den,
    bool eps_w,
    bool r_dot_exceeded,
    bool g_violated
) {
    if (g->state == FP_STATE_KILL) {
        return FP_STATE_KILL; /* Post-KILL crowbar latch immunity */
    }
    bool inv_ok = (fp_apply_T(fp_apply_T(g->medium)) == g->medium);
    if (eps_w || !inv_ok || g_violated || g->load_c_milli >= FP_CAPACITY_R_MILLI) {
        g->state = FP_STATE_KILL;
        fp_append_log(g, mono_ns);
        return FP_STATE_KILL;
    }
    bool eps_e_ge_zero = (pi_den == 0u)
        || ((uint64_t)pi_num * (uint64_t)FP_TAU_DEN >= (uint64_t)FP_TAU_NUM * (uint64_t)pi_den);
    if (eps_e_ge_zero || eps_k_milli > 0u || r_dot_exceeded) {
        g->state = FP_STATE_HOLD;
        fp_append_log(g, mono_ns);
        return FP_STATE_HOLD;
    }
    g->state = FP_STATE_OPEN;
    fp_append_log(g, mono_ns);
    return FP_STATE_OPEN;
}

/* Doc 183 (SPEC-387) Theorem 1: History-Dependent POVM Divergence (0 float, milli-scale)
 * Valid iff eta^2 + 4*eps^2 <= 1; outputs p_+(gamma) = 500 + eps_milli * k_gamma. */
static bool fp_povm_outcome_milli(
    uint32_t eta_milli,
    uint32_t eps_milli,
    uint8_t k_gamma,
    uint32_t *out_p_milli
) {
    if (eta_milli == 0u || eta_milli >= 1000u || eps_milli == 0u || k_gamma > 1u || !out_p_milli) {
        return false;
    }
    uint64_t norm_sq = (uint64_t)eta_milli * (uint64_t)eta_milli
        + 4ULL * (uint64_t)eps_milli * (uint64_t)eps_milli;
    if (norm_sq > 1000000ULL) {
        return false;
    }
    *out_p_milli = 500u + eps_milli * (uint32_t)k_gamma;
    return true;
}

/* Doc 183 (SPEC-387) Table 1: Cross-Disciplinary Selection over Generation (0 float)
 * Checks POVM validity, SDE Lipschitz bound, ECC cofactor h <= 8, and MCMC detailed balance. */
static uint8_t fp_eval_doc183_admissibility(
    uint32_t eta_milli,
    uint32_t eps_milli,
    uint64_t lip_lhs,
    uint64_t lip_rhs,
    uint32_t ecc_cofactor_h,
    uint64_t pi_x,
    uint64_t p_xy,
    uint64_t pi_y,
    uint64_t p_yx
) {
    uint32_t p_probe = 0u;
    bool povm_ok = fp_povm_outcome_milli(eta_milli, eps_milli, 1u, &p_probe);
    bool lip_ok  = (lip_lhs <= lip_rhs);
    bool ecc_ok  = (ecc_cofactor_h >= 1u && ecc_cofactor_h <= 8u);
    if (!povm_ok || !lip_ok || !ecc_ok) {
        return FP_STATE_KILL;
    }
    if (pi_x * p_xy != pi_y * p_yx) {
        return FP_STATE_HOLD;
    }
    return FP_STATE_OPEN;
}

/* Doc 185 (KY Canon): Prime Mark (Delta_K), Poincare Return Surface (Delta_Sigma),
 * and Maxwell Integrability Gate (|dP/dT - dS/dV| <= eps_integrable) — 0 float. */
static uint8_t fp_eval_doc185_canon(
    uint64_t delta_k,
    uint64_t delta_sigma,
    int64_t dp_dt_milli,
    int64_t ds_dv_milli,
    uint64_t eps_admissible,
    uint64_t eps_critical,
    uint64_t eps_integrable
) {
    uint64_t delta_maxwell = (dp_dt_milli >= ds_dv_milli)
        ? (uint64_t)(dp_dt_milli - ds_dv_milli)
        : (uint64_t)(ds_dv_milli - dp_dt_milli);
    if (eps_critical < eps_admissible
        || delta_maxwell > eps_integrable
        || delta_k > eps_critical
        || delta_sigma > eps_critical) {
        return FP_STATE_KILL;
    }
    if (delta_k > eps_admissible || delta_sigma > eps_admissible) {
        return FP_STATE_HOLD;
    }
    return FP_STATE_OPEN;
}

/* Doc 171 (SPEC-365) PiPNN & HashPrune: History-Independent Angular Cone Gating (0 float) */
#define FP_PIPNN_C_MAX 1024u

typedef struct {
    uint32_t id;
    int32_t  dx;
    int32_t  dy;
} fp_hp_cand_t;

static inline uint8_t fp_hashprune_bucket(int32_t dx, int32_t dy) {
    uint8_t b0 = (dx >= 0) ? 1u : 0u;
    uint8_t b1 = (dy >= 0) ? 1u : 0u;
    uint8_t b2 = (((int64_t)dx + (int64_t)dy) >= 0LL) ? 1u : 0u;
    return (uint8_t)(b0 | (uint8_t)(b1 << 1u) | (uint8_t)(b2 << 2u));
}

static uint32_t fp_hashprune_admit(
    const fp_hp_cand_t *cands,
    uint32_t n,
    uint32_t l_max,
    uint32_t out_ids[8]
) {
    bool     used[8] = { false };
    uint32_t bid[8]  = { 0u };
    uint64_t bd2[8]  = { 0ULL };
    uint32_t active  = 0u;

    for (uint32_t i = 0u; i < n; ++i) {
        int64_t dx = (int64_t)cands[i].dx;
        int64_t dy = (int64_t)cands[i].dy;
        uint64_t d2 = (uint64_t)(dx * dx + dy * dy);
        uint8_t b = fp_hashprune_bucket(cands[i].dx, cands[i].dy);
        if (!used[b]) {
            used[b] = true;
            bid[b]  = cands[i].id;
            bd2[b]  = d2;
            active++;
        } else if (d2 < bd2[b] || (d2 == bd2[b] && cands[i].id < bid[b])) {
            bid[b] = cands[i].id;
            bd2[b] = d2;
        }
        while (active > l_max) {
            uint8_t  worst_b  = 0u;
            uint64_t worst_d2 = 0ULL;
            uint32_t worst_id = 0u;
            bool     found    = false;
            for (uint8_t k = 0u; k < 8u; ++k) {
                if (!used[k]) continue;
                if (!found || bd2[k] > worst_d2 || (bd2[k] == worst_d2 && bid[k] > worst_id)) {
                    found    = true;
                    worst_b  = k;
                    worst_d2 = bd2[k];
                    worst_id = bid[k];
                }
            }
            if (found) {
                used[worst_b] = false;
                active--;
            } else {
                break;
            }
        }
    }
    for (uint8_t k = 0u; k < 8u; ++k) {
        out_ids[k] = used[k] ? bid[k] : 0u;
    }
    return active;
}

static bool fp_shift(fp_qnx_gate_t *g, uint64_t mono_ns) {
    if (g->state != FP_STATE_OPEN || mono_ns < g->last_mono_ns) {
        return false;
    }
    g->last_mono_ns = mono_ns;
    g->medium = fp_apply_T(g->medium);
    g->shift_parity++;
    if ((g->shift_parity & 1u) == 0u) {
        g->involutions_completed++;
        g->load_c_milli = (g->load_c_milli > 10000u) ? (g->load_c_milli - 10000u) : 0u;
    }
    fp_append_log(g, mono_ns);
    return true;
}

static void fp_step_monotonic(fp_qnx_gate_t *g, uint64_t mono_ns, uint32_t load_delta_milli) {
    if (mono_ns < g->last_mono_ns) {
        g->state = FP_STATE_KILL; /* Non-monotonic clock violation -> KILL */
        fp_append_log(g, mono_ns);
        return;
    }
    g->last_mono_ns = mono_ns;
    if (g->state == FP_STATE_HOLD) {
        /* HOLD never opens on elapsed time; cools C(t) safely */
        g->load_c_milli = (g->load_c_milli > load_delta_milli) ? (g->load_c_milli - load_delta_milli) : 0u;
        return;
    }
    if (g->state == FP_STATE_OPEN) {
        uint64_t next_c = (uint64_t)g->load_c_milli + (uint64_t)load_delta_milli;
        if (next_c >= (uint64_t)FP_CAPACITY_R_MILLI) {
            g->load_c_milli = FP_CAPACITY_R_MILLI;
            g->state = FP_STATE_KILL;
            fp_append_log(g, mono_ns);
        } else {
            g->load_c_milli = (uint32_t)next_c;
        }
    }
}

static bool fp_verify_chain(const fp_qnx_gate_t *g) {
    uint64_t prev = 0ULL;
    for (uint32_t i = 0u; i < g->log_len; ++i) {
        const fp_witness_t *w = &g->log[i];
        if (w->prev_hash != prev) return false;
        uint64_t h = fp_fnv1a(w->prev_hash, w->seq, w->mono_ns, w->load_c_milli, w->state);
        if (w->event_hash != h) return false;
        prev = w->event_hash;
    }
    return prev == g->head_hash;
}

int main(void) {
    /* 1. Exact involution T^2 = I (in HOLD phase space M), Double-Pulse & exact tau <= 27/50 */
    assert(fp_apply_T(fp_apply_T(FP_MED_SKY)) == FP_MED_SKY);
    assert(fp_apply_T(fp_apply_T(FP_MED_SEA)) == FP_MED_SEA);
    assert(fp_omega_tau_admissible(27u, 50u, 0x17700540u));
    assert(!fp_omega_tau_admissible(541u, 1000u, 0x17700540u));

    fp_qnx_gate_t g;
    fp_init(&g, 1000000ULL);
    assert(g.state == FP_STATE_HOLD);

    /* 2. HOLD never opens merely because monotonic time passes */
    fp_step_monotonic(&g, 5000000000ULL, 2000u);
    assert(g.state == FP_STATE_HOLD);

    /* 3. OPEN requires explicit non-zero evidence_id */
    assert(!fp_open_with_witness(&g, 5000012500ULL, 0ULL));
    assert(g.state == FP_STATE_HOLD);
    assert(fp_open_with_witness(&g, 5000025000ULL, 0xF1A90001ULL));
    assert(g.state == FP_STATE_OPEN);

    /* 4. Two SHIFTs complete T(T(s)) = s; verify Doc 176 triadic horizon t < t* & Design Invalidity */
    assert(fp_shift(&g, 5000037500ULL) && g.medium == FP_MED_SEA);
    assert(fp_shift(&g, 5000050000ULL) && g.medium == FP_MED_SKY);
    assert(g.involutions_completed == 1u);
    assert(fp_eval_triadic(&g, 5000050000ULL, 6000000000ULL, true) == FP_STATE_OPEN);
    assert(fp_eval_triadic(&g, 6000000000ULL, 6000000000ULL, true) == FP_STATE_HOLD);
    assert(fp_eval_triadic(&g, 5000050000ULL, 6000000000ULL, false) == FP_STATE_KILL);

    /* 5. C(t) >= R triggers immediate 0.00 V KILL and drops indicator product to 0 */
    assert(fp_indicator_product(&g, fp_verify_chain(&g), true) == 1u);
    fp_step_monotonic(&g, 5000062500ULL, 100000u);
    assert(g.state == FP_STATE_KILL);
    assert(fp_indicator_product(&g, fp_verify_chain(&g), true) == 0u);
    assert(g.log[g.log_len - 1u].v_out_allow == 0u);

    /* 6. Doc 178 Rev^2: asserting reversibility after D2 PONR -> ANTI_REVERSIBLE_VIOLATION KILL */
    assert(fp_deny_anti_reversible(&g, 5000075000ULL, false, true));
    assert(!fp_deny_anti_reversible(&g, 5000087500ULL, true, true));
    assert(g.state == FP_STATE_KILL);
    assert(fp_verify_chain(&g));

    /* 7. Doc 181 (SPEC-385) Crash^3 Table 1 Verification Suite (KILL > HOLD > OPEN) */
    fp_qnx_gate_t cg;
    fp_init(&cg, 1000000ULL);
    assert(fp_eval_crash3(&cg, 1001000ULL, 0u, 26u, 50u, false, false, false) == FP_STATE_OPEN);  /* Test A */
    assert(fp_eval_crash3(&cg, 1002000ULL, 10u, 26u, 50u, false, false, false) == FP_STATE_HOLD); /* Test B */
    assert(fp_eval_crash3(&cg, 1003000ULL, 0u, 27u, 50u, false, false, false) == FP_STATE_HOLD);  /* Test C */
    assert(fp_eval_crash3(&cg, 1004000ULL, 0u, 26u, 50u, true, false, false) == FP_STATE_KILL);   /* Test D */
    assert(cg.log[cg.log_len - 1u].v_out_allow == 0u);
    assert(fp_eval_crash3(&cg, 1005000ULL, 0u, 10u, 50u, false, false, false) == FP_STATE_KILL);  /* Latch */
    assert(fp_verify_chain(&cg));

    fp_qnx_gate_t c3;
    fp_init(&c3, 2000000ULL);
    /* Crash^3 main clash: S1 PASS (eps_K=0), S2 HOLD (pi=30/50 >= 27/50), S3 KILL (eps_W=1), R_dot > dR */
    assert(fp_eval_crash3(&c3, 2001000ULL, 0u, 30u, 50u, true, true, false) == FP_STATE_KILL);
    assert(c3.log[c3.log_len - 1u].v_out_allow == 0u);
    assert(fp_verify_chain(&c3));

    /* 8. Doc 183 (SPEC-387): POVM History Divergence (dp = eps) & Cross-Disciplinary Admissibility */
    uint32_t pa = 0u, pb = 0u, pinv = 0u;
    assert(fp_povm_outcome_milli(600u, 300u, 1u, &pa));
    assert(fp_povm_outcome_milli(600u, 300u, 0u, &pb));
    assert(pa == 800u && pb == 500u && (pa - pb) == 300u);
    assert(!fp_povm_outcome_milli(800u, 400u, 1u, &pinv));
    assert(fp_eval_doc183_admissibility(600u, 300u, 40ULL, 50ULL, 1u, 3ULL, 4ULL, 6ULL, 2ULL) == FP_STATE_OPEN);
    assert(fp_eval_doc183_admissibility(600u, 300u, 40ULL, 50ULL, 1u, 3ULL, 4ULL, 5ULL, 2ULL) == FP_STATE_HOLD);
    assert(fp_eval_doc183_admissibility(600u, 300u, 60ULL, 50ULL, 1u, 3ULL, 4ULL, 6ULL, 2ULL) == FP_STATE_KILL);
    assert(fp_eval_doc183_admissibility(600u, 300u, 40ULL, 50ULL, 16u, 3ULL, 4ULL, 6ULL, 2ULL) == FP_STATE_KILL);

    /* 9. Doc 185 (KY Canon): Prime Mark, Poincare Return Surface & Maxwell Integrability Gate */
    assert(fp_eval_doc185_canon(0ULL, 12ULL, 1000LL, 998LL, 20ULL, 50ULL, 5ULL) == FP_STATE_OPEN);
    assert(fp_eval_doc185_canon(0ULL, 35ULL, 1000LL, 998LL, 20ULL, 50ULL, 5ULL) == FP_STATE_HOLD);
    assert(fp_eval_doc185_canon(0ULL, 75ULL, 1000LL, 998LL, 20ULL, 50ULL, 5ULL) == FP_STATE_KILL);
    assert(fp_eval_doc185_canon(0ULL, 10ULL, 1000LL, 950LL, 20ULL, 50ULL, 5ULL) == FP_STATE_KILL);

    /* 10. Doc 171 (SPEC-365) PiPNN / HashPrune Theorem 3.1: HashPrune(pi(C)) == HashPrune(C) */
    const fp_hp_cand_t hp_fwd[5]  = { {1u,10,10}, {2u,4,3}, {3u,-6,8}, {4u,-5,-5}, {5u,12,-2} };
    const fp_hp_cand_t hp_rev[5]  = { {5u,12,-2}, {4u,-5,-5}, {3u,-6,8}, {2u,4,3}, {1u,10,10} };
    const fp_hp_cand_t hp_perm[5] = { {4u,-5,-5}, {1u,10,10}, {5u,12,-2}, {3u,-6,8}, {2u,4,3} };
    uint32_t rf[8], rr[8], rp[8];
    assert(FP_PIPNN_C_MAX == 1024u);
    assert(fp_hashprune_admit(hp_fwd, 5u, 3u, rf) == 3u);
    assert(fp_hashprune_admit(hp_rev, 5u, 3u, rr) == 3u);
    assert(fp_hashprune_admit(hp_perm, 5u, 3u, rp) == 3u);
    for (uint8_t k = 0u; k < 8u; ++k) {
        assert(rf[k] == rr[k] && rf[k] == rp[k]);
    }
    assert(rf[0] == 4u && rf[6] == 3u && rf[7] == 2u);

    printf("FLAP_PLOPP_QNX_C11_PASS log_entries=%u crash3_entries=%u doc183_dp=%u doc185_ok=1 doc171_hp=1 involutions=%u chain_valid=1\n",
           g.log_len, cg.log_len + c3.log_len, pa - pb, g.involutions_completed);
    return 0;
}
