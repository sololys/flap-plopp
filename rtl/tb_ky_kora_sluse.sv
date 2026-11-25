// SystemVerilog Testbench for ky_kora_sluse (7/7 bit-exact parity with C11)
`timescale 1ns/1ps

module tb_ky_kora_sluse;
    logic               clk = 1'b0;
    logic               rst_n = 1'b0;
    logic [11:0]        active_nodes_mask;
    logic [7:0]         swap_layers;
    logic [31:0]        predicted_latency_ps;
    logic [15:0]        delta_k_q4_12;
    logic signed [31:0] m_return_q4_12;
    logic signed [31:0] r_x_return_q4_12;
    logic signed [31:0] dP_dT_V_q4_12;
    logic signed [31:0] dS_dV_T_q4_12;
    logic [63:0]        next_witness_seq;
    logic               audit_verified;
    logic               level01_authorize;
    logic               step_valid;

    logic [1:0]         port_state;
    logic               open_5v_en;
    logic               latched_kill;
    logic [31:0]        delta_sigma_q4_12;
    logic [31:0]        delta_maxwell_q4_12;
    logic [63:0]        committed_seq;

    ky_kora_sluse dut (
        .clk(clk),
        .rst_n(rst_n),
        .active_nodes_mask(active_nodes_mask),
        .swap_layers(swap_layers),
        .predicted_latency_ps(predicted_latency_ps),
        .delta_k_q4_12(delta_k_q4_12),
        .m_return_q4_12(m_return_q4_12),
        .r_x_return_q4_12(r_x_return_q4_12),
        .dP_dT_V_q4_12(dP_dT_V_q4_12),
        .dS_dV_T_q4_12(dS_dV_T_q4_12),
        .next_witness_seq(next_witness_seq),
        .audit_verified(audit_verified),
        .level01_authorize(level01_authorize),
        .step_valid(step_valid),
        .port_state(port_state),
        .open_5v_en(open_5v_en),
        .latched_kill(latched_kill),
        .delta_sigma_q4_12(delta_sigma_q4_12),
        .delta_maxwell_q4_12(delta_maxwell_q4_12),
        .committed_seq(committed_seq)
    );

    always #5 clk = ~clk;

    task automatic set_nominal(input logic [63:0] seq);
        active_nodes_mask    = 12'b1111_0110_1111;
        swap_layers          = 8'd2;
        predicted_latency_ps = 32'd39400;
        delta_k_q4_12        = 16'd32;
        m_return_q4_12       = 32'sd1000;
        r_x_return_q4_12     = 32'sd960;  // delta_sigma = 40 <= 64
        dP_dT_V_q4_12        = 32'sd2000;
        dS_dV_T_q4_12        = 32'sd1980; // delta_maxwell = 20 <= 32
        next_witness_seq     = seq;
        audit_verified       = 1'b1;
        level01_authorize    = 1'b1;
        step_valid           = 1'b1;
    endtask

    task automatic check_step(
        input logic [1:0] exp_port,
        input logic       exp_5v,
        input logic       exp_latch,
        input string      name
    );
        #1;
        if (port_state !== exp_port || open_5v_en !== exp_5v || latched_kill !== exp_latch) begin
            $display("FAIL %s: got port=%b 5v=%b latch=%b, exp port=%b 5v=%b latch=%b",
                     name, port_state, open_5v_en, latched_kill, exp_port, exp_5v, exp_latch);
            $fatal(1);
        end
        @(posedge clk);
        #1;
    endtask

    initial begin
        // Reset
        set_nominal(64'd1);
        step_valid = 1'b0;
        rst_n = 1'b0;
        @(posedge clk);
        #1;
        rst_n = 1'b1;

        // 1. Nominal OPEN (5.00 V DC), seq 0 -> 1
        set_nominal(64'd1);
        check_step(2'b01, 1'b1, 1'b0, "1_nominal_open");
        if (committed_seq !== 64'd1) $fatal(1);

        // 2. Poincare drift in mid-zone (120) -> HOLD, seq 1 -> 2
        set_nominal(64'd2);
        r_x_return_q4_12 = 32'sd880;
        check_step(2'b00, 1'b0, 1'b0, "2_poincare_drift_hold");
        if (committed_seq !== 64'd2) $fatal(1);

        // 3. Recalibrated return -> OPEN, seq 2 -> 3
        set_nominal(64'd3);
        check_step(2'b01, 1'b1, 1'b0, "3_recalibrated_open");
        if (committed_seq !== 64'd3) $fatal(1);

        // 4. Missing Level 01 auth -> HOLD, seq 3 -> 4
        set_nominal(64'd4);
        level01_authorize = 1'b0;
        check_step(2'b00, 1'b0, 1'b0, "4_no_level01_hold");
        if (committed_seq !== 64'd4) $fatal(1);

        // 5. Schwarz/Maxwell breach (100 > 32) -> latched KILL
        set_nominal(64'd5);
        dS_dV_T_q4_12 = 32'sd1900;
        check_step(2'b10, 1'b0, 1'b1, "5_maxwell_breach_kill");

        // 6. Post-KILL latch immunity: valid nominal input stays KILL
        set_nominal(64'd5);
        check_step(2'b10, 1'b0, 1'b1, "6_post_kill_latch_immunity");

        // 7. Physical rst_n clears latch and allows fresh seq=1 OPEN
        rst_n = 1'b0;
        step_valid = 1'b0;
        @(posedge clk);
        #1;
        rst_n = 1'b1;
        set_nominal(64'd1);
        check_step(2'b01, 1'b1, 1'b0, "7_physical_reset_recovery");

        $display("KY_KORA_RTL_PASS tests=7/7 latch_immunity=1");
        $finish;
    end
endmodule
