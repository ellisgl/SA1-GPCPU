`include "cpu_defines.vh"

// Address computation for all 65C816 addressing modes
module address_gen (
    input  wire [4:0]  addr_mode,
    input  wire [7:0]  operand_lo,   // First operand byte
    input  wire [7:0]  operand_hi,   // Second operand byte
    input  wire [7:0]  operand_bk,   // Third operand byte (bank)
    input  wire [15:0] reg_x,
    input  wire [15:0] reg_y,
    input  wire [15:0] reg_sp,
    input  wire [15:0] reg_dp,
    input  wire [7:0]  reg_dbr,
    input  wire [7:0]  reg_pbr,
    input  wire [15:0] reg_pc,

    // Indirect pointer (fetched by CPU core during indirect addressing)
    input  wire [7:0]  indirect_lo,
    input  wire [7:0]  indirect_hi,
    input  wire [7:0]  indirect_bk,

    // Effective address output
    output reg  [23:0] eff_addr,

    // Address for fetching indirect pointer
    output reg  [23:0] ptr_addr,

    // Number of operand bytes to fetch
    output reg  [1:0]  operand_bytes,
    // Whether indirect pointer fetch is needed
    output reg         needs_indirect,
    // Number of indirect bytes to fetch (2 or 3 for long)
    output reg  [1:0]  indirect_bytes
);

    wire [15:0] operand_16 = {operand_hi, operand_lo};
    wire [15:0] dp_offset  = reg_dp + {8'h00, operand_lo};

    always @(*) begin
        eff_addr       = 24'h000000;
        ptr_addr       = 24'h000000;
        operand_bytes  = 2'd0;
        needs_indirect = 1'b0;
        indirect_bytes = 2'd2;

        case (addr_mode)
            `AM_IMP, `AM_ACC: begin
                operand_bytes = 2'd0;
            end

            `AM_IMM: begin
                operand_bytes = 2'd2;
                eff_addr = {reg_pbr, reg_pc + 16'd1};
            end

            `AM_IMM8: begin
                operand_bytes = 2'd1;
                eff_addr = {reg_pbr, reg_pc + 16'd1};
            end

            `AM_DP: begin
                operand_bytes = 2'd1;
                eff_addr = {8'h00, dp_offset};
            end

            `AM_DPX: begin
                operand_bytes = 2'd1;
                eff_addr = {8'h00, dp_offset + reg_x};
            end

            `AM_DPY: begin
                operand_bytes = 2'd1;
                eff_addr = {8'h00, dp_offset + reg_y};
            end

            `AM_IDP: begin
                operand_bytes  = 2'd1;
                needs_indirect = 1'b1;
                indirect_bytes = 2'd2;
                ptr_addr = {8'h00, dp_offset};
                eff_addr = {reg_dbr, indirect_hi, indirect_lo};
            end

            `AM_IDPX: begin
                operand_bytes  = 2'd1;
                needs_indirect = 1'b1;
                indirect_bytes = 2'd2;
                ptr_addr = {8'h00, dp_offset + reg_x};
                eff_addr = {reg_dbr, indirect_hi, indirect_lo};
            end

            `AM_IDPY: begin
                operand_bytes  = 2'd1;
                needs_indirect = 1'b1;
                indirect_bytes = 2'd2;
                ptr_addr = {8'h00, dp_offset};
                eff_addr = {reg_dbr, {indirect_hi, indirect_lo} + reg_y};
            end

            `AM_IDPL: begin
                operand_bytes  = 2'd1;
                needs_indirect = 1'b1;
                indirect_bytes = 2'd3;
                ptr_addr = {8'h00, dp_offset};
                eff_addr = {indirect_bk, indirect_hi, indirect_lo};
            end

            `AM_IDPLY: begin
                operand_bytes  = 2'd1;
                needs_indirect = 1'b1;
                indirect_bytes = 2'd3;
                ptr_addr = {8'h00, dp_offset};
                eff_addr = {indirect_bk, {indirect_hi, indirect_lo} + reg_y};
            end

            `AM_ABS: begin
                operand_bytes = 2'd2;
                eff_addr = {reg_dbr, operand_16};
            end

            `AM_ABX: begin
                operand_bytes = 2'd2;
                eff_addr = {reg_dbr, operand_16 + reg_x};
            end

            `AM_ABY: begin
                operand_bytes = 2'd2;
                eff_addr = {reg_dbr, operand_16 + reg_y};
            end

            `AM_LONG: begin
                operand_bytes = 2'd3;
                eff_addr = {operand_bk, operand_16};
            end

            `AM_LONGX: begin
                operand_bytes = 2'd3;
                eff_addr = {operand_bk, operand_16} + {8'h00, reg_x};
            end

            `AM_IND: begin
                operand_bytes  = 2'd2;
                needs_indirect = 1'b1;
                indirect_bytes = 2'd2;
                ptr_addr = {8'h00, operand_16};
                eff_addr = {reg_pbr, indirect_hi, indirect_lo};
            end

            `AM_INDX: begin
                operand_bytes  = 2'd2;
                needs_indirect = 1'b1;
                indirect_bytes = 2'd2;
                ptr_addr = {reg_pbr, operand_16 + reg_x};
                eff_addr = {reg_pbr, indirect_hi, indirect_lo};
            end

            `AM_INDL: begin
                operand_bytes  = 2'd2;
                needs_indirect = 1'b1;
                indirect_bytes = 2'd3;
                ptr_addr = {8'h00, operand_16};
                eff_addr = {indirect_bk, indirect_hi, indirect_lo};
            end

            `AM_REL: begin
                operand_bytes = 2'd1;
            end

            `AM_RELL: begin
                operand_bytes = 2'd2;
            end

            `AM_SR: begin
                operand_bytes = 2'd1;
                eff_addr = {8'h00, reg_sp + {8'h00, operand_lo}};
            end

            `AM_SRY: begin
                operand_bytes  = 2'd1;
                needs_indirect = 1'b1;
                indirect_bytes = 2'd2;
                ptr_addr = {8'h00, reg_sp + {8'h00, operand_lo}};
                eff_addr = {reg_dbr, {indirect_hi, indirect_lo} + reg_y};
            end

            `AM_BM: begin
                operand_bytes = 2'd2;
            end

            `AM_PEA: begin
                operand_bytes = 2'd2;
            end

            `AM_PEI: begin
                operand_bytes  = 2'd1;
                needs_indirect = 1'b1;
                indirect_bytes = 2'd2;
                ptr_addr = {8'h00, dp_offset};
            end

            `AM_PER: begin
                operand_bytes = 2'd2;
            end

            default: begin
                operand_bytes = 2'd0;
            end
        endcase
    end

endmodule
