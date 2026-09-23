`include "cpu_defines.vh"
`timescale 1ns / 1ps

module tb_timer;

    reg        clk, rst_n;
    wire       timer0_irq, timer1_irq;
    reg        reg_wr_en;
    reg        reg_rd_en;
    reg  [3:0] reg_addr;
    reg  [7:0] reg_wr_data;
    wire [7:0] reg_rd_data;

    timer uut (
        .clk        (clk),
        .rst_n      (rst_n),
        .timer0_irq (timer0_irq),
        .timer1_irq (timer1_irq),
        .reg_wr_en  (reg_wr_en),
        .reg_rd_en  (reg_rd_en),
        .reg_addr   (reg_addr),
        .reg_wr_data(reg_wr_data),
        .reg_rd_data(reg_rd_data)
    );

    always #5 clk = ~clk;

    integer pass_count = 0;
    integer fail_count = 0;

    task write_reg;
        input [3:0] addr;
        input [7:0] data;
        begin
            @(posedge clk);
            reg_wr_en   = 1'b1;
            reg_addr    = addr;
            reg_wr_data = data;
            @(posedge clk);
            reg_wr_en = 1'b0;
        end
    endtask

    task read_reg;
        input [3:0] addr;
        output [7:0] data;
        begin
            @(posedge clk);
            reg_wr_en = 1'b0;
            reg_rd_en = 1'b1;
            reg_addr  = addr;
            @(posedge clk);
            data = reg_rd_data;
            reg_rd_en = 1'b0;
        end
    endtask

    reg [7:0] read_val;

    initial begin
        $dumpfile("tb_timer.vcd");
        $dumpvars(0, tb_timer);

        clk = 0; rst_n = 0;
        reg_wr_en = 0; reg_rd_en = 0; reg_addr = 0; reg_wr_data = 0;

        repeat(4) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        $display("--- Timer Tests ---");

        // ---- Test 1: Configure Timer 0 with prescaler=0, reload=5 ----
        $display("Test 1: Timer 0 countdown from 5");

        // Set prescaler to 0 (tick every clock)
        write_reg(4'd1, 8'd0);

        // Set timer 0 reload = 5 (low byte)
        write_reg(4'd2, 8'd5);
        // Set timer 0 reload high + load counter
        write_reg(4'd3, 8'd0);

        // Read back counter
        read_reg(4'd2, read_val);
        if (read_val !== 8'd5) begin
            $display("FAIL: Timer0 count after load = %0d, expected 5", read_val);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS: Timer0 loaded with 5");
            pass_count = pass_count + 1;
        end

        // Enable timer 0 with IRQ
        write_reg(4'd0, 8'b00010001); // timer0_enable=1, timer0_irq_en=1

        // Wait for countdown
        repeat(10) @(posedge clk);

        // Check if timer fired
        if (timer0_irq !== 1'b1) begin
            $display("FAIL: Timer0 IRQ not asserted after countdown");
            fail_count = fail_count + 1;
        end else begin
            $display("PASS: Timer0 IRQ asserted");
            pass_count = pass_count + 1;
        end

        // Read status to clear
        read_reg(4'd0, read_val);
        $display("  Status register: %08b", read_val);

        // ---- Test 2: Timer with prescaler ----
        $display("");
        $display("Test 2: Timer 0 with prescaler=3");

        // Disable timers
        write_reg(4'd0, 8'd0);
        repeat(2) @(posedge clk);

        // Set prescaler to 3 (tick every 4 clocks)
        write_reg(4'd1, 8'd3);

        // Set timer 0 reload = 2
        write_reg(4'd2, 8'd2);
        write_reg(4'd3, 8'd0);

        // Enable timer 0 with IRQ
        write_reg(4'd0, 8'b00010001);

        // Timer should take ~(2+1) * (3+1) = 12 clocks to fire
        // Wait and check
        repeat(8) @(posedge clk);
        if (timer0_irq === 1'b1) begin
            $display("FAIL: Timer0 fired too early with prescaler");
            fail_count = fail_count + 1;
        end else begin
            $display("PASS: Timer0 not yet fired (prescaler active)");
            pass_count = pass_count + 1;
        end

        repeat(20) @(posedge clk);
        if (timer0_irq !== 1'b1) begin
            $display("FAIL: Timer0 never fired with prescaler");
            fail_count = fail_count + 1;
        end else begin
            $display("PASS: Timer0 fired with prescaler");
            pass_count = pass_count + 1;
        end

        // ---- Test 3: Timer 1 independence ----
        $display("");
        $display("Test 3: Timer 1 independent operation");

        // Disable everything
        write_reg(4'd0, 8'd0);
        read_reg(4'd0, read_val); // Clear flags
        repeat(2) @(posedge clk);

        // Set prescaler to 0
        write_reg(4'd1, 8'd0);

        // Set timer 1 reload = 3
        write_reg(4'd4, 8'd3);
        write_reg(4'd5, 8'd0);

        // Enable timer 1 only, with IRQ
        write_reg(4'd0, 8'b00100010); // timer1_enable=1, timer1_irq_en=1

        repeat(8) @(posedge clk);

        if (timer1_irq !== 1'b1) begin
            $display("FAIL: Timer1 IRQ not asserted");
            fail_count = fail_count + 1;
        end else begin
            $display("PASS: Timer1 IRQ asserted independently");
            pass_count = pass_count + 1;
        end

        // Timer 0 should NOT have fired
        if (timer0_irq === 1'b1) begin
            $display("FAIL: Timer0 fired when only Timer1 enabled");
            fail_count = fail_count + 1;
        end else begin
            $display("PASS: Timer0 stayed quiet");
            pass_count = pass_count + 1;
        end

        // ---- Test 4: Auto-reload ----
        $display("");
        $display("Test 4: Auto-reload");

        write_reg(4'd0, 8'd0);
        read_reg(4'd0, read_val);
        repeat(2) @(posedge clk);

        write_reg(4'd1, 8'd0); // prescaler=0
        write_reg(4'd2, 8'd2); // reload=2
        write_reg(4'd3, 8'd0);
        write_reg(4'd0, 8'b00010001); // enable timer0 + IRQ

        // Wait for first fire
        repeat(6) @(posedge clk);
        read_reg(4'd0, read_val); // Clear fired flag

        // Wait for second fire (auto-reload)
        repeat(6) @(posedge clk);
        if (timer0_irq !== 1'b1) begin
            $display("FAIL: Timer0 did not auto-reload and fire again");
            fail_count = fail_count + 1;
        end else begin
            $display("PASS: Timer0 auto-reloaded and fired again");
            pass_count = pass_count + 1;
        end

        // Summary
        $display("");
        $display("========================================");
        $display("Timer Tests: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================");
        if (fail_count > 0) $display("*** FAILURES DETECTED ***");
        $finish;
    end

endmodule
