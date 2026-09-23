`include "cpu_defines.vh"

module tb_alu;

    reg  [3:0]  op;
    reg  [15:0] a, b;
    reg         carry_in, decimal;
    wire [15:0] result;
    wire        carry_out, zero, negative, overflow_out;

    alu uut (
        .op           (op),
        .a            (a),
        .b            (b),
        .carry_in     (carry_in),
        .decimal      (decimal),
        .result       (result),
        .carry_out    (carry_out),
        .zero         (zero),
        .negative     (negative),
        .overflow_out (overflow_out)
    );

    integer pass_count = 0;
    integer fail_count = 0;

    task check;
        input [15:0] exp_result;
        input        exp_carry;
        input        exp_zero;
        input        exp_neg;
        input [127:0] name;
        begin
            if (result !== exp_result || carry_out !== exp_carry ||
                zero !== exp_zero || negative !== exp_neg) begin
                $display("FAIL %0s: got result=%04X C=%b Z=%b N=%b, expected %04X C=%b Z=%b N=%b",
                         name, result, carry_out, zero, negative,
                         exp_result, exp_carry, exp_zero, exp_neg);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS %0s", name);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);
        decimal = 1'b0;
        carry_in = 1'b0;

        // ---- ADC ----
        op = `ALU_ADC; a = 16'h0001; b = 16'h0002; carry_in = 1'b0;
        #1; check(16'h0003, 1'b0, 1'b0, 1'b0, "ADC 1+2");

        op = `ALU_ADC; a = 16'hFFFF; b = 16'h0001; carry_in = 1'b0;
        #1; check(16'h0000, 1'b1, 1'b1, 1'b0, "ADC FFFF+1 carry");

        op = `ALU_ADC; a = 16'h0001; b = 16'h0001; carry_in = 1'b1;
        #1; check(16'h0003, 1'b0, 1'b0, 1'b0, "ADC 1+1+C");

        op = `ALU_ADC; a = 16'h7FFF; b = 16'h0001; carry_in = 1'b0;
        #1; check(16'h8000, 1'b0, 1'b0, 1'b1, "ADC overflow pos");

        op = `ALU_ADC; a = 16'h0000; b = 16'h0000; carry_in = 1'b0;
        #1; check(16'h0000, 1'b0, 1'b1, 1'b0, "ADC 0+0 zero");

        // ---- SBC ----
        carry_in = 1'b1; // SBC: carry=1 means no borrow
        op = `ALU_SBC; a = 16'h0005; b = 16'h0003;
        #1; check(16'h0002, 1'b1, 1'b0, 1'b0, "SBC 5-3");

        op = `ALU_SBC; a = 16'h0000; b = 16'h0001; carry_in = 1'b1;
        #1; check(16'hFFFF, 1'b0, 1'b0, 1'b1, "SBC 0-1 borrow");

        op = `ALU_SBC; a = 16'h0005; b = 16'h0005; carry_in = 1'b1;
        #1; check(16'h0000, 1'b1, 1'b1, 1'b0, "SBC 5-5 zero");

        op = `ALU_SBC; a = 16'h0003; b = 16'h0001; carry_in = 1'b0;
        #1; check(16'h0001, 1'b1, 1'b0, 1'b0, "SBC 3-1-borrow");

        // ---- AND ----
        op = `ALU_AND; a = 16'hFF00; b = 16'h0F0F; carry_in = 1'b0;
        #1; check(16'h0F00, 1'b0, 1'b0, 1'b0, "AND FF00 & 0F0F");

        op = `ALU_AND; a = 16'hAAAA; b = 16'h5555; carry_in = 1'b0;
        #1; check(16'h0000, 1'b0, 1'b1, 1'b0, "AND AAAA & 5555 zero");

        // ---- ORA ----
        op = `ALU_ORA; a = 16'hF000; b = 16'h000F; carry_in = 1'b0;
        #1; check(16'hF00F, 1'b0, 1'b0, 1'b1, "ORA F000 | 000F");

        // ---- EOR ----
        op = `ALU_EOR; a = 16'hFFFF; b = 16'hFFFF; carry_in = 1'b0;
        #1; check(16'h0000, 1'b0, 1'b1, 1'b0, "EOR FFFF ^ FFFF");

        op = `ALU_EOR; a = 16'hAAAA; b = 16'h5555; carry_in = 1'b0;
        #1; check(16'hFFFF, 1'b0, 1'b0, 1'b1, "EOR AAAA ^ 5555");

        // ---- ASL ----
        op = `ALU_ASL; a = 16'h4000; carry_in = 1'b0;
        #1; check(16'h8000, 1'b0, 1'b0, 1'b1, "ASL 4000");

        op = `ALU_ASL; a = 16'h8001; carry_in = 1'b0;
        #1; check(16'h0002, 1'b1, 1'b0, 1'b0, "ASL 8001 carry");

        // ---- LSR ----
        op = `ALU_LSR; a = 16'h0002; carry_in = 1'b0;
        #1; check(16'h0001, 1'b0, 1'b0, 1'b0, "LSR 0002");

        op = `ALU_LSR; a = 16'h0001; carry_in = 1'b0;
        #1; check(16'h0000, 1'b1, 1'b1, 1'b0, "LSR 0001 carry");

        // ---- ROL ----
        op = `ALU_ROL; a = 16'h8000; carry_in = 1'b1;
        #1; check(16'h0001, 1'b1, 1'b0, 1'b0, "ROL 8000 C=1");

        op = `ALU_ROL; a = 16'h4000; carry_in = 1'b0;
        #1; check(16'h8000, 1'b0, 1'b0, 1'b1, "ROL 4000 C=0");

        // ---- ROR ----
        op = `ALU_ROR; a = 16'h0001; carry_in = 1'b1;
        #1; check(16'h8000, 1'b1, 1'b0, 1'b1, "ROR 0001 C=1");

        op = `ALU_ROR; a = 16'h0002; carry_in = 1'b0;
        #1; check(16'h0001, 1'b0, 1'b0, 1'b0, "ROR 0002 C=0");

        // ---- INC ----
        op = `ALU_INC; a = 16'h00FF; carry_in = 1'b0;
        #1; check(16'h0100, 1'b0, 1'b0, 1'b0, "INC 00FF");

        op = `ALU_INC; a = 16'hFFFF; carry_in = 1'b0;
        #1; check(16'h0000, 1'b0, 1'b1, 1'b0, "INC FFFF wrap");

        // ---- DEC ----
        op = `ALU_DEC; a = 16'h0100; carry_in = 1'b0;
        #1; check(16'h00FF, 1'b0, 1'b0, 1'b0, "DEC 0100");

        op = `ALU_DEC; a = 16'h0000; carry_in = 1'b0;
        #1; check(16'hFFFF, 1'b0, 1'b0, 1'b1, "DEC 0000 wrap");

        // ---- CMP ----
        op = `ALU_CMP; a = 16'h0005; b = 16'h0003; carry_in = 1'b1;
        #1; check(16'h0002, 1'b1, 1'b0, 1'b0, "CMP 5>3");

        op = `ALU_CMP; a = 16'h0003; b = 16'h0003; carry_in = 1'b1;
        #1; check(16'h0000, 1'b1, 1'b1, 1'b0, "CMP 3==3");

        op = `ALU_CMP; a = 16'h0002; b = 16'h0005; carry_in = 1'b1;
        #1; check(16'hFFFD, 1'b0, 1'b0, 1'b1, "CMP 2<5");

        // ---- BIT ----
        op = `ALU_BIT; a = 16'h00FF; b = 16'hC000; carry_in = 1'b0;
        #1;
        if (result !== 16'h0000 || zero !== 1'b1 ||
            negative !== 1'b1 || overflow_out !== 1'b1) begin
            $display("FAIL BIT: result=%04X Z=%b N=%b V=%b", result, zero, negative, overflow_out);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS BIT C000 & 00FF");
            pass_count = pass_count + 1;
        end

        // ---- TSB ----
        op = `ALU_TSB; a = 16'h00F0; b = 16'h0F00; carry_in = 1'b0;
        #1;
        if (result !== 16'h0FF0 || zero !== 1'b1) begin
            $display("FAIL TSB: result=%04X Z=%b", result, zero);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS TSB no overlap");
            pass_count = pass_count + 1;
        end

        // ---- TRB ----
        op = `ALU_TRB; a = 16'h00FF; b = 16'h0FF0; carry_in = 1'b0;
        #1;
        if (result !== 16'h0F00 || zero !== 1'b0) begin
            $display("FAIL TRB: result=%04X Z=%b", result, zero);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS TRB with overlap");
            pass_count = pass_count + 1;
        end

        // ---- PASS ----
        op = `ALU_PASS; b = 16'h1234; carry_in = 1'b0;
        #1; check(16'h1234, 1'b0, 1'b0, 1'b0, "PASS 1234");

        // ---- BCD ADC ----
        decimal = 1'b1;
        op = `ALU_ADC; a = 16'h0019; b = 16'h0001; carry_in = 1'b0;
        #1;
        if (result !== 16'h0020) begin
            $display("FAIL BCD ADC: 19+01 got %04X expected 0020", result);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS BCD ADC 19+01=20");
            pass_count = pass_count + 1;
        end

        decimal = 1'b1;
        op = `ALU_ADC; a = 16'h0099; b = 16'h0001; carry_in = 1'b0;
        #1;
        if (result !== 16'h0100) begin
            $display("FAIL BCD ADC: 99+01 got %04X expected 0100", result);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS BCD ADC 99+01=100");
            pass_count = pass_count + 1;
        end
        decimal = 1'b0;

        // Summary
        $display("");
        $display("========================================");
        $display("ALU Tests: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================");
        if (fail_count > 0) $display("*** FAILURES DETECTED ***");
        $finish;
    end

endmodule
