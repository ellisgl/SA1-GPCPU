`include "cpu_defines.vh"

module alu (
    input  wire [3:0]  op,
    input  wire [15:0] a,        // First operand
    input  wire [15:0] b,        // Second operand
    input  wire        carry_in,
    input  wire        decimal,  // BCD mode
    output reg  [15:0] result,
    output reg         carry_out,
    output reg         zero,
    output reg         negative,
    output reg         overflow_out
);

    wire [16:0] sum;
    wire [16:0] diff;
    wire        sum_overflow;
    wire        diff_overflow;

    // Binary add/subtract
    assign sum  = {1'b0, a} + {1'b0, b} + {16'd0, carry_in};
    assign diff = {1'b0, a} - {1'b0, b} - {16'd0, ~carry_in};
    assign sum_overflow  = (a[15] == b[15]) && (sum[15] != a[15]);
    assign diff_overflow = (a[15] != b[15]) && (diff[15] != a[15]);

    // BCD add (simplified: correct each nibble)
    reg [16:0] bcd_sum;
    reg [16:0] bcd_diff;
    reg [4:0]  nib0, nib1, nib2, nib3;

    always @(*) begin
        // BCD addition
        nib0 = {1'b0, a[3:0]}  + {1'b0, b[3:0]}  + {4'd0, carry_in};
        if (nib0 > 5'd9) nib0 = nib0 + 5'd6;
        nib1 = {1'b0, a[7:4]}  + {1'b0, b[7:4]}  + {4'd0, nib0[4]};
        if (nib1 > 5'd9) nib1 = nib1 + 5'd6;
        nib2 = {1'b0, a[11:8]} + {1'b0, b[11:8]} + {4'd0, nib1[4]};
        if (nib2 > 5'd9) nib2 = nib2 + 5'd6;
        nib3 = {1'b0, a[15:12]}+ {1'b0, b[15:12]}+ {4'd0, nib2[4]};
        if (nib3 > 5'd9) nib3 = nib3 + 5'd6;

        bcd_sum = {nib3[4], nib3[3:0], nib2[3:0], nib1[3:0], nib0[3:0]};
        bcd_diff = diff; // BCD subtract uses binary result with fixup
    end

    always @(*) begin
        result       = 16'h0000;
        carry_out    = 1'b0;
        zero         = 1'b0;
        negative     = 1'b0;
        overflow_out = 1'b0;

        case (op)
            `ALU_ADC: begin
                if (decimal) begin
                    result    = bcd_sum[15:0];
                    carry_out = bcd_sum[16];
                end else begin
                    result    = sum[15:0];
                    carry_out = sum[16];
                end
                overflow_out = sum_overflow;
            end

            `ALU_SBC: begin
                result       = diff[15:0];
                carry_out    = ~diff[16]; // Borrow is inverted carry
                overflow_out = diff_overflow;
            end

            `ALU_AND: begin
                result = a & b;
            end

            `ALU_ORA: begin
                result = a | b;
            end

            `ALU_EOR: begin
                result = a ^ b;
            end

            `ALU_ASL: begin
                {carry_out, result} = {a, 1'b0};
            end

            `ALU_LSR: begin
                result    = {1'b0, a[15:1]};
                carry_out = a[0];
            end

            `ALU_ROL: begin
                {carry_out, result} = {a, carry_in};
            end

            `ALU_ROR: begin
                result    = {carry_in, a[15:1]};
                carry_out = a[0];
            end

            `ALU_INC: begin
                result = a + 16'd1;
            end

            `ALU_DEC: begin
                result = a - 16'd1;
            end

            `ALU_CMP: begin
                result    = a - b;
                carry_out = (a >= b);
            end

            `ALU_BIT: begin
                result       = a & b;
                negative     = b[15];
                overflow_out = b[14];
                zero         = (a & b) == 16'h0000;
                // Early return — skip default flag calculation
            end

            `ALU_TSB: begin
                result = a | b;
                zero   = (a & b) == 16'h0000;
            end

            `ALU_TRB: begin
                result = ~a & b;
                zero   = (a & b) == 16'h0000;
            end

            `ALU_PASS: begin
                result = b;
            end
        endcase

        // Default flag calculation (BIT/TSB/TRB handle their own)
        if (op != `ALU_BIT && op != `ALU_TSB && op != `ALU_TRB) begin
            zero     = (result == 16'h0000);
            negative = result[15];
        end
    end

endmodule
