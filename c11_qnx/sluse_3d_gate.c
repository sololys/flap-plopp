/*
 * Flap & Plopp — 3D (q, p) Zero-Float C11 Sluse Gate
 * Enforces HOLD (0.00 V phase space), REJECT (exact Landauer bit-width heat),
 * Poincare crossing (Sigma), Maxwell cross-product symmetry, one-way OPEN,
 * and KILL detachment with R_bound welding (0 float, QNX / host C11).
 */

#include <assert.h>
#include <stdint.h>
#include <stdio.h>

typedef enum {
    PORT_HOLD   = 0,
    PORT_REJECT = 1,
    PORT_OPEN   = 2,
    PORT_KILL   = 3
} gate_event_t;

typedef struct {
    uint64_t tau;
    int32_t  q[3];
    int32_t  p[3];
    int32_t  R_bound;
    uint32_t Q_heat;
    uint32_t Q_max;
    uint8_t  lambda;
    uint32_t fix_streak;

    uint32_t eps_sigma_adm;
    uint32_t eps_sigma_crit;
    uint8_t  sigma_ok;

    uint64_t eps_maxwell;
    uint8_t  maxwell_ok;

    uint8_t  attached;
    uint64_t wal_seq;
} sluse_state_t;

typedef struct {
    int32_t  f[3];
    int32_t  m[3];
    int32_t  dP;
    int32_t  dT;
    int32_t  dS;
    int32_t  dV;
    uint64_t evidence_id;
    uint8_t  bridge_busy;
    uint8_t  hw_veto;
} sluse_input_t;

static uint32_t bit_width_u32(uint32_t v) {
    uint32_t w = 0U;
    while (v > 0U) {
        w++;
        v >>= 1U;
    }
    return w;
}

static int32_t clamp_i32(int32_t v, int32_t lo, int32_t hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static uint32_t abs_i32_to_u32(int32_t v) {
    return (v < 0) ? (uint32_t)(-(int64_t)v) : (uint32_t)v;
}

static uint64_t abs_i64_to_u64(int64_t v) {
    return (v < 0) ? (uint64_t)(-(v + 1)) + 1ULL : (uint64_t)v;
}

static void trigger_kill(sluse_state_t *s) {
    s->attached = 0U;
    s->fix_streak = 0U;
    s->sigma_ok = 0U;
    s->maxwell_ok = 0U;
    if (s->R_bound > 2) {
        s->R_bound -= 1;
    }
    s->wal_seq++;
}

static gate_event_t sluse_step(sluse_state_t *s, const sluse_input_t *in, uint8_t *u_out) {
    *u_out = 0U;
    s->tau++;

    if (s->attached == 0U || in->hw_veto != 0U) {
        if (s->attached != 0U) {
            trigger_kill(s);
        }
        return PORT_KILL;
    }

    int32_t qx_prev = s->q[0];
    uint32_t delta_q = 0U;
    uint32_t delta_p = 0U;
    uint8_t  touching_wall = 0U;
    uint8_t  shift = (s->lambda > 3U) ? 3U : s->lambda;

    for (int i = 0; i < 3; i++) {
        int64_t q_prop_64 = (int64_t)s->q[i] + (int64_t)s->p[i];
        int64_t p_prop_64 = (int64_t)s->p[i] + (int64_t)in->f[i];

        int32_t q_prop = (q_prop_64 > INT32_MAX - 1) ? (INT32_MAX - 1) :
                         (q_prop_64 < INT32_MIN + 1) ? (INT32_MIN + 1) : (int32_t)q_prop_64;
        int32_t p_prop = (p_prop_64 > INT32_MAX - 1) ? (INT32_MAX - 1) :
                         (p_prop_64 < INT32_MIN + 1) ? (INT32_MIN + 1) : (int32_t)p_prop_64;

        int32_t q_proj = clamp_i32(q_prop, -s->R_bound, s->R_bound);

        if (q_proj != q_prop) {
            delta_q += abs_i32_to_u32(q_prop - q_proj);
            uint32_t p_mag = abs_i32_to_u32(p_prop);
            uint32_t p_damped = p_mag >> shift;
            delta_p += (p_mag - p_damped);

            s->q[i] = q_proj;
            s->p[i] = (p_prop >= 0) ? -(int32_t)p_damped : (int32_t)p_damped;
            touching_wall = 1U;
        } else {
            s->q[i] = q_proj;
            s->p[i] = p_prop;
            if (q_proj == s->R_bound || q_proj == -s->R_bound) {
                touching_wall = 1U;
            }
        }
    }

    if (qx_prev < 0 && s->q[0] >= 0) {
        uint32_t delta_sigma = 0U;
        for (int i = 0; i < 3; i++) {
            int64_t diff = (int64_t)in->m[i] - (int64_t)s->q[i];
            delta_sigma += (uint32_t)abs_i64_to_u64(diff);
        }

        if (delta_sigma > s->eps_sigma_crit) {
            trigger_kill(s);
            return PORT_KILL;
        } else if (delta_sigma > s->eps_sigma_adm) {
            s->sigma_ok = 0U;
            s->fix_streak = 0U;
            return PORT_REJECT;
        } else {
            s->sigma_ok = 1U;
        }
    }

    if (in->dT != 0 && in->dV != 0) {
        int64_t lhs = (int64_t)in->dP * (int64_t)in->dV;
        int64_t rhs = (int64_t)in->dS * (int64_t)in->dT;
        uint64_t delta_maxwell = abs_i64_to_u64(lhs - rhs);
        s->maxwell_ok = (delta_maxwell <= s->eps_maxwell) ? 1U : 0U;
    } else {
        s->maxwell_ok = 0U;
    }

    if (delta_q > 0U) {
        uint32_t dQ = bit_width_u32(delta_q) + bit_width_u32(delta_p);
        s->Q_heat += dQ;
        s->fix_streak = 0U;

        if (s->Q_heat >= s->Q_max) {
            trigger_kill(s);
            return PORT_KILL;
        }
        return PORT_REJECT;
    }

    if (touching_wall == 0U) {
        if (s->Q_heat > 0U) {
            s->Q_heat -= 1U;
        }
        s->fix_streak++;
    }

    if (s->fix_streak >= 4U &&
        s->sigma_ok == 1U &&
        s->maxwell_ok == 1U &&
        in->evidence_id != 0U &&
        in->bridge_busy == 0U) {
        *u_out = 1U;
        s->wal_seq++;
        return PORT_OPEN;
    }

    return PORT_HOLD;
}

static sluse_state_t make_default_state(void) {
    sluse_state_t s = {
        .tau            = 0ULL,
        .q              = {0, 0, 0},
        .p              = {0, 0, 0},
        .R_bound        = 16,
        .Q_heat         = 0U,
        .Q_max          = 64U,
        .lambda         = 1U,
        .fix_streak     = 0U,
        .eps_sigma_adm  = 2U,
        .eps_sigma_crit = 6U,
        .sigma_ok       = 0U,
        .eps_maxwell    = 0ULL,
        .maxwell_ok     = 0U,
        .attached       = 1U,
        .wal_seq        = 0ULL
    };
    return s;
}

/* Test 1: HOLD - 0 varme og tid alene aapner aldri porten */
static void test_hold_time_never_opens(void) {
    sluse_state_t s = make_default_state();
    sluse_input_t in = {
        .f = {0, 0, 0}, .m = {0, 0, 0},
        .dP = 2, .dV = 3, .dS = 3, .dT = 2,
        .evidence_id = 0ULL, .bridge_busy = 0U, .hw_veto = 0U
    };
    uint8_t u = 1U;

    for (int i = 0; i < 10; i++) {
        gate_event_t ev = sluse_step(&s, &in, &u);
        assert(ev == PORT_HOLD);
        assert(u == 0U);
    }
    assert(s.Q_heat == 0U);
    assert(s.fix_streak == 10U);
    assert(s.maxwell_ok == 1U);
    assert(s.sigma_ok == 0U);
    printf("[OK] Test 1: HOLD bevarer på 0.00 V (tid alene åpner aldri)\n");
}

/* Test 2: REJECT i HOLD - veggstoet gir eksakt Landauer-varme */
static void test_reject_landauer_heat(void) {
    sluse_state_t s = make_default_state();
    s.q[0] = 15;
    s.p[0] = 5;
    s.fix_streak = 5U;

    sluse_input_t in = {
        .f = {0, 0, 0}, .m = {0, 0, 0},
        .dP = 2, .dV = 3, .dS = 3, .dT = 2,
        .evidence_id = 1ULL, .bridge_busy = 0U, .hw_veto = 0U
    };
    uint8_t u = 1U;

    /* q_prop=20 -> q_proj=16 (delta_q=4, bw=3); p_prop=5 -> p_damped=2 (delta_p=3, bw=2) => dQ=5 */
    gate_event_t ev = sluse_step(&s, &in, &u);
    assert(ev == PORT_REJECT);
    assert(u == 0U);
    assert(s.attached == 1U);
    assert(s.q[0] == 16);
    assert(s.p[0] == -2);
    assert(s.Q_heat == 5U);
    assert(s.fix_streak == 0U);
    printf("[OK] Test 2: REJECT i HOLD gir eksakt Landauer-varme (dQ = 5 LU)\n");
}

/* Test 3: Poincare-kryssing (Sigma) - drift gir REJECT, koherens gir sigma_ok */
static void test_poincare_crossing(void) {
    sluse_state_t s = make_default_state();
    s.q[0] = -2;
    s.p[0] = 3;

    /* Drift: q_ny = 1, m = 5 => delta_sigma = 4 (mellom 2 og 6 => REJECT) */
    sluse_input_t in_drift = {
        .f = {0, 0, 0}, .m = {5, 0, 0},
        .dP = 2, .dV = 3, .dS = 3, .dT = 2,
        .evidence_id = 0ULL, .bridge_busy = 0U, .hw_veto = 0U
    };
    uint8_t u = 1U;
    gate_event_t ev = sluse_step(&s, &in_drift, &u);
    assert(ev == PORT_REJECT);
    assert(u == 0U);
    assert(s.sigma_ok == 0U);
    assert(s.attached == 1U);

    /* Godkjent kryssing: q_ny = 1, m = 2 => delta_sigma = 1 (<= 2 => sigma_ok = 1) */
    s.q[0] = -2;
    s.p[0] = 3;
    sluse_input_t in_ok = in_drift;
    in_ok.m[0] = 2;

    ev = sluse_step(&s, &in_ok, &u);
    assert(ev == PORT_HOLD);
    assert(u == 0U);
    assert(s.sigma_ok == 1U);
    printf("[OK] Test 3: Poincare-flate (Sigma) skiller drift fra godkjent retur\n");
}

/* Test 4: Maxwell-symmetri - brudd eller null-nevner blokkerer OPEN */
static void test_maxwell_gate(void) {
    sluse_state_t s = make_default_state();
    s.sigma_ok = 1U;
    s.fix_streak = 4U;

    /* Ugyldig symmetri: 2*3 != 4*2 */
    sluse_input_t in_bad = {
        .f = {0, 0, 0}, .m = {0, 0, 0},
        .dP = 2, .dV = 3, .dS = 4, .dT = 2,
        .evidence_id = 42ULL, .bridge_busy = 0U, .hw_veto = 0U
    };
    uint8_t u = 1U;
    gate_event_t ev = sluse_step(&s, &in_bad, &u);
    assert(ev == PORT_HOLD);
    assert(u == 0U);
    assert(s.maxwell_ok == 0U);

    /* Null-beskyttelse: dT == 0 */
    in_bad.dT = 0;
    ev = sluse_step(&s, &in_bad, &u);
    assert(ev == PORT_HOLD);
    assert(u == 0U);
    assert(s.maxwell_ok == 0U);
    printf("[OK] Test 4: Maxwell-porten feiler lukket ved brutt symmetri og dT = 0\n");
}

/* Test 5: Enveis-loven for OPEN - krever evidence_id og fri bro */
static void test_open_one_way_law(void) {
    sluse_state_t s = make_default_state();
    s.sigma_ok = 1U;
    s.fix_streak = 4U;

    sluse_input_t in = {
        .f = {0, 0, 0}, .m = {0, 0, 0},
        .dP = 3, .dV = 4, .dS = 6, .dT = 2, /* 3*4 == 6*2 */
        .evidence_id = 0ULL, .bridge_busy = 0U, .hw_veto = 0U
    };
    uint8_t u = 1U;

    /* Uten evidence_id -> HOLD */
    assert(sluse_step(&s, &in, &u) == PORT_HOLD);
    assert(u == 0U);

    /* Med evidence_id men opptatt bro -> HOLD */
    in.evidence_id = 99ULL;
    in.bridge_busy = 1U;
    assert(sluse_step(&s, &in, &u) == PORT_HOLD);
    assert(u == 0U);

    /* Med evidence_id og fri bro -> OPEN (5.00 V) */
    in.bridge_busy = 0U;
    uint64_t wal_before = s.wal_seq;
    assert(sluse_step(&s, &in, &u) == PORT_OPEN);
    assert(u == 1U);
    assert(s.wal_seq == wal_before + 1ULL);
    printf("[OK] Test 5: OPEN frigir kun ved grønn sluse + evidence_id + fri bro\n");
}

/* Test 6: KILL - frakobling, sveising av R_bound og laast tilstand */
static void test_kill_detachment_and_welding(void) {
    /* 6A: Kritisk Poincare-kollaps */
    sluse_state_t s = make_default_state();
    s.q[0] = -1;
    s.p[0] = 2;
    sluse_input_t in = {
        .f = {0, 0, 0}, .m = {10, 0, 0}, /* q_ny=1 => delta_sigma=9 > 6 */
        .dP = 2, .dV = 3, .dS = 3, .dT = 2,
        .evidence_id = 1ULL, .bridge_busy = 0U, .hw_veto = 0U
    };
    uint8_t u = 1U;

    assert(sluse_step(&s, &in, &u) == PORT_KILL);
    assert(u == 0U);
    assert(s.attached == 0U);
    assert(s.R_bound == 15);
    assert(s.wal_seq == 1ULL);

    /* 6B: Allerede i KILL forblir frakoblet */
    in.m[0] = 1;
    assert(sluse_step(&s, &in, &u) == PORT_KILL);
    assert(u == 0U);
    assert(s.attached == 0U);

    /* 6C: Termisk KILL ved Q_heat >= Q_max */
    s = make_default_state();
    s.q[0] = 15;
    s.p[0] = 5;
    s.Q_heat = 60U;
    assert(sluse_step(&s, &in, &u) == PORT_KILL);
    assert(u == 0U);
    assert(s.attached == 0U);
    assert(s.R_bound == 15);

    /* 6D: Fysisk kobber-kutt (hw_veto = 1) */
    s = make_default_state();
    in.hw_veto = 1U;
    assert(sluse_step(&s, &in, &u) == PORT_KILL);
    assert(u == 0U);
    assert(s.attached == 0U);
    assert(s.R_bound == 15);
    printf("[OK] Test 6: KILL kobler fra monitor, sveiser R_bound og holder låsen\n");
}

int main(void) {
    test_hold_time_never_opens();
    test_reject_landauer_heat();
    test_poincare_crossing();
    test_maxwell_gate();
    test_open_one_way_law();
    test_kill_detachment_and_welding();
    printf("ALLE 6 TESTER BESTÅTT (0 FLOAT, FAIL-CLOSED VERIFISERT).\n");
    return 0;
}
