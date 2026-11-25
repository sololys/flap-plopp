// Flap & Plopp — 10-Node LiH Combinational Sluse Gate (SystemVerilog RTL Mirror)
// Bit-exact hardware mirror of c11_qnx/lih_sluse_gate.c (40 800 ps window, 0 float)
`timescale 1ns/1ps

module lih_sluse_gate (
    input  logic [11:0] active_nodes_mask,
    input  logic [1:0]  swap_layers,
    input  logic [15:0] delta_temp_mk,
    input  logic [15:0] gamma_q4_12,
    input  logic        lut_valid,
    input  logic        op_requested,
    output logic [1:0]  port_state,   // 2'b00 = HOLD, 2'b01 = OPEN, 2'b10 = KILL
    output logic        awg_drive_en  // Fysisk port til DAC/AWG
);
    localparam logic [11:0] MASKED_NODES = 12'b0000_1001_0000; // Q7 og Q4
    localparam logic [15:0] TEMP_LIMIT   = 16'd300;
    localparam logic [15:0] GAMMA_LIMIT  = 16'd4342;
    localparam logic [15:0] WINDOW_MAX   = 16'd40800;
    localparam logic [15:0] BUFFER_MIN   = 16'd1400;

    logic [15:0] total_latency_ps;
    logic        kill_cond;

    always_comb begin
        total_latency_ps = ({14'd0, swap_layers} * 16'd12400) + 16'd9600 + 16'd4100 + 16'd900;

        kill_cond = ((active_nodes_mask & MASKED_NODES) != 12'd0) ||
                    (delta_temp_mk >= TEMP_LIMIT) ||
                    (swap_layers > 2'd2) ||
                    (!lut_valid) ||
                    (gamma_q4_12 < GAMMA_LIMIT) ||
                    (total_latency_ps > (WINDOW_MAX - BUFFER_MIN));

        if (kill_cond) begin
            port_state   = 2'b10; // KILL: Kutt kobber/mikroboelge-utgang
            awg_drive_en = 1'b0;
        end else if (op_requested) begin
            port_state   = 2'b01; // OPEN: Slipp gjennom pulstog
            awg_drive_en = 1'b1;
        end else begin
            port_state   = 2'b00; // HOLD: 0.00 V faserom
            awg_drive_en = 1'b0;
        end
    end
endmodule
