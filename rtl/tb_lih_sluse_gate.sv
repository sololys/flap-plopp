// SystemVerilog Testbench for lih_sluse_gate (7/7 boundary scenarios)
`timescale 1ns/1ps

module tb_lih_sluse_gate;
    logic [11:0] active_nodes_mask;
    logic [1:0]  swap_layers;
    logic [15:0] delta_temp_mk;
    logic [15:0] gamma_q4_12;
    logic        lut_valid;
    logic        op_requested;
    logic [1:0]  port_state;
    logic        awg_drive_en;

    lih_sluse_gate dut (
        .active_nodes_mask(active_nodes_mask),
        .swap_layers(swap_layers),
        .delta_temp_mk(delta_temp_mk),
        .gamma_q4_12(gamma_q4_12),
        .lut_valid(lut_valid),
        .op_requested(op_requested),
        .port_state(port_state),
        .awg_drive_en(awg_drive_en)
    );

    task automatic check(input logic [1:0] exp_port, input logic exp_awg, input string name);
        #1;
        if (port_state !== exp_port || awg_drive_en !== exp_awg) begin
            $display("FAIL %s: got port=%b awg=%b, expected port=%b awg=%b",
                     name, port_state, awg_drive_en, exp_port, exp_awg);
            $fatal(1);
        end
    endtask

    initial begin
        // 1. Nominal OPEN (39 400 ps, 2 SWAP layers, Q4/Q7 excluded, 299 mK, gamma=4342)
        active_nodes_mask = 12'b1111_0110_1111;
        swap_layers       = 2'd2;
        delta_temp_mk     = 16'd299;
        gamma_q4_12       = 16'd4342;
        lut_valid         = 1'b1;
        op_requested      = 1'b1;
        check(2'b01, 1'b1, "1_nominal_open_39400ps");

        // 2. HOLD (op_requested = 0 -> 0.00 V)
        op_requested = 1'b0;
        check(2'b00, 1'b0, "2_reversible_hold");

        // 3. KILL on Q4 touch
        op_requested      = 1'b1;
        active_nodes_mask = 12'b1111_0111_1111;
        check(2'b10, 1'b0, "3_q4_mask_kill");

        // 4. KILL on Q7 touch
        active_nodes_mask = 12'b1111_1110_1111;
        check(2'b10, 1'b0, "4_q7_mask_kill");

        // 5. KILL on 3x SWAP
        active_nodes_mask = 12'b1111_0110_1111;
        swap_layers       = 2'd3;
        check(2'b10, 1'b0, "5_swap3_kill");

        // 6. KILL on 300 mK thermal limit
        swap_layers   = 2'd2;
        delta_temp_mk = 16'd300;
        check(2'b10, 1'b0, "6_temp_300mk_kill");

        // 7. KILL on Riccati gamma = 4301 (~1.05 < 1.06) & invalid LUT
        delta_temp_mk = 16'd250;
        gamma_q4_12   = 16'd4301;
        check(2'b10, 1'b0, "7a_riccati_1_05_kill");
        gamma_q4_12 = 16'd4342;
        lut_valid   = 1'b0;
        check(2'b10, 1'b0, "7b_invalid_lut_kill");

        $display("LIH_SLUSE_RTL_PASS tests=7/7 awg_fail_closed=1");
        $finish;
    end
endmodule
