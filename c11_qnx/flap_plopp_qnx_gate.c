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

    /* 4. Two SHIFTs complete T(T(s)) = s */
    assert(fp_shift(&g, 5000037500ULL) && g.medium == FP_MED_SEA);
    assert(fp_shift(&g, 5000050000ULL) && g.medium == FP_MED_SKY);
    assert(g.involutions_completed == 1u);

    /* 5. C(t) >= R triggers immediate 0.00 V KILL and drops indicator product to 0 */
    assert(fp_indicator_product(&g, fp_verify_chain(&g), true) == 1u);
    fp_step_monotonic(&g, 5000062500ULL, 100000u);
    assert(g.state == FP_STATE_KILL);
    assert(fp_indicator_product(&g, fp_verify_chain(&g), true) == 0u);
    assert(g.log[g.log_len - 1u].v_out_allow == 0u);
    assert(fp_verify_chain(&g));

    printf("FLAP_PLOPP_QNX_C11_PASS log_entries=%u involutions=%u chain_valid=1\n",
           g.log_len, g.involutions_completed);
    return 0;
}
