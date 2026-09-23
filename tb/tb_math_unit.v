`include "cpu_defines.vh"
`timescale 1ns / 1ps

module tb_math_unit;

    reg         clk, rst_n;
    reg         mul_start, div_start;
    reg  [15:0] mul_a, mul_b;
    reg  [31:0] div_dividend;
    reg  [15:0] div_divisor;
    wire [31:0] mul_result;
    wire        mul_done;
    wire [15:0] div_quotient, div_remainder;
    wire        div_done, div_overflow;
    reg         cum_add, cum_clear;
    wire [39:0] cum_sum;

    math_unit uut (
        .clk          (clk),
        .rst_n        (rst_n),
        .mul_start    (mul_start),
        .mul_a        (mul_a),
        .mul_b        (mul_b),
        .mul_result   (mul_result),
        .mul_done     (mul_done),
        .div_start    (div_start),
        .div_dividend (div_dividend),
        .div_divisor  (div_divisor),
        .div_quotient (div_quotient),
        .div_remainder(div_remainder),
        .div_done     (div_done),
        .div_overflow (div_overflow),
        .cum_add      (cum_add),
        .cum_clear    (cum_clear),
        .cum_sum      (cum_sum)
    );

    always #5 clk = ~clk;

    integer pass_count = 0;
    integer fail_count = 0;

    task do_multiply;
        input [15:0] a_val, b_val;
        input [31:0] expected;
        input [127:0] name;
        begin
            @(posedge clk);
            mul_a = a_val;
            mul_b = b_val;
            mul_start = 1'b1;
            @(posedge clk);
            mul_start = 1'b0;
            // Wait for done
            wait (mul_done);
            @(posedge clk);
            if (mul_result !== expected) begin
                $display("FAIL %0s: %0d * %0d = %0d, expected %0d",
                         name, a_val, b_val, mul_result, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS %0s: %0d * %0d = %0d", name, a_val, b_val, mul_result);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task do_divide;
        input [31:0] dividend;
        input [15:0] divisor;
        input [15:0] exp_quot, exp_rem;
        input        exp_ovf;
        input [127:0] name;
        begin
            @(posedge clk);
            div_dividend = dividend;
            div_divisor  = divisor;
            div_start    = 1'b1;
            @(posedge clk);
            div_start = 1'b0;
            wait (div_done);
            @(posedge clk);
            if (exp_ovf) begin
                if (div_overflow !== 1'b1) begin
                    $display("FAIL %0s: expected overflow", name);
                    fail_count = fail_count + 1;
                end else begin
                    $display("PASS %0s: divide by zero overflow", name);
                    pass_count = pass_count + 1;
                end
            end else if (div_quotient !== exp_quot || div_remainder !== exp_rem) begin
                $display("FAIL %0s: %0d / %0d = Q:%0d R:%0d, expected Q:%0d R:%0d",
                         name, dividend, divisor, div_quotient, div_remainder, exp_quot, exp_rem);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS %0s: %0d / %0d = Q:%0d R:%0d",
                         name, dividend, divisor, div_quotient, div_remainder);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_math_unit.vcd");
        $dumpvars(0, tb_math_unit);

        clk = 0; rst_n = 0;
        mul_start = 0; div_start = 0;
        mul_a = 0; mul_b = 0;
        div_dividend = 0; div_divisor = 0;
        cum_add = 0; cum_clear = 0;

        repeat(4) @(posedge clk);
        rst_n = 1;

        // ---- Multiply tests ----
        $display("--- Multiply Tests ---");
        do_multiply(16'd0,     16'd0,     32'd0,         "MUL 0*0");
        do_multiply(16'd1,     16'd1,     32'd1,         "MUL 1*1");
        do_multiply(16'd100,   16'd200,   32'd20000,     "MUL 100*200");
        do_multiply(16'd256,   16'd256,   32'd65536,     "MUL 256*256");
        do_multiply(16'hFFFF,  16'hFFFF,  32'hFFFE0001,  "MUL FFFF*FFFF");
        do_multiply(16'h8000,  16'd2,     32'h00010000,  "MUL 8000*2");
        do_multiply(16'd12345, 16'd6789,  32'd83810205,  "MUL 12345*6789");

        // ---- Divide tests ----
        $display("");
        $display("--- Divide Tests ---");
        do_divide(32'd100,     16'd10,  16'd10, 16'd0,  1'b0, "DIV 100/10");
        do_divide(32'd65535,   16'd256, 16'd255, 16'd255, 1'b0, "DIV 65535/256");
        do_divide(32'd7,       16'd2,   16'd3,  16'd1,  1'b0, "DIV 7/2");
        do_divide(32'd0,       16'd5,   16'd0,  16'd0,  1'b0, "DIV 0/5");
        do_divide(32'd1000,    16'd0,   16'd0,  16'd0,  1'b1, "DIV 1000/0 overflow");
        do_divide(32'd1,       16'd1,   16'd1,  16'd0,  1'b0, "DIV 1/1");
        do_divide(32'd10000,   16'd3,   16'd3333, 16'd1, 1'b0, "DIV 10000/3");

        // ---- Cumulative sum tests ----
        $display("");
        $display("--- Cumulative Sum Tests ---");

        // Clear sum
        @(posedge clk);
        cum_clear = 1'b1;
        @(posedge clk);
        cum_clear = 1'b0;
        @(posedge clk);

        if (cum_sum !== 40'd0) begin
            $display("FAIL CUM_CLEAR: sum=%0d", cum_sum);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS CUM_CLEAR: sum=0");
            pass_count = pass_count + 1;
        end

        // Multiply 10*10=100, then accumulate
        do_multiply(16'd10, 16'd10, 32'd100, "MUL for cum sum");
        // mul_done triggers auto cum_add in top-level, but here we do it manually
        @(posedge clk);
        cum_add = 1'b1;
        @(posedge clk);
        cum_add = 1'b0;
        @(posedge clk);

        if (cum_sum !== 40'd100) begin
            $display("FAIL CUM_SUM after 100: sum=%0d", cum_sum);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS CUM_SUM: 0+100=100");
            pass_count = pass_count + 1;
        end

        // Another multiply 20*20=400, accumulate
        do_multiply(16'd20, 16'd20, 32'd400, "MUL for cum sum 2");
        @(posedge clk);
        cum_add = 1'b1;
        @(posedge clk);
        cum_add = 1'b0;
        @(posedge clk);

        if (cum_sum !== 40'd500) begin
            $display("FAIL CUM_SUM after 400: sum=%0d", cum_sum);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS CUM_SUM: 100+400=500");
            pass_count = pass_count + 1;
        end

        // Summary
        $display("");
        $display("========================================");
        $display("Math Unit Tests: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================");
        if (fail_count > 0) $display("*** FAILURES DETECTED ***");
        $finish;
    end

endmodule
