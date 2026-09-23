`include "cpu_defines.vh"

module register_file (
    input  wire        clk,
    input  wire        rst_n,

    // Read ports
    input  wire [2:0]  rd_sel_a,
    input  wire [2:0]  rd_sel_b,
    output reg  [15:0] rd_data_a,
    output reg  [15:0] rd_data_b,

    // Write port
    input  wire        wr_en,
    input  wire [2:0]  wr_sel,
    input  wire [15:0] wr_data,
    input  wire        wr_byte_lo,  // Write only low byte

    // Program counter
    input  wire        pc_wr_en,
    input  wire [15:0] pc_wr_data,
    input  wire        pc_inc,
    output wire [15:0] pc_out,

    // Bank registers
    input  wire        pbr_wr_en,
    input  wire [7:0]  pbr_wr_data,
    output wire [7:0]  pbr_out,
    input  wire        dbr_wr_en,
    input  wire [7:0]  dbr_wr_data,
    output wire [7:0]  dbr_out,

    // Status register
    input  wire        p_wr_en,
    input  wire [7:0]  p_wr_data,
    input  wire [7:0]  p_wr_mask,   // Which bits to update
    output wire [7:0]  p_out,

    // Stack pointer direct access
    input  wire        sp_dec,
    input  wire        sp_inc,
    input  wire        sp_dec2,
    input  wire        sp_inc2,
    output wire [15:0] sp_out,

    // Direct register outputs for address generation
    output wire [15:0] a_out,
    output wire [15:0] x_out,
    output wire [15:0] y_out,
    output wire [15:0] dp_out
);

    reg [15:0] reg_a;   // Accumulator
    reg [15:0] reg_x;   // Index X
    reg [15:0] reg_y;   // Index Y
    reg [15:0] reg_sp;  // Stack Pointer
    reg [15:0] reg_dp;  // Direct Page
    reg [15:0] reg_pc;  // Program Counter
    reg [7:0]  reg_dbr; // Data Bank Register
    reg [7:0]  reg_pbr; // Program Bank Register
    reg [7:0]  reg_p;   // Processor Status

    assign pc_out  = reg_pc;
    assign pbr_out = reg_pbr;
    assign dbr_out = reg_dbr;
    assign p_out   = reg_p;
    assign sp_out  = reg_sp;
    assign a_out   = reg_a;
    assign x_out   = reg_x;
    assign y_out   = reg_y;
    assign dp_out  = reg_dp;

    // Read port A
    always @(*) begin
        case (rd_sel_a)
            `REG_A:   rd_data_a = reg_a;
            `REG_X:   rd_data_a = reg_x;
            `REG_Y:   rd_data_a = reg_y;
            `REG_SP:  rd_data_a = reg_sp;
            `REG_DP:  rd_data_a = reg_dp;
            `REG_DBR: rd_data_a = {8'h00, reg_dbr};
            `REG_PBR: rd_data_a = {8'h00, reg_pbr};
            `REG_P:   rd_data_a = {8'h00, reg_p};
        endcase
    end

    // Read port B
    always @(*) begin
        case (rd_sel_b)
            `REG_A:   rd_data_b = reg_a;
            `REG_X:   rd_data_b = reg_x;
            `REG_Y:   rd_data_b = reg_y;
            `REG_SP:  rd_data_b = reg_sp;
            `REG_DP:  rd_data_b = reg_dp;
            `REG_DBR: rd_data_b = {8'h00, reg_dbr};
            `REG_PBR: rd_data_b = {8'h00, reg_pbr};
            `REG_P:   rd_data_b = {8'h00, reg_p};
        endcase
    end

    // Register writes
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_a   <= 16'h0000;
            reg_x   <= 16'h0000;
            reg_y   <= 16'h0000;
            reg_sp  <= 16'h01FF;
            reg_dp  <= 16'h0000;
            reg_pc  <= 16'h0000;
            reg_dbr <= 8'h00;
            reg_pbr <= 8'h00;
            reg_p   <= 8'b00000100; // I=1 on reset, M=0, X=0
        end else begin
            // General register write
            if (wr_en) begin
                case (wr_sel)
                    `REG_A: begin
                        if (wr_byte_lo)
                            reg_a[7:0] <= wr_data[7:0];
                        else
                            reg_a <= wr_data;
                    end
                    `REG_X:   reg_x  <= wr_data;
                    `REG_Y:   reg_y  <= wr_data;
                    `REG_SP:  reg_sp <= wr_data;
                    `REG_DP:  reg_dp <= wr_data;
                    `REG_DBR: reg_dbr <= wr_data[7:0];
                    `REG_PBR: reg_pbr <= wr_data[7:0];
                    `REG_P:   reg_p <= (wr_data[7:0] & 8'hCF) | 8'h00;
                    // M and X bits forced to 0
                endcase
            end

            // Program counter
            if (pc_wr_en)
                reg_pc <= pc_wr_data;
            else if (pc_inc)
                reg_pc <= reg_pc + 16'd1;

            // Bank registers
            if (pbr_wr_en) reg_pbr <= pbr_wr_data;
            if (dbr_wr_en) reg_dbr <= dbr_wr_data;

            // Status register (masked write)
            if (p_wr_en)
                reg_p <= ((p_wr_data & p_wr_mask) | (reg_p & ~p_wr_mask)) & 8'hCF;
                // M and X always forced to 0

            // Stack pointer adjust
            if (sp_dec)       reg_sp <= reg_sp - 16'd1;
            else if (sp_dec2) reg_sp <= reg_sp - 16'd2;
            else if (sp_inc)  reg_sp <= reg_sp + 16'd1;
            else if (sp_inc2) reg_sp <= reg_sp + 16'd2;
        end
    end

endmodule
