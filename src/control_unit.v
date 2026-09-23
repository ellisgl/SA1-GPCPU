`include "cpu_defines.vh"

// Combinational instruction decoder
// Maps opcode -> control signals
module control_unit (
    input  wire [7:0]  opcode,

    output reg  [3:0]  alu_op,
    output reg  [4:0]  addr_mode,
    output reg  [2:0]  src_reg,
    output reg  [2:0]  dst_reg,
    output reg  [2:0]  category,
    output reg  [2:0]  branch_cond,
    output reg         mem_read,
    output reg         mem_write,
    output reg         reg_write,
    output reg         flag_update,
    output reg         is_store,     // STA/STX/STY/STZ
    output reg         is_long_addr, // 24-bit address
    output reg         valid
);

    always @(*) begin
        // Defaults
        alu_op      = `ALU_PASS;
        addr_mode   = `AM_IMP;
        src_reg     = `REG_A;
        dst_reg     = `REG_A;
        category    = `CAT_ALU;
        branch_cond = 3'd0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        reg_write   = 1'b0;
        flag_update = 1'b0;
        is_store    = 1'b0;
        is_long_addr = 1'b0;
        valid       = 1'b1;

        case (opcode)
            // ========== 0x ==========
            8'h00: begin // BRK
                category = `CAT_SPECIAL;
            end
            8'h01: begin // ORA (dp,X)
                alu_op = `ALU_ORA; addr_mode = `AM_IDPX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h02: begin // COP
                category = `CAT_SPECIAL;
            end
            8'h03: begin // ORA sr,S
                alu_op = `ALU_ORA; addr_mode = `AM_SR;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h04: begin // TSB dp
                alu_op = `ALU_TSB; addr_mode = `AM_DP; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h05: begin // ORA dp
                alu_op = `ALU_ORA; addr_mode = `AM_DP;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h06: begin // ASL dp
                alu_op = `ALU_ASL; addr_mode = `AM_DP; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h07: begin // ORA [dp]
                alu_op = `ALU_ORA; addr_mode = `AM_IDPL;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end
            8'h08: begin // PHP
                category = `CAT_STACK; src_reg = `REG_P;
            end
            8'h09: begin // ORA #imm
                alu_op = `ALU_ORA; addr_mode = `AM_IMM;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h0A: begin // ASL A
                alu_op = `ALU_ASL; addr_mode = `AM_ACC;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h0B: begin // PHD
                category = `CAT_STACK; src_reg = `REG_DP;
            end
            8'h0C: begin // TSB abs
                alu_op = `ALU_TSB; addr_mode = `AM_ABS; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h0D: begin // ORA abs
                alu_op = `ALU_ORA; addr_mode = `AM_ABS;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h0E: begin // ASL abs
                alu_op = `ALU_ASL; addr_mode = `AM_ABS; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h0F: begin // ORA long
                alu_op = `ALU_ORA; addr_mode = `AM_LONG;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end

            // ========== 1x ==========
            8'h10: begin // BPL
                category = `CAT_BRANCH; addr_mode = `AM_REL; branch_cond = `BR_PL;
            end
            8'h11: begin // ORA (dp),Y
                alu_op = `ALU_ORA; addr_mode = `AM_IDPY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h12: begin // ORA (dp)
                alu_op = `ALU_ORA; addr_mode = `AM_IDP;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h13: begin // ORA (sr,S),Y
                alu_op = `ALU_ORA; addr_mode = `AM_SRY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h14: begin // TRB dp
                alu_op = `ALU_TRB; addr_mode = `AM_DP; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h15: begin // ORA dp,X
                alu_op = `ALU_ORA; addr_mode = `AM_DPX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h16: begin // ASL dp,X
                alu_op = `ALU_ASL; addr_mode = `AM_DPX; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h17: begin // ORA [dp],Y
                alu_op = `ALU_ORA; addr_mode = `AM_IDPLY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end
            8'h18: begin // CLC
                category = `CAT_FLAG;
            end
            8'h19: begin // ORA abs,Y
                alu_op = `ALU_ORA; addr_mode = `AM_ABY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h1A: begin // INC A
                alu_op = `ALU_INC; addr_mode = `AM_ACC;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h1B: begin // TCS
                category = `CAT_XFER; src_reg = `REG_A; dst_reg = `REG_SP;
                reg_write = 1'b1;
            end
            8'h1C: begin // TRB abs
                alu_op = `ALU_TRB; addr_mode = `AM_ABS; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h1D: begin // ORA abs,X
                alu_op = `ALU_ORA; addr_mode = `AM_ABX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h1E: begin // ASL abs,X
                alu_op = `ALU_ASL; addr_mode = `AM_ABX; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h1F: begin // ORA long,X
                alu_op = `ALU_ORA; addr_mode = `AM_LONGX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end

            // ========== 2x ==========
            8'h20: begin // JSR abs
                category = `CAT_JUMP; addr_mode = `AM_ABS;
            end
            8'h21: begin // AND (dp,X)
                alu_op = `ALU_AND; addr_mode = `AM_IDPX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h22: begin // JSL long
                category = `CAT_JUMP; addr_mode = `AM_LONG;
                is_long_addr = 1'b1;
            end
            8'h23: begin // AND sr,S
                alu_op = `ALU_AND; addr_mode = `AM_SR;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h24: begin // BIT dp
                alu_op = `ALU_BIT; addr_mode = `AM_DP;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'h25: begin // AND dp
                alu_op = `ALU_AND; addr_mode = `AM_DP;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h26: begin // ROL dp
                alu_op = `ALU_ROL; addr_mode = `AM_DP; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h27: begin // AND [dp]
                alu_op = `ALU_AND; addr_mode = `AM_IDPL;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end
            8'h28: begin // PLP
                category = `CAT_STACK; dst_reg = `REG_P;
                reg_write = 1'b1;
            end
            8'h29: begin // AND #imm
                alu_op = `ALU_AND; addr_mode = `AM_IMM;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h2A: begin // ROL A
                alu_op = `ALU_ROL; addr_mode = `AM_ACC;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h2B: begin // PLD
                category = `CAT_STACK; dst_reg = `REG_DP;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h2C: begin // BIT abs
                alu_op = `ALU_BIT; addr_mode = `AM_ABS;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'h2D: begin // AND abs
                alu_op = `ALU_AND; addr_mode = `AM_ABS;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h2E: begin // ROL abs
                alu_op = `ALU_ROL; addr_mode = `AM_ABS; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h2F: begin // AND long
                alu_op = `ALU_AND; addr_mode = `AM_LONG;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end

            // ========== 3x ==========
            8'h30: begin // BMI
                category = `CAT_BRANCH; addr_mode = `AM_REL; branch_cond = `BR_MI;
            end
            8'h31: begin // AND (dp),Y
                alu_op = `ALU_AND; addr_mode = `AM_IDPY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h32: begin // AND (dp)
                alu_op = `ALU_AND; addr_mode = `AM_IDP;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h33: begin // AND (sr,S),Y
                alu_op = `ALU_AND; addr_mode = `AM_SRY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h34: begin // BIT dp,X
                alu_op = `ALU_BIT; addr_mode = `AM_DPX;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'h35: begin // AND dp,X
                alu_op = `ALU_AND; addr_mode = `AM_DPX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h36: begin // ROL dp,X
                alu_op = `ALU_ROL; addr_mode = `AM_DPX; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h37: begin // AND [dp],Y
                alu_op = `ALU_AND; addr_mode = `AM_IDPLY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end
            8'h38: begin // SEC
                category = `CAT_FLAG;
            end
            8'h39: begin // AND abs,Y
                alu_op = `ALU_AND; addr_mode = `AM_ABY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h3A: begin // DEC A
                alu_op = `ALU_DEC; addr_mode = `AM_ACC;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h3B: begin // TSC
                category = `CAT_XFER; src_reg = `REG_SP; dst_reg = `REG_A;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h3C: begin // BIT abs,X
                alu_op = `ALU_BIT; addr_mode = `AM_ABX;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'h3D: begin // AND abs,X
                alu_op = `ALU_AND; addr_mode = `AM_ABX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h3E: begin // ROL abs,X
                alu_op = `ALU_ROL; addr_mode = `AM_ABX; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h3F: begin // AND long,X
                alu_op = `ALU_AND; addr_mode = `AM_LONGX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end

            // ========== 4x ==========
            8'h40: begin // RTI
                category = `CAT_JUMP;
            end
            8'h41: begin // EOR (dp,X)
                alu_op = `ALU_EOR; addr_mode = `AM_IDPX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h42: begin // WDM (reserved, treated as 2-byte NOP)
                category = `CAT_SPECIAL; addr_mode = `AM_IMM8;
            end
            8'h43: begin // EOR sr,S
                alu_op = `ALU_EOR; addr_mode = `AM_SR;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h44: begin // MVP
                category = `CAT_SPECIAL; addr_mode = `AM_BM;
            end
            8'h45: begin // EOR dp
                alu_op = `ALU_EOR; addr_mode = `AM_DP;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h46: begin // LSR dp
                alu_op = `ALU_LSR; addr_mode = `AM_DP; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h47: begin // EOR [dp]
                alu_op = `ALU_EOR; addr_mode = `AM_IDPL;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end
            8'h48: begin // PHA
                category = `CAT_STACK; src_reg = `REG_A;
            end
            8'h49: begin // EOR #imm
                alu_op = `ALU_EOR; addr_mode = `AM_IMM;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h4A: begin // LSR A
                alu_op = `ALU_LSR; addr_mode = `AM_ACC;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h4B: begin // PHK
                category = `CAT_STACK; src_reg = `REG_PBR;
            end
            8'h4C: begin // JMP abs
                category = `CAT_JUMP; addr_mode = `AM_ABS;
            end
            8'h4D: begin // EOR abs
                alu_op = `ALU_EOR; addr_mode = `AM_ABS;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h4E: begin // LSR abs
                alu_op = `ALU_LSR; addr_mode = `AM_ABS; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h4F: begin // EOR long
                alu_op = `ALU_EOR; addr_mode = `AM_LONG;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end

            // ========== 5x ==========
            8'h50: begin // BVC
                category = `CAT_BRANCH; addr_mode = `AM_REL; branch_cond = `BR_VC;
            end
            8'h51: begin // EOR (dp),Y
                alu_op = `ALU_EOR; addr_mode = `AM_IDPY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h52: begin // EOR (dp)
                alu_op = `ALU_EOR; addr_mode = `AM_IDP;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h53: begin // EOR (sr,S),Y
                alu_op = `ALU_EOR; addr_mode = `AM_SRY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h54: begin // MVN
                category = `CAT_SPECIAL; addr_mode = `AM_BM;
            end
            8'h55: begin // EOR dp,X
                alu_op = `ALU_EOR; addr_mode = `AM_DPX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h56: begin // LSR dp,X
                alu_op = `ALU_LSR; addr_mode = `AM_DPX; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h57: begin // EOR [dp],Y
                alu_op = `ALU_EOR; addr_mode = `AM_IDPLY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end
            8'h58: begin // CLI
                category = `CAT_FLAG;
            end
            8'h59: begin // EOR abs,Y
                alu_op = `ALU_EOR; addr_mode = `AM_ABY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h5A: begin // PHY
                category = `CAT_STACK; src_reg = `REG_Y;
            end
            8'h5B: begin // TCD
                category = `CAT_XFER; src_reg = `REG_A; dst_reg = `REG_DP;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h5C: begin // JML long
                category = `CAT_JUMP; addr_mode = `AM_LONG;
                is_long_addr = 1'b1;
            end
            8'h5D: begin // EOR abs,X
                alu_op = `ALU_EOR; addr_mode = `AM_ABX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h5E: begin // LSR abs,X
                alu_op = `ALU_LSR; addr_mode = `AM_ABX; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h5F: begin // EOR long,X
                alu_op = `ALU_EOR; addr_mode = `AM_LONGX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end

            // ========== 6x ==========
            8'h60: begin // RTS
                category = `CAT_JUMP;
            end
            8'h61: begin // ADC (dp,X)
                alu_op = `ALU_ADC; addr_mode = `AM_IDPX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h62: begin // PER rel16
                category = `CAT_STACK; addr_mode = `AM_PER;
            end
            8'h63: begin // ADC sr,S
                alu_op = `ALU_ADC; addr_mode = `AM_SR;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h64: begin // STZ dp
                addr_mode = `AM_DP; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h65: begin // ADC dp
                alu_op = `ALU_ADC; addr_mode = `AM_DP;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h66: begin // ROR dp
                alu_op = `ALU_ROR; addr_mode = `AM_DP; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h67: begin // ADC [dp]
                alu_op = `ALU_ADC; addr_mode = `AM_IDPL;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end
            8'h68: begin // PLA
                category = `CAT_STACK; dst_reg = `REG_A;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h69: begin // ADC #imm
                alu_op = `ALU_ADC; addr_mode = `AM_IMM;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h6A: begin // ROR A
                alu_op = `ALU_ROR; addr_mode = `AM_ACC;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h6B: begin // RTL
                category = `CAT_JUMP;
            end
            8'h6C: begin // JMP (abs)
                category = `CAT_JUMP; addr_mode = `AM_IND;
            end
            8'h6D: begin // ADC abs
                alu_op = `ALU_ADC; addr_mode = `AM_ABS;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h6E: begin // ROR abs
                alu_op = `ALU_ROR; addr_mode = `AM_ABS; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h6F: begin // ADC long
                alu_op = `ALU_ADC; addr_mode = `AM_LONG;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end

            // ========== 7x ==========
            8'h70: begin // BVS
                category = `CAT_BRANCH; addr_mode = `AM_REL; branch_cond = `BR_VS;
            end
            8'h71: begin // ADC (dp),Y
                alu_op = `ALU_ADC; addr_mode = `AM_IDPY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h72: begin // ADC (dp)
                alu_op = `ALU_ADC; addr_mode = `AM_IDP;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h73: begin // ADC (sr,S),Y
                alu_op = `ALU_ADC; addr_mode = `AM_SRY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h74: begin // STZ dp,X
                addr_mode = `AM_DPX; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h75: begin // ADC dp,X
                alu_op = `ALU_ADC; addr_mode = `AM_DPX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h76: begin // ROR dp,X
                alu_op = `ALU_ROR; addr_mode = `AM_DPX; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h77: begin // ADC [dp],Y
                alu_op = `ALU_ADC; addr_mode = `AM_IDPLY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end
            8'h78: begin // SEI
                category = `CAT_FLAG;
            end
            8'h79: begin // ADC abs,Y
                alu_op = `ALU_ADC; addr_mode = `AM_ABY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h7A: begin // PLY
                category = `CAT_STACK; dst_reg = `REG_Y;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h7B: begin // TDC
                category = `CAT_XFER; src_reg = `REG_DP; dst_reg = `REG_A;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h7C: begin // JMP (abs,X)
                category = `CAT_JUMP; addr_mode = `AM_INDX;
            end
            8'h7D: begin // ADC abs,X
                alu_op = `ALU_ADC; addr_mode = `AM_ABX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h7E: begin // ROR abs,X
                alu_op = `ALU_ROR; addr_mode = `AM_ABX; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'h7F: begin // ADC long,X
                alu_op = `ALU_ADC; addr_mode = `AM_LONGX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end

            // ========== 8x ==========
            8'h80: begin // BRA
                category = `CAT_BRANCH; addr_mode = `AM_REL;
            end
            8'h81: begin // STA (dp,X)
                addr_mode = `AM_IDPX; src_reg = `REG_A; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h82: begin // BRL rel16
                category = `CAT_BRANCH; addr_mode = `AM_RELL;
            end
            8'h83: begin // STA sr,S
                addr_mode = `AM_SR; src_reg = `REG_A; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h84: begin // STY dp
                addr_mode = `AM_DP; src_reg = `REG_Y; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h85: begin // STA dp
                addr_mode = `AM_DP; src_reg = `REG_A; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h86: begin // STX dp
                addr_mode = `AM_DP; src_reg = `REG_X; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h87: begin // STA [dp]
                addr_mode = `AM_IDPL; src_reg = `REG_A; is_store = 1'b1;
                mem_write = 1'b1; is_long_addr = 1'b1;
            end
            8'h88: begin // DEY
                alu_op = `ALU_DEC; addr_mode = `AM_IMP;
                src_reg = `REG_Y; dst_reg = `REG_Y;
                reg_write = 1'b1; flag_update = 1'b1;
                category = `CAT_XFER;
            end
            8'h89: begin // BIT #imm
                alu_op = `ALU_BIT; addr_mode = `AM_IMM;
                flag_update = 1'b1;
            end
            8'h8A: begin // TXA
                category = `CAT_XFER; src_reg = `REG_X; dst_reg = `REG_A;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h8B: begin // PHB
                category = `CAT_STACK; src_reg = `REG_DBR;
            end
            8'h8C: begin // STY abs
                addr_mode = `AM_ABS; src_reg = `REG_Y; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h8D: begin // STA abs
                addr_mode = `AM_ABS; src_reg = `REG_A; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h8E: begin // STX abs
                addr_mode = `AM_ABS; src_reg = `REG_X; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h8F: begin // STA long
                addr_mode = `AM_LONG; src_reg = `REG_A; is_store = 1'b1;
                mem_write = 1'b1; is_long_addr = 1'b1;
            end

            // ========== 9x ==========
            8'h90: begin // BCC
                category = `CAT_BRANCH; addr_mode = `AM_REL; branch_cond = `BR_CC;
            end
            8'h91: begin // STA (dp),Y
                addr_mode = `AM_IDPY; src_reg = `REG_A; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h92: begin // STA (dp)
                addr_mode = `AM_IDP; src_reg = `REG_A; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h93: begin // STA (sr,S),Y
                addr_mode = `AM_SRY; src_reg = `REG_A; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h94: begin // STY dp,X
                addr_mode = `AM_DPX; src_reg = `REG_Y; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h95: begin // STA dp,X
                addr_mode = `AM_DPX; src_reg = `REG_A; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h96: begin // STX dp,Y
                addr_mode = `AM_DPY; src_reg = `REG_X; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h97: begin // STA [dp],Y
                addr_mode = `AM_IDPLY; src_reg = `REG_A; is_store = 1'b1;
                mem_write = 1'b1; is_long_addr = 1'b1;
            end
            8'h98: begin // TYA
                category = `CAT_XFER; src_reg = `REG_Y; dst_reg = `REG_A;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h99: begin // STA abs,Y
                addr_mode = `AM_ABY; src_reg = `REG_A; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h9A: begin // TXS
                category = `CAT_XFER; src_reg = `REG_X; dst_reg = `REG_SP;
                reg_write = 1'b1;
            end
            8'h9B: begin // TXY
                category = `CAT_XFER; src_reg = `REG_X; dst_reg = `REG_Y;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'h9C: begin // STZ abs
                addr_mode = `AM_ABS; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h9D: begin // STA abs,X
                addr_mode = `AM_ABX; src_reg = `REG_A; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h9E: begin // STZ abs,X
                addr_mode = `AM_ABX; is_store = 1'b1;
                mem_write = 1'b1;
            end
            8'h9F: begin // STA long,X
                addr_mode = `AM_LONGX; src_reg = `REG_A; is_store = 1'b1;
                mem_write = 1'b1; is_long_addr = 1'b1;
            end

            // ========== Ax ==========
            8'hA0: begin // LDY #imm
                alu_op = `ALU_PASS; addr_mode = `AM_IMM; dst_reg = `REG_Y;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hA1: begin // LDA (dp,X)
                alu_op = `ALU_PASS; addr_mode = `AM_IDPX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hA2: begin // LDX #imm
                alu_op = `ALU_PASS; addr_mode = `AM_IMM; dst_reg = `REG_X;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hA3: begin // LDA sr,S
                alu_op = `ALU_PASS; addr_mode = `AM_SR;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hA4: begin // LDY dp
                alu_op = `ALU_PASS; addr_mode = `AM_DP; dst_reg = `REG_Y;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hA5: begin // LDA dp
                alu_op = `ALU_PASS; addr_mode = `AM_DP;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hA6: begin // LDX dp
                alu_op = `ALU_PASS; addr_mode = `AM_DP; dst_reg = `REG_X;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hA7: begin // LDA [dp]
                alu_op = `ALU_PASS; addr_mode = `AM_IDPL;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end
            8'hA8: begin // TAY
                category = `CAT_XFER; src_reg = `REG_A; dst_reg = `REG_Y;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hA9: begin // LDA #imm
                alu_op = `ALU_PASS; addr_mode = `AM_IMM;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hAA: begin // TAX
                category = `CAT_XFER; src_reg = `REG_A; dst_reg = `REG_X;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hAB: begin // PLB
                category = `CAT_STACK; dst_reg = `REG_DBR;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hAC: begin // LDY abs
                alu_op = `ALU_PASS; addr_mode = `AM_ABS; dst_reg = `REG_Y;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hAD: begin // LDA abs
                alu_op = `ALU_PASS; addr_mode = `AM_ABS;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hAE: begin // LDX abs
                alu_op = `ALU_PASS; addr_mode = `AM_ABS; dst_reg = `REG_X;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hAF: begin // LDA long
                alu_op = `ALU_PASS; addr_mode = `AM_LONG;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end

            // ========== Bx ==========
            8'hB0: begin // BCS
                category = `CAT_BRANCH; addr_mode = `AM_REL; branch_cond = `BR_CS;
            end
            8'hB1: begin // LDA (dp),Y
                alu_op = `ALU_PASS; addr_mode = `AM_IDPY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hB2: begin // LDA (dp)
                alu_op = `ALU_PASS; addr_mode = `AM_IDP;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hB3: begin // LDA (sr,S),Y
                alu_op = `ALU_PASS; addr_mode = `AM_SRY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hB4: begin // LDY dp,X
                alu_op = `ALU_PASS; addr_mode = `AM_DPX; dst_reg = `REG_Y;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hB5: begin // LDA dp,X
                alu_op = `ALU_PASS; addr_mode = `AM_DPX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hB6: begin // LDX dp,Y
                alu_op = `ALU_PASS; addr_mode = `AM_DPY; dst_reg = `REG_X;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hB7: begin // LDA [dp],Y
                alu_op = `ALU_PASS; addr_mode = `AM_IDPLY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end
            8'hB8: begin // CLV
                category = `CAT_FLAG;
            end
            8'hB9: begin // LDA abs,Y
                alu_op = `ALU_PASS; addr_mode = `AM_ABY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hBA: begin // TSX
                category = `CAT_XFER; src_reg = `REG_SP; dst_reg = `REG_X;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hBB: begin // TYX
                category = `CAT_XFER; src_reg = `REG_Y; dst_reg = `REG_X;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hBC: begin // LDY abs,X
                alu_op = `ALU_PASS; addr_mode = `AM_ABX; dst_reg = `REG_Y;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hBD: begin // LDA abs,X
                alu_op = `ALU_PASS; addr_mode = `AM_ABX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hBE: begin // LDX abs,Y
                alu_op = `ALU_PASS; addr_mode = `AM_ABY; dst_reg = `REG_X;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hBF: begin // LDA long,X
                alu_op = `ALU_PASS; addr_mode = `AM_LONGX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end

            // ========== Cx ==========
            8'hC0: begin // CPY #imm
                alu_op = `ALU_CMP; addr_mode = `AM_IMM; src_reg = `REG_Y;
                flag_update = 1'b1;
            end
            8'hC1: begin // CMP (dp,X)
                alu_op = `ALU_CMP; addr_mode = `AM_IDPX;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'hC2: begin // REP #imm8 (only clears non-M/X flags)
                category = `CAT_FLAG; addr_mode = `AM_IMM8;
            end
            8'hC3: begin // CMP sr,S
                alu_op = `ALU_CMP; addr_mode = `AM_SR;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'hC4: begin // CPY dp
                alu_op = `ALU_CMP; addr_mode = `AM_DP; src_reg = `REG_Y;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'hC5: begin // CMP dp
                alu_op = `ALU_CMP; addr_mode = `AM_DP;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'hC6: begin // DEC dp
                alu_op = `ALU_DEC; addr_mode = `AM_DP; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'hC7: begin // CMP [dp]
                alu_op = `ALU_CMP; addr_mode = `AM_IDPL;
                mem_read = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end
            8'hC8: begin // INY
                alu_op = `ALU_INC; addr_mode = `AM_IMP;
                src_reg = `REG_Y; dst_reg = `REG_Y;
                reg_write = 1'b1; flag_update = 1'b1;
                category = `CAT_XFER;
            end
            8'hC9: begin // CMP #imm
                alu_op = `ALU_CMP; addr_mode = `AM_IMM;
                flag_update = 1'b1;
            end
            8'hCA: begin // DEX
                alu_op = `ALU_DEC; addr_mode = `AM_IMP;
                src_reg = `REG_X; dst_reg = `REG_X;
                reg_write = 1'b1; flag_update = 1'b1;
                category = `CAT_XFER;
            end
            8'hCB: begin // WAI
                category = `CAT_SPECIAL;
            end
            8'hCC: begin // CPY abs
                alu_op = `ALU_CMP; addr_mode = `AM_ABS; src_reg = `REG_Y;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'hCD: begin // CMP abs
                alu_op = `ALU_CMP; addr_mode = `AM_ABS;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'hCE: begin // DEC abs
                alu_op = `ALU_DEC; addr_mode = `AM_ABS; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'hCF: begin // CMP long
                alu_op = `ALU_CMP; addr_mode = `AM_LONG;
                mem_read = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end

            // ========== Dx ==========
            8'hD0: begin // BNE
                category = `CAT_BRANCH; addr_mode = `AM_REL; branch_cond = `BR_NE;
            end
            8'hD1: begin // CMP (dp),Y
                alu_op = `ALU_CMP; addr_mode = `AM_IDPY;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'hD2: begin // CMP (dp)
                alu_op = `ALU_CMP; addr_mode = `AM_IDP;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'hD3: begin // CMP (sr,S),Y
                alu_op = `ALU_CMP; addr_mode = `AM_SRY;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'hD4: begin // PEI (dp)
                category = `CAT_STACK; addr_mode = `AM_PEI;
            end
            8'hD5: begin // CMP dp,X
                alu_op = `ALU_CMP; addr_mode = `AM_DPX;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'hD6: begin // DEC dp,X
                alu_op = `ALU_DEC; addr_mode = `AM_DPX; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'hD7: begin // CMP [dp],Y
                alu_op = `ALU_CMP; addr_mode = `AM_IDPLY;
                mem_read = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end
            8'hD8: begin // CLD
                category = `CAT_FLAG;
            end
            8'hD9: begin // CMP abs,Y
                alu_op = `ALU_CMP; addr_mode = `AM_ABY;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'hDA: begin // PHX
                category = `CAT_STACK; src_reg = `REG_X;
            end
            8'hDB: begin // STP
                category = `CAT_SPECIAL;
            end
            8'hDC: begin // JML [abs]
                category = `CAT_JUMP; addr_mode = `AM_INDL;
                is_long_addr = 1'b1;
            end
            8'hDD: begin // CMP abs,X
                alu_op = `ALU_CMP; addr_mode = `AM_ABX;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'hDE: begin // DEC abs,X
                alu_op = `ALU_DEC; addr_mode = `AM_ABX; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'hDF: begin // CMP long,X
                alu_op = `ALU_CMP; addr_mode = `AM_LONGX;
                mem_read = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end

            // ========== Ex ==========
            8'hE0: begin // CPX #imm
                alu_op = `ALU_CMP; addr_mode = `AM_IMM; src_reg = `REG_X;
                flag_update = 1'b1;
            end
            8'hE1: begin // SBC (dp,X)
                alu_op = `ALU_SBC; addr_mode = `AM_IDPX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hE2: begin // SEP #imm8 (only sets non-M/X flags)
                category = `CAT_FLAG; addr_mode = `AM_IMM8;
            end
            8'hE3: begin // SBC sr,S
                alu_op = `ALU_SBC; addr_mode = `AM_SR;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hE4: begin // CPX dp
                alu_op = `ALU_CMP; addr_mode = `AM_DP; src_reg = `REG_X;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'hE5: begin // SBC dp
                alu_op = `ALU_SBC; addr_mode = `AM_DP;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hE6: begin // INC dp
                alu_op = `ALU_INC; addr_mode = `AM_DP; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'hE7: begin // SBC [dp]
                alu_op = `ALU_SBC; addr_mode = `AM_IDPL;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end
            8'hE8: begin // INX
                alu_op = `ALU_INC; addr_mode = `AM_IMP;
                src_reg = `REG_X; dst_reg = `REG_X;
                reg_write = 1'b1; flag_update = 1'b1;
                category = `CAT_XFER;
            end
            8'hE9: begin // SBC #imm
                alu_op = `ALU_SBC; addr_mode = `AM_IMM;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hEA: begin // NOP
                category = `CAT_SPECIAL;
            end
            8'hEB: begin // XBA
                category = `CAT_SPECIAL;
            end
            8'hEC: begin // CPX abs
                alu_op = `ALU_CMP; addr_mode = `AM_ABS; src_reg = `REG_X;
                mem_read = 1'b1; flag_update = 1'b1;
            end
            8'hED: begin // SBC abs
                alu_op = `ALU_SBC; addr_mode = `AM_ABS;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hEE: begin // INC abs
                alu_op = `ALU_INC; addr_mode = `AM_ABS; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'hEF: begin // SBC long
                alu_op = `ALU_SBC; addr_mode = `AM_LONG;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end

            // ========== Fx ==========
            8'hF0: begin // BEQ
                category = `CAT_BRANCH; addr_mode = `AM_REL; branch_cond = `BR_EQ;
            end
            8'hF1: begin // SBC (dp),Y
                alu_op = `ALU_SBC; addr_mode = `AM_IDPY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hF2: begin // SBC (dp)
                alu_op = `ALU_SBC; addr_mode = `AM_IDP;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hF3: begin // SBC (sr,S),Y
                alu_op = `ALU_SBC; addr_mode = `AM_SRY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hF4: begin // PEA abs16 (push effective absolute)
                category = `CAT_STACK; addr_mode = `AM_PEA;
            end
            8'hF5: begin // SBC dp,X
                alu_op = `ALU_SBC; addr_mode = `AM_DPX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hF6: begin // INC dp,X
                alu_op = `ALU_INC; addr_mode = `AM_DPX; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'hF7: begin // SBC [dp],Y
                alu_op = `ALU_SBC; addr_mode = `AM_IDPLY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end
            8'hF8: begin // SED
                category = `CAT_FLAG;
            end
            8'hF9: begin // SBC abs,Y
                alu_op = `ALU_SBC; addr_mode = `AM_ABY;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hFA: begin // PLX
                category = `CAT_STACK; dst_reg = `REG_X;
                reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hFB: begin // XCE (NOP in 16-bit only mode)
                category = `CAT_SPECIAL;
            end
            8'hFC: begin // JSR (abs,X)
                category = `CAT_JUMP; addr_mode = `AM_INDX;
            end
            8'hFD: begin // SBC abs,X
                alu_op = `ALU_SBC; addr_mode = `AM_ABX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
            end
            8'hFE: begin // INC abs,X
                alu_op = `ALU_INC; addr_mode = `AM_ABX; category = `CAT_RMW;
                mem_read = 1'b1; mem_write = 1'b1; flag_update = 1'b1;
            end
            8'hFF: begin // SBC long,X
                alu_op = `ALU_SBC; addr_mode = `AM_LONGX;
                mem_read = 1'b1; reg_write = 1'b1; flag_update = 1'b1;
                is_long_addr = 1'b1;
            end
        endcase
    end

endmodule
