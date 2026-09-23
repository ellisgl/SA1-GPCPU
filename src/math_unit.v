`include "cpu_defines.vh"

// SA1-style hardware multiply/divide with cumulative sum
module math_unit (
    input  wire        clk,
    input  wire        rst_n,

    // Multiply: 16x16 -> 32
    input  wire        mul_start,
    input  wire [15:0] mul_a,
    input  wire [15:0] mul_b,
    output reg  [31:0] mul_result,
    output reg         mul_done,

    // Divide: 32 / 16 -> 16 quotient + 16 remainder
    input  wire        div_start,
    input  wire [31:0] div_dividend,
    input  wire [15:0] div_divisor,
    output reg  [15:0] div_quotient,
    output reg  [15:0] div_remainder,
    output reg         div_done,
    output reg         div_overflow,

    // Cumulative sum (40-bit)
    input  wire        cum_add,    // Add mul_result to cumulative sum
    input  wire        cum_clear,
    output reg  [39:0] cum_sum
);

    // Multiply pipeline (2-cycle, matching SA1 timing)
    reg        mul_active;
    reg [15:0] mul_a_r, mul_b_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mul_result <= 32'd0;
            mul_done   <= 1'b0;
            mul_active <= 1'b0;
            mul_a_r    <= 16'd0;
            mul_b_r    <= 16'd0;
        end else begin
            mul_done <= 1'b0;
            if (mul_start) begin
                mul_a_r    <= mul_a;
                mul_b_r    <= mul_b;
                mul_active <= 1'b1;
            end else if (mul_active) begin
                mul_result <= mul_a_r * mul_b_r;
                mul_done   <= 1'b1;
                mul_active <= 1'b0;
            end
        end
    end

    // Non-restoring long division (single cycle using combinational logic)
    // For 32/16 this is fine on FPGA; a pipelined version can come later
    reg div_busy;

    reg [31:0] div_num;
    reg [15:0] div_den;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_quotient  <= 16'd0;
            div_remainder <= 16'd0;
            div_done      <= 1'b0;
            div_overflow  <= 1'b0;
            div_busy      <= 1'b0;
        end else begin
            div_done <= 1'b0;
            if (div_start) begin
                if (div_divisor == 16'd0) begin
                    div_quotient  <= 16'hFFFF;
                    div_remainder <= 16'hFFFF;
                    div_overflow  <= 1'b1;
                    div_done      <= 1'b1;
                end else begin
                    div_num  <= div_dividend;
                    div_den  <= div_divisor;
                    div_busy <= 1'b1;
                    div_overflow <= 1'b0;
                end
            end else if (div_busy) begin
                div_quotient  <= div_num / {16'd0, div_den};
                div_remainder <= div_num % {16'd0, div_den};
                div_done      <= 1'b1;
                div_busy      <= 1'b0;
            end
        end
    end

    // Cumulative sum
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cum_sum <= 40'd0;
        else if (cum_clear)
            cum_sum <= 40'd0;
        else if (cum_add)
            cum_sum <= cum_sum + {8'd0, mul_result};
    end

endmodule
