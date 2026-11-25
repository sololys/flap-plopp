/*
 * Flap & Plopp — 10-Node LiH Bit-Exact Zero-Float C11 HAL Sluse Gate
 * Enforces 40 800 ps window (39 400 ps OPEN limit, 1 400 ps buffer),
 * max 2 parallel SWAP layers, Q4/Q7 TLS mask, 300 mK thermal KILL,
 * and Q4.12 Riccati stability gamma >= 4342 (1.06).
 */

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

/* Fysiske konstanter i heltalls-pikosekunder (ps) og Q4.12 fastpunkt */
#define WINDOW_MAX_PS       40800U
#define BUFFER_MIN_PS        1400U
#define OPEN_LIMIT_PS       (WINDOW_MAX_PS - BUFFER_MIN_PS) /* 39 400 ps */

#define SWAP_COST_PS        12400U
#define CNOT_ROT_COST_PS     9600U
#define EKF_LUT_COST_PS      4100U
#define DAC_OUT_COST_PS       900U

#define MAX_SWAP_LAYERS         2U
#define MASKED_NODE_MASK    ((1U << 4) | (1U << 7)) /* Q4 og Q7 laast ute */
#define TEMP_KILL_MK          300U  /* 0.300 K = 300 mK */
#define GAMMA_MIN_Q4_12      4342U  /* 1.06 * 4096 = 4341.76 -> 4342 */

typedef enum {
    PORT_HOLD = 0, /* Faserom: 0.00 V hvile, reversibel oppstilling */
    PORT_OPEN = 1, /* Sluse: Aktivt pulstog godkjent innenfor 39 400 ps */
    PORT_KILL = 2  /* Frakobling: Fysisk kutt av AWG-drivlinje */
} sluse_port_t;

typedef struct {
    int32_t  k_gain_q4_12;    /* Pre-kalkulert H-inf gain fra BRAM LUT */
    uint16_t gamma_q4_12;     /* Stabilitetsmargin i Q4.12 */
    uint8_t  valid;           /* 1 = gyldig eFUSE/BRAM-oppfoering */
} bram_lut_entry_t;

typedef struct {
    uint16_t active_nodes_mask; /* Bitmaske over involverte qubits (Q0..Q11) */
    uint8_t  swap_layers;       /* Antall parallelle SWAP-lag (0..2) */
    uint16_t lut_index;         /* Indeks fra EKF-residual til BRAM */
    uint16_t delta_temp_mk;     /* Maalt temperaturstigning i mK */
    bool     op_requested;      /* Eksplisitt trigger fra Level 01 */
} pulse_frame_t;

typedef struct {
    sluse_port_t port;
    uint32_t     total_latency_ps;
    uint32_t     margin_ps;
    int32_t      applied_gain_q4_12;
} sluse_verdict_t;

static sluse_verdict_t evaluate_lih_gate(
    const pulse_frame_t *frame,
    const bram_lut_entry_t *lut,
    uint32_t lut_size
) {
    sluse_verdict_t out = {
        .port = PORT_HOLD,
        .total_latency_ps = 0U,
        .margin_ps = WINDOW_MAX_PS,
        .applied_gain_q4_12 = 0
    };

    /* 1. Fail-Closed sjekk: Fysiske og termiske grenser -> KILL */
    if (!frame || !lut) {
        out.port = PORT_KILL;
        return out;
    }
    if ((frame->active_nodes_mask & MASKED_NODE_MASK) != 0U) {
        out.port = PORT_KILL; /* Forsoek paa aa adressere TLS-infisert Q4/Q7 */
        return out;
    }
    if (frame->delta_temp_mk >= TEMP_KILL_MK) {
        out.port = PORT_KILL; /* Termisk grense 0.30 K brutt */
        return out;
    }
    if (frame->swap_layers > MAX_SWAP_LAYERS) {
        out.port = PORT_KILL; /* Topologisk brudd: > 2 SWAP-lag */
        return out;
    }
    if (frame->lut_index >= lut_size || lut[frame->lut_index].valid == 0U) {
        out.port = PORT_KILL; /* EKF utenfor validert LUT-rom */
        return out;
    }

    const bram_lut_entry_t entry = lut[frame->lut_index];
    if (entry.gamma_q4_12 < GAMMA_MIN_Q4_12) {
        out.port = PORT_KILL; /* Riccati-stabilitet under 1.06 */
        return out;
    }

    /* 2. Eksakt heltalls-latensberegning */
    uint32_t latency = ((uint32_t)frame->swap_layers * SWAP_COST_PS)
                     + CNOT_ROT_COST_PS
                     + EKF_LUT_COST_PS
                     + DAC_OUT_COST_PS;

    if (latency > OPEN_LIMIT_PS) {
        out.port = PORT_KILL; /* Kausalitetsmargin < 1 400 ps */
        out.total_latency_ps = latency;
        out.margin_ps = (latency < WINDOW_MAX_PS) ? (WINDOW_MAX_PS - latency) : 0U;
        return out;
    }

    out.total_latency_ps = latency;
    out.margin_ps = WINDOW_MAX_PS - latency;

    /* 3. Ingen eksplisitt trigger -> forbli reversibelt i HOLD (0.00 V) */
    if (!frame->op_requested) {
        out.port = PORT_HOLD;
        return out;
    }

    /* 4. Alle invarianter groenne -> OPEN slipper pulstoget gjennom */
    out.port = PORT_OPEN;
    out.applied_gain_q4_12 = entry.k_gain_q4_12;
    return out;
}

int main(void) {
    const bram_lut_entry_t lut[3] = {
        { .k_gain_q4_12 = 5120, .gamma_q4_12 = 4342U, .valid = 1U }, /* Gyldig nominal (1.06) */
        { .k_gain_q4_12 = 4096, .gamma_q4_12 = 4301U, .valid = 1U }, /* Riccati 1.05 -> KILL */
        { .k_gain_q4_12 = 0,    .gamma_q4_12 = 5000U, .valid = 0U }  /* Ugyldig eFUSE -> KILL */
    };

    /* 1. Nominal worst-case LiH (Q0..Q11 uten Q4/Q7, 2 SWAP-lag = 39 400 ps, 1 400 ps margin) */
    pulse_frame_t nom = {
        .active_nodes_mask = (uint16_t)(0x0FFFU & ~MASKED_NODE_MASK),
        .swap_layers       = 2U,
        .lut_index         = 0U,
        .delta_temp_mk     = 299U,
        .op_requested      = true
    };
    sluse_verdict_t v = evaluate_lih_gate(&nom, lut, 3U);
    assert(v.port == PORT_OPEN);
    assert(v.total_latency_ps == 39400U);
    assert(v.margin_ps == 1400U);
    assert(v.applied_gain_q4_12 == 5120);

    /* 2. HOLD: op_requested = false -> 0.00 V uten gain */
    pulse_frame_t hold_f = nom;
    hold_f.op_requested = false;
    v = evaluate_lih_gate(&hold_f, lut, 3U);
    assert(v.port == PORT_HOLD && v.applied_gain_q4_12 == 0 && v.total_latency_ps == 39400U);

    /* 3. KILL ved Q4 eller Q7 berøring */
    pulse_frame_t q4_f = nom;
    q4_f.active_nodes_mask |= (1U << 4);
    assert(evaluate_lih_gate(&q4_f, lut, 3U).port == PORT_KILL);
    pulse_frame_t q7_f = nom;
    q7_f.active_nodes_mask |= (1U << 7);
    assert(evaluate_lih_gate(&q7_f, lut, 3U).port == PORT_KILL);

    /* 4. KILL ved 3x SWAP (> 2 lag) */
    pulse_frame_t swap3_f = nom;
    swap3_f.swap_layers = 3U;
    assert(evaluate_lih_gate(&swap3_f, lut, 3U).port == PORT_KILL);

    /* 5. KILL ved 300 mK termisk grense */
    pulse_frame_t temp_f = nom;
    temp_f.delta_temp_mk = 300U;
    assert(evaluate_lih_gate(&temp_f, lut, 3U).port == PORT_KILL);

    /* 6. KILL ved Riccati-brudd (gamma = 4301 ~ 1.05 < 1.06) */
    pulse_frame_t ric_f = nom;
    ric_f.lut_index = 1U;
    assert(evaluate_lih_gate(&ric_f, lut, 3U).port == PORT_KILL);

    /* 7. KILL ved ugyldig LUT-oppføring, out-of-bounds, eller NULL */
    pulse_frame_t inv_f = nom;
    inv_f.lut_index = 2U;
    assert(evaluate_lih_gate(&inv_f, lut, 3U).port == PORT_KILL);
    inv_f.lut_index = 9U;
    assert(evaluate_lih_gate(&inv_f, lut, 3U).port == PORT_KILL);
    assert(evaluate_lih_gate(NULL, lut, 3U).port == PORT_KILL);

    printf("LIH_SLUSE_C11_PASS latency_ps=39400 margin_ps=1400 tests=7/7 zero_float=1\n");
    return 0;
}
