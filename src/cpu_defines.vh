// SA1-GPCPU CPU Defines
// 16-bit only 65C816-derived processor

`ifndef CPU_DEFINES_VH
`define CPU_DEFINES_VH

// ============================================================
// ALU Operations
// ============================================================
`define ALU_ADC   4'd0
`define ALU_SBC   4'd1
`define ALU_AND   4'd2
`define ALU_ORA   4'd3
`define ALU_EOR   4'd4
`define ALU_ASL   4'd5
`define ALU_LSR   4'd6
`define ALU_ROL   4'd7
`define ALU_ROR   4'd8
`define ALU_INC   4'd9
`define ALU_DEC   4'd10
`define ALU_CMP   4'd11
`define ALU_BIT   4'd12
`define ALU_TSB   4'd13
`define ALU_TRB   4'd14
`define ALU_PASS  4'd15

// ============================================================
// Addressing Modes
// ============================================================
`define AM_IMP    5'd0    // Implied
`define AM_ACC    5'd1    // Accumulator
`define AM_IMM    5'd2    // Immediate 16-bit
`define AM_DP     5'd3    // Direct Page
`define AM_DPX    5'd4    // Direct Page,X
`define AM_DPY    5'd5    // Direct Page,Y
`define AM_IDP    5'd6    // (Direct Page)
`define AM_IDPX   5'd7    // (Direct Page,X)
`define AM_IDPY   5'd8    // (Direct Page),Y
`define AM_IDPL   5'd9    // [Direct Page]
`define AM_IDPLY  5'd10   // [Direct Page],Y
`define AM_ABS    5'd11   // Absolute
`define AM_ABX    5'd12   // Absolute,X
`define AM_ABY    5'd13   // Absolute,Y
`define AM_LONG   5'd14   // Absolute Long
`define AM_LONGX  5'd15   // Absolute Long,X
`define AM_IND    5'd16   // (Absolute)
`define AM_INDX   5'd17   // (Absolute,X)
`define AM_INDL   5'd18   // [Absolute]
`define AM_REL    5'd19   // Relative 8-bit
`define AM_RELL   5'd20   // Relative 16-bit
`define AM_SR     5'd21   // Stack Relative
`define AM_SRY    5'd22   // (Stack Relative),Y
`define AM_BM     5'd23   // Block Move
`define AM_PEA    5'd24   // Push Effective Address
`define AM_PEI    5'd25   // Push Effective Indirect
`define AM_PER    5'd26   // Push Effective Relative
`define AM_IMM8   5'd27   // Immediate 8-bit (REP/SEP)

// ============================================================
// Register IDs
// ============================================================
`define REG_A     3'd0
`define REG_X     3'd1
`define REG_Y     3'd2
`define REG_SP    3'd3
`define REG_DP    3'd4
`define REG_DBR   3'd5
`define REG_PBR   3'd6
`define REG_P     3'd7

// ============================================================
// Branch Conditions
// ============================================================
`define BR_CC     3'd0    // Carry Clear
`define BR_CS     3'd1    // Carry Set
`define BR_EQ     3'd2    // Equal (Z=1)
`define BR_NE     3'd3    // Not Equal (Z=0)
`define BR_MI     3'd4    // Minus (N=1)
`define BR_PL     3'd5    // Plus (N=0)
`define BR_VS     3'd6    // Overflow Set
`define BR_VC     3'd7    // Overflow Clear

// ============================================================
// Processor Status Bits
// ============================================================
`define P_C       0       // Carry
`define P_Z       1       // Zero
`define P_I       2       // IRQ Disable
`define P_D       3       // Decimal Mode
`define P_X       4       // Index 16-bit (always 0)
`define P_M       5       // Accumulator 16-bit (always 0)
`define P_V       6       // Overflow
`define P_N       7       // Negative

// ============================================================
// CPU States (16-bit bus: merged LO/HI pairs)
// ============================================================
`define S_RESET         6'd0
`define S_VEC           6'd1
`define S_FETCH_OP      6'd2
`define S_DECODE        6'd3
`define S_FETCH_OP1     6'd4
`define S_FETCH_OP2     6'd5
`define S_FETCH_OP3     6'd6
`define S_ADDR          6'd7
`define S_ADDR_BK       6'd8
`define S_DATA_RD       6'd9
`define S_EXECUTE       6'd10
`define S_DATA_WR       6'd11
`define S_PUSH          6'd12
`define S_PUSH_BK       6'd13
`define S_PULL          6'd14
`define S_BRANCH        6'd15
`define S_JSR_PUSH      6'd16
`define S_JSR_PUSH_BK   6'd17
`define S_RTS_PULL      6'd18
`define S_RTL_PULL_BK   6'd19
`define S_INT_PUSH_PBR  6'd20
`define S_INT_PUSH_PC   6'd21
`define S_INT_PUSH_P    6'd22
`define S_INT_VEC       6'd23
`define S_RTI_PULL_P    6'd24
`define S_RTI_PULL_PC   6'd25
`define S_RTI_PULL_PBR  6'd26
`define S_BM_READ       6'd27
`define S_BM_WRITE      6'd28
`define S_BM_NEXT       6'd29
`define S_WAI           6'd30
`define S_STP           6'd31
`define S_XBA           6'd32

// ============================================================
// Interrupt Vectors (bank 00)
// ============================================================
`define VEC_COP     16'hFFE4
`define VEC_BRK     16'hFFE6
`define VEC_ABORT   16'hFFE8
`define VEC_NMI     16'hFFEA
`define VEC_IRQ     16'hFFEE
`define VEC_RESET   16'hFFFC

// ============================================================
// Instruction Categories (for control unit)
// ============================================================
`define CAT_ALU     3'd0    // ALU operation (LDA/STA/ADC/etc)
`define CAT_RMW     3'd1    // Read-modify-write (INC/DEC/ASL/etc on memory)
`define CAT_BRANCH  3'd2    // Branch instructions
`define CAT_JUMP    3'd3    // Jump/Call/Return
`define CAT_STACK   3'd4    // Push/Pull
`define CAT_FLAG    3'd5    // Flag manipulation
`define CAT_XFER    3'd6    // Register transfer
`define CAT_SPECIAL 3'd7    // BRK/COP/WAI/STP/NOP/etc

`endif
