// Flap & Plopp — Document 185 KORA Sluse Gate (SystemVerilog RTL Mirror)
// Bit-exact hardware mirror of c11_qnx/ky_kora_sluse.c with synchronous H_latch KILL register
`timescale 1ns/1ps

module ky_kora_sluse (
    input  logic               clk,
    input  logic               rst_n,              // Kun fysisk Level 01 reset sletter KILL

    // Kandidat x' = Phi(x)
    input  logic [11:0]        active_nodes_mask,
    input  logic [7:0]         swap_layers,
    input  logic [31:0]        predicted_latency_ps,

    // Projeksjonsavvik Delta_K (Q4.12)
    input  logic [15:0]        delta_k_q4_12,

    // Poincare-returflate Sigma: m_return vs R(x_return) (Q4.12 signed)
    input  logic signed [31:0] m_return_q4_12,
    input  logic signed [31:0] r_x_return_q4_12,

    // Maxwell / Schwarz-port: kryssderiverte (Q4.12 signed)
    input  logic signed [31:0] dP_dT_V_q4_12,
    input  logic signed [31:0] dS_dV_T_q4_12,

    // Witness^2 & Level 01 suverenitet
    input  logic [63:0]        next_witness_seq,
    input  logic               audit_verified,
    input  logic               level01_authorize,
    input  logic               step_valid,         // Klokkepuls for ny evaluering

    // Utganger til fysisk sluse og logg
    output logic [1:0]         port_state,         // 2'b00=HOLD, 2'b01=OPEN, 2'b10=KILL
    output logic               open_5v_en,         // 1 = 5.00 V DC, 0 = 0.00 V DC
    output logic               latched_kill,       // 1 = Latchet KILL i H_latch
    output logic [31:0]        delta_sigma_q4_12,
    output logic [31:0]        delta_maxwell_q4_12,
    output logic [63:0]        committed_seq
);

    // Kanoniske terskler (bit-eksakt lik C11)
    localparam logic [11:0] MASKED_NODE_MASK  = 12'b0000_1001_0000; // Q7 og Q4
    localparam logic [31:0] OPEN_LIMIT_PS     = 32'd39400;
    localparam logic [15:0] EPS_ADM_Q4_12     = 16'd64;
    localparam logic [15:0] EPS_CRIT_Q4_12    = 16'd256;
    localparam logic [31:0] EPS_MAXWELL_Q4_12 = 32'd32;

    localparam logic [1:0]  PORT_HOLD         = 2'b00;
    localparam logic [1:0]  PORT_OPEN         = 2'b01;
    localparam logic [1:0]  PORT_KILL         = 2'b10;

    // Tilstandsregistre (H_fermion & H_latch)
    logic        latched_kill_q;
    logic [63:0] witness_seq_q;

    // 33-bit differanser for overflow-fri absoluttverdi
    logic signed [32:0] diff_sigma;
    logic signed [32:0] diff_maxwell;
    logic [32:0]        abs_sigma_33;
    logic [32:0]        abs_maxwell_33;

    logic kill_trigger;
    logic hold_trigger;

    always_comb begin
        diff_sigma   = $signed({m_return_q4_12[31], m_return_q4_12}) -
                       $signed({r_x_return_q4_12[31], r_x_return_q4_12});
        diff_maxwell = $signed({dP_dT_V_q4_12[31], dP_dT_V_q4_12}) -
                       $signed({dS_dV_T_q4_12[31], dS_dV_T_q4_12});

        abs_sigma_33   = diff_sigma[32]   ? (-diff_sigma)   : diff_sigma;
        abs_maxwell_33 = diff_maxwell[32] ? (-diff_maxwell) : diff_maxwell;

        delta_sigma_q4_12   = abs_sigma_33[31:0];
        delta_maxwell_q4_12 = abs_maxwell_33[31:0];

        // Fail-closed KILL-betingelser (Lov 2, Pi_K, Schwarz, kritisk drift)
        kill_trigger = latched_kill_q ||
                       (!audit_verified) ||
                       (next_witness_seq != (witness_seq_q + 64'd1)) ||
                       ((active_nodes_mask & MASKED_NODE_MASK) != 12'd0) ||
                       (swap_layers > 8'd2) ||
                       (predicted_latency_ps > OPEN_LIMIT_PS) ||
                       (delta_maxwell_q4_12 > EPS_MAXWELL_Q4_12) ||
                       (delta_k_q4_12 > EPS_CRIT_Q4_12) ||
                       (delta_sigma_q4_12 > {16'd0, EPS_CRIT_Q4_12});

        // Mellomsone -> HOLD (0.00 V DC) for rekalibrering eller manglende Level 01
        hold_trigger = (delta_k_q4_12 > EPS_ADM_Q4_12) ||
                       (delta_sigma_q4_12 > {16'd0, EPS_ADM_Q4_12}) ||
                       (!level01_authorize);

        // Kombinatorisk portutgang (0 syklus forsinkelse paa kutt)
        if (kill_trigger) begin
            port_state = PORT_KILL;
            open_5v_en = 1'b0;
        end else if (!step_valid || hold_trigger) begin
            port_state = PORT_HOLD;
            open_5v_en = 1'b0;
        end else begin
            port_state = PORT_OPEN;
            open_5v_en = 1'b1;
        end
    end

    // Synkron forsegling i H_latch og historiefiberen
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latched_kill_q <= 1'b0;
            witness_seq_q  <= 64'd0;
        end else if (step_valid) begin
            if (kill_trigger) begin
                latched_kill_q <= 1'b1; // Sveiset fast til fysisk reset
            end else begin
                witness_seq_q  <= next_witness_seq;
            end
        end
    end

    assign latched_kill  = latched_kill_q || (step_valid && kill_trigger);
    assign committed_seq = witness_seq_q;

endmodule
