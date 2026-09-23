`include "cpu_defines.vh"

module cpu_core (
    input  wire        clk,
    input  wire        rst_n,

    // Bus interface (16-bit data bus)
    output reg  [23:0] bus_addr,
    output reg  [15:0] bus_wdata,
    input  wire [15:0] bus_rdata,
    output reg         bus_we,
    output reg         bus_re,
    output reg         bus_valid,
    input  wire        bus_ready,
    output reg         bus_width,    // 0=byte, 1=word

    // Interrupts
    input  wire        int_pending,
    input  wire [15:0] int_vector,
    output reg         int_ack,
    output wire        cpu_brk,
    output wire        cpu_cop,

    // DMA halt
    input  wire        dma_active,

    // Processor status output
    output wire [7:0]  p_out,

    // Debug
    output wire [23:0] dbg_pc,
    output wire [7:0]  dbg_opcode,
    output wire [5:0]  dbg_state
);

    // ==============================================================
    // State register
    // ==============================================================
    reg [5:0] state, next_state;

    reg [5:0] state_prev;
    wire      bus_ack = bus_ready & (state == state_prev);

    // ==============================================================
    // Instruction latch
    // ==============================================================
    reg [7:0]  opcode;
    reg [7:0]  operand_lo, operand_hi, operand_bk;
    reg [7:0]  indirect_lo, indirect_hi, indirect_bk;
    reg [15:0] data_latch;
    reg [15:0] result_latch;
    reg [23:0] eff_addr_r;

    // ==============================================================
    // Control Unit (combinational decode)
    // ==============================================================
    wire [3:0] dec_alu_op;
    wire [4:0] dec_addr_mode;
    wire [2:0] dec_src_reg, dec_dst_reg, dec_category, dec_branch_cond;
    wire       dec_mem_read, dec_mem_write, dec_reg_write, dec_flag_update;
    wire       dec_is_store, dec_is_long, dec_valid;

    control_unit u_decode (
        .opcode      (opcode),
        .alu_op      (dec_alu_op),
        .addr_mode   (dec_addr_mode),
        .src_reg     (dec_src_reg),
        .dst_reg     (dec_dst_reg),
        .category    (dec_category),
        .branch_cond (dec_branch_cond),
        .mem_read    (dec_mem_read),
        .mem_write   (dec_mem_write),
        .reg_write   (dec_reg_write),
        .flag_update (dec_flag_update),
        .is_store    (dec_is_store),
        .is_long_addr(dec_is_long),
        .valid       (dec_valid)
    );

    // ==============================================================
    // Register File
    // ==============================================================
    reg  [2:0]  rf_rd_sel_a, rf_rd_sel_b;
    reg  [2:0]  rf_wr_sel;
    reg  [15:0] rf_wr_data;
    reg         rf_wr_en, rf_wr_byte_lo;
    reg         rf_pc_wr_en, rf_pc_inc;
    reg  [15:0] rf_pc_wr_data;
    reg         rf_pbr_wr_en, rf_dbr_wr_en;
    reg  [7:0]  rf_pbr_wr_data, rf_dbr_wr_data;
    reg         rf_p_wr_en;
    reg  [7:0]  rf_p_wr_data, rf_p_wr_mask;
    reg         rf_sp_dec, rf_sp_inc;
    reg         rf_sp_dec2, rf_sp_inc2;

    wire [15:0] rf_rd_data_a, rf_rd_data_b;
    wire [15:0] rf_pc_out, rf_sp_out, rf_a_out, rf_x_out, rf_y_out, rf_dp_out;
    wire [7:0]  rf_pbr_out, rf_dbr_out, rf_p_out;

    assign dbg_pc     = {rf_pbr_out, rf_pc_out};
    assign dbg_opcode = opcode;
    assign dbg_state  = state;

    assign cpu_brk = (state == `S_DECODE) && (opcode == 8'h00);
    assign cpu_cop = (state == `S_DECODE) && (opcode == 8'h02);
    assign p_out = rf_p_out;

    register_file u_regs (
        .clk        (clk),
        .rst_n      (rst_n),
        .rd_sel_a   (rf_rd_sel_a),
        .rd_sel_b   (rf_rd_sel_b),
        .rd_data_a  (rf_rd_data_a),
        .rd_data_b  (rf_rd_data_b),
        .wr_en      (rf_wr_en),
        .wr_sel     (rf_wr_sel),
        .wr_data    (rf_wr_data),
        .wr_byte_lo (rf_wr_byte_lo),
        .pc_wr_en   (rf_pc_wr_en),
        .pc_wr_data (rf_pc_wr_data),
        .pc_inc     (rf_pc_inc),
        .pc_out     (rf_pc_out),
        .pbr_wr_en  (rf_pbr_wr_en),
        .pbr_wr_data(rf_pbr_wr_data),
        .pbr_out    (rf_pbr_out),
        .dbr_wr_en  (rf_dbr_wr_en),
        .dbr_wr_data(rf_dbr_wr_data),
        .dbr_out    (rf_dbr_out),
        .p_wr_en    (rf_p_wr_en),
        .p_wr_data  (rf_p_wr_data),
        .p_wr_mask  (rf_p_wr_mask),
        .p_out      (rf_p_out),
        .sp_dec     (rf_sp_dec),
        .sp_inc     (rf_sp_inc),
        .sp_dec2    (rf_sp_dec2),
        .sp_inc2    (rf_sp_inc2),
        .sp_out     (rf_sp_out),
        .a_out      (rf_a_out),
        .x_out      (rf_x_out),
        .y_out      (rf_y_out),
        .dp_out     (rf_dp_out)
    );

    // ==============================================================
    // ALU
    // ==============================================================
    reg  [15:0] alu_a_in, alu_b_in;
    wire [15:0] alu_result;
    wire        alu_carry, alu_zero, alu_neg, alu_ovf;

    alu u_alu (
        .op           (dec_alu_op),
        .a            (alu_a_in),
        .b            (alu_b_in),
        .carry_in     (rf_p_out[`P_C]),
        .decimal      (rf_p_out[`P_D]),
        .result       (alu_result),
        .carry_out    (alu_carry),
        .zero         (alu_zero),
        .negative     (alu_neg),
        .overflow_out (alu_ovf)
    );

    // ==============================================================
    // Address Generator
    // ==============================================================
    wire [23:0] ag_eff_addr, ag_ptr_addr;
    wire [1:0]  ag_operand_bytes;
    wire        ag_needs_indirect;
    wire [1:0]  ag_indirect_bytes;

    address_gen u_addr (
        .addr_mode     (dec_addr_mode),
        .operand_lo    (operand_lo),
        .operand_hi    (operand_hi),
        .operand_bk    (operand_bk),
        .reg_x         (rf_x_out),
        .reg_y         (rf_y_out),
        .reg_sp        (rf_sp_out),
        .reg_dp        (rf_dp_out),
        .reg_dbr       (rf_dbr_out),
        .reg_pbr       (rf_pbr_out),
        .reg_pc        (rf_pc_out),
        .indirect_lo   (indirect_lo),
        .indirect_hi   (indirect_hi),
        .indirect_bk   (indirect_bk),
        .eff_addr      (ag_eff_addr),
        .ptr_addr      (ag_ptr_addr),
        .operand_bytes (ag_operand_bytes),
        .needs_indirect(ag_needs_indirect),
        .indirect_bytes(ag_indirect_bytes)
    );

    // ==============================================================
    // Branch condition evaluation
    // ==============================================================
    reg branch_taken;
    always @(*) begin
        case (dec_branch_cond)
            `BR_CC: branch_taken = ~rf_p_out[`P_C];
            `BR_CS: branch_taken =  rf_p_out[`P_C];
            `BR_EQ: branch_taken =  rf_p_out[`P_Z];
            `BR_NE: branch_taken = ~rf_p_out[`P_Z];
            `BR_MI: branch_taken =  rf_p_out[`P_N];
            `BR_PL: branch_taken = ~rf_p_out[`P_N];
            `BR_VS: branch_taken =  rf_p_out[`P_V];
            `BR_VC: branch_taken = ~rf_p_out[`P_V];
        endcase
        if (opcode == 8'h80 || opcode == 8'h82)
            branch_taken = 1'b1;
    end

    wire [15:0] branch_offset_8  = {{8{operand_lo[7]}}, operand_lo};
    wire [15:0] branch_offset_16 = {operand_hi, operand_lo};

    // ==============================================================
    // Push/Pull byte vs word helpers
    // ==============================================================
    wire push_is_byte = (opcode == 8'h08) || (opcode == 8'h4B) || (opcode == 8'h8B);
    wire pull_is_byte = (opcode == 8'h28) || (opcode == 8'hAB);

    // ==============================================================
    // Block move state
    // ==============================================================
    reg [7:0] bm_src_bank, bm_dst_bank;

    // ==============================================================
    // Main State Machine
    // ==============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `S_RESET;
            state_prev <= `S_RESET;
        end else if (!dma_active) begin
            state_prev <= state;
            state <= next_state;
        end
    end

    always @(*) begin
        // Default: hold everything
        next_state      = state;
        bus_addr        = 24'd0;
        bus_wdata       = 16'd0;
        bus_we          = 1'b0;
        bus_re          = 1'b0;
        bus_valid       = 1'b0;
        bus_width       = 1'b0;
        int_ack         = 1'b0;

        rf_wr_en        = 1'b0;
        rf_wr_sel       = `REG_A;
        rf_wr_data      = 16'd0;
        rf_wr_byte_lo   = 1'b0;
        rf_pc_wr_en     = 1'b0;
        rf_pc_wr_data   = 16'd0;
        rf_pc_inc       = 1'b0;
        rf_pbr_wr_en    = 1'b0;
        rf_pbr_wr_data  = 8'd0;
        rf_dbr_wr_en    = 1'b0;
        rf_dbr_wr_data  = 8'd0;
        rf_p_wr_en      = 1'b0;
        rf_p_wr_data    = 8'd0;
        rf_p_wr_mask    = 8'd0;
        rf_sp_dec       = 1'b0;
        rf_sp_inc       = 1'b0;
        rf_sp_dec2      = 1'b0;
        rf_sp_inc2      = 1'b0;
        rf_rd_sel_a     = dec_src_reg;
        rf_rd_sel_b     = dec_dst_reg;

        alu_a_in        = rf_a_out;
        alu_b_in        = data_latch;

        case (state)
            // ==========================================
            // RESET
            // ==========================================
            `S_RESET: begin
                next_state = `S_VEC;
            end

            // ==========================================
            // RESET VECTOR (16-bit read)
            // ==========================================
            `S_VEC: begin
                bus_addr  = {8'h00, `VEC_RESET};
                bus_re    = 1'b1;
                bus_valid = 1'b1;
                bus_width = 1'b1;
                if (bus_ack) begin
                    rf_pc_wr_en    = 1'b1;
                    rf_pc_wr_data  = bus_rdata;
                    rf_pbr_wr_en   = 1'b1;
                    rf_pbr_wr_data = 8'h00;
                    next_state = `S_FETCH_OP;
                end
            end

            // ==========================================
            // FETCH OPCODE (8-bit read)
            // ==========================================
            `S_FETCH_OP: begin
                if (int_pending && opcode != 8'h00 && opcode != 8'h02) begin
                    next_state = `S_INT_PUSH_PBR;
                end else begin
                    bus_addr  = {rf_pbr_out, rf_pc_out};
                    bus_re    = 1'b1;
                    bus_valid = 1'b1;
                    if (bus_ack) begin
                        rf_pc_inc  = 1'b1;
                        next_state = `S_DECODE;
                    end
                end
            end

            // ==========================================
            // DECODE
            // ==========================================
            `S_DECODE: begin
                case (dec_category)
                    `CAT_ALU, `CAT_RMW: begin
                        if (ag_operand_bytes > 2'd0)
                            next_state = `S_FETCH_OP1;
                        else
                            next_state = `S_EXECUTE;
                    end

                    `CAT_BRANCH: begin
                        next_state = `S_FETCH_OP1;
                    end

                    `CAT_JUMP: begin
                        case (opcode)
                            8'h40: next_state = `S_RTI_PULL_P;
                            8'h60: next_state = `S_RTS_PULL;
                            8'h6B: next_state = `S_RTS_PULL;   // RTL reuses RTS_PULL then pulls BK
                            default: next_state = `S_FETCH_OP1;
                        endcase
                    end

                    `CAT_STACK: begin
                        case (opcode)
                            8'h08, 8'h4B, 8'h8B: next_state = `S_PUSH; // 8-bit push
                            8'h48, 8'h5A, 8'hDA: next_state = `S_PUSH; // 16-bit push
                            8'h0B:                next_state = `S_PUSH; // PHD
                            8'h28, 8'hAB:         next_state = `S_PULL; // 8-bit pull
                            8'h68, 8'h7A, 8'hFA: next_state = `S_PULL; // 16-bit pull
                            8'h2B:                next_state = `S_PULL; // PLD
                            8'hF4, 8'hD4, 8'h62: next_state = `S_FETCH_OP1; // PEA/PEI/PER
                            default: next_state = `S_FETCH_OP;
                        endcase
                    end

                    `CAT_FLAG: begin
                        case (opcode)
                            8'h18: begin // CLC
                                rf_p_wr_en   = 1'b1;
                                rf_p_wr_data = rf_p_out & ~(8'd1 << `P_C);
                                rf_p_wr_mask = 8'hFF;
                            end
                            8'h38: begin // SEC
                                rf_p_wr_en   = 1'b1;
                                rf_p_wr_data = rf_p_out | (8'd1 << `P_C);
                                rf_p_wr_mask = 8'hFF;
                            end
                            8'h58: begin // CLI
                                rf_p_wr_en   = 1'b1;
                                rf_p_wr_data = rf_p_out & ~(8'd1 << `P_I);
                                rf_p_wr_mask = 8'hFF;
                            end
                            8'h78: begin // SEI
                                rf_p_wr_en   = 1'b1;
                                rf_p_wr_data = rf_p_out | (8'd1 << `P_I);
                                rf_p_wr_mask = 8'hFF;
                            end
                            8'hB8: begin // CLV
                                rf_p_wr_en   = 1'b1;
                                rf_p_wr_data = rf_p_out & ~(8'd1 << `P_V);
                                rf_p_wr_mask = 8'hFF;
                            end
                            8'hD8: begin // CLD
                                rf_p_wr_en   = 1'b1;
                                rf_p_wr_data = rf_p_out & ~(8'd1 << `P_D);
                                rf_p_wr_mask = 8'hFF;
                            end
                            8'hF8: begin // SED
                                rf_p_wr_en   = 1'b1;
                                rf_p_wr_data = rf_p_out | (8'd1 << `P_D);
                                rf_p_wr_mask = 8'hFF;
                            end
                            8'hC2, 8'hE2: begin // REP, SEP: need operand
                                next_state = `S_FETCH_OP1;
                            end
                            default: ;
                        endcase
                        if (opcode != 8'hC2 && opcode != 8'hE2)
                            next_state = `S_FETCH_OP;
                    end

                    `CAT_XFER: begin
                        next_state = `S_EXECUTE;
                    end

                    `CAT_SPECIAL: begin
                        case (opcode)
                            8'h00: next_state = `S_INT_PUSH_PBR; // BRK
                            8'h02: next_state = `S_INT_PUSH_PBR; // COP
                            8'hCB: next_state = `S_WAI;
                            8'hDB: next_state = `S_STP;
                            8'hEB: next_state = `S_XBA;
                            8'h42: next_state = `S_FETCH_OP1;    // WDM
                            8'h44, 8'h54: next_state = `S_FETCH_OP1; // MVP, MVN
                            8'hEA, 8'hFB: next_state = `S_FETCH_OP;  // NOP, XCE
                            default: next_state = `S_FETCH_OP;
                        endcase
                    end

                    default: next_state = `S_FETCH_OP;
                endcase
            end

            // ==========================================
            // OPERAND FETCH (8-bit reads, kept as-is)
            // ==========================================
            `S_FETCH_OP1: begin
                bus_addr  = {rf_pbr_out, rf_pc_out};
                bus_re    = 1'b1;
                bus_valid = 1'b1;
                if (bus_ack) begin
                    rf_pc_inc = 1'b1;
                    if (ag_operand_bytes > 2'd1)
                        next_state = `S_FETCH_OP2;
                    else begin
                        if (dec_category == `CAT_BRANCH)
                            next_state = `S_BRANCH;
                        else if (dec_category == `CAT_FLAG)
                            next_state = `S_EXECUTE;
                        else if (dec_category == `CAT_SPECIAL && (opcode == 8'h42))
                            next_state = `S_FETCH_OP;
                        else if (dec_category == `CAT_SPECIAL && (opcode == 8'h44 || opcode == 8'h54))
                            next_state = `S_FETCH_OP2;
                        else if (ag_needs_indirect)
                            next_state = `S_ADDR;
                        else if (dec_is_store)
                            next_state = `S_DATA_WR;
                        else if (dec_mem_read)
                            next_state = `S_DATA_RD;
                        else
                            next_state = `S_EXECUTE;
                    end
                end
            end

            `S_FETCH_OP2: begin
                bus_addr  = {rf_pbr_out, rf_pc_out};
                bus_re    = 1'b1;
                bus_valid = 1'b1;
                if (bus_ack) begin
                    rf_pc_inc = 1'b1;
                    if (ag_operand_bytes > 2'd2)
                        next_state = `S_FETCH_OP3;
                    else begin
                        if (dec_category == `CAT_BRANCH)
                            next_state = `S_BRANCH;
                        else if (dec_category == `CAT_JUMP) begin
                            case (opcode)
                                8'h20: next_state = `S_JSR_PUSH;
                                8'h4C: begin // JMP abs
                                    rf_pc_wr_en = 1'b1;
                                    rf_pc_wr_data = {operand_hi, operand_lo};
                                    next_state = `S_FETCH_OP;
                                end
                                8'hFC: next_state = `S_JSR_PUSH;
                                default: begin
                                    if (ag_needs_indirect)
                                        next_state = `S_ADDR;
                                    else
                                        next_state = `S_EXECUTE;
                                end
                            endcase
                        end else if (dec_category == `CAT_STACK) begin
                            next_state = `S_PUSH;
                        end else if (dec_category == `CAT_SPECIAL && (opcode == 8'h44 || opcode == 8'h54)) begin
                            next_state = `S_BM_READ;
                        end else if (ag_needs_indirect)
                            next_state = `S_ADDR;
                        else if (dec_is_store)
                            next_state = `S_DATA_WR;
                        else if (dec_mem_read)
                            next_state = `S_DATA_RD;
                        else
                            next_state = `S_EXECUTE;
                    end
                end
            end

            `S_FETCH_OP3: begin
                bus_addr  = {rf_pbr_out, rf_pc_out};
                bus_re    = 1'b1;
                bus_valid = 1'b1;
                if (bus_ack) begin
                    rf_pc_inc = 1'b1;
                    if (dec_category == `CAT_JUMP) begin
                        case (opcode)
                            8'h22: next_state = `S_JSR_PUSH_BK;
                            8'h5C: begin // JML long
                                rf_pc_wr_en    = 1'b1;
                                rf_pc_wr_data  = {operand_hi, operand_lo};
                                rf_pbr_wr_en   = 1'b1;
                                rf_pbr_wr_data = operand_bk;
                                next_state = `S_FETCH_OP;
                            end
                            default: next_state = `S_EXECUTE;
                        endcase
                    end else if (dec_is_store)
                        next_state = `S_DATA_WR;
                    else if (dec_mem_read)
                        next_state = `S_DATA_RD;
                    else
                        next_state = `S_EXECUTE;
                end
            end

            // ==========================================
            // INDIRECT ADDRESS FETCH (16-bit read + optional bank byte)
            // ==========================================
            `S_ADDR: begin
                bus_addr  = ag_ptr_addr;
                bus_re    = 1'b1;
                bus_valid = 1'b1;
                bus_width = 1'b1;
                if (bus_ack) begin
                    if (ag_indirect_bytes > 2'd2)
                        next_state = `S_ADDR_BK;
                    else begin
                        if (dec_category == `CAT_JUMP) begin
                            rf_pc_wr_en   = 1'b1;
                            rf_pc_wr_data = bus_rdata;
                            next_state = `S_FETCH_OP;
                        end else if (dec_category == `CAT_STACK)
                            next_state = `S_PUSH;
                        else if (dec_is_store)
                            next_state = `S_DATA_WR;
                        else if (dec_mem_read)
                            next_state = `S_DATA_RD;
                        else
                            next_state = `S_EXECUTE;
                    end
                end
            end

            `S_ADDR_BK: begin
                bus_addr  = ag_ptr_addr + 24'd2;
                bus_re    = 1'b1;
                bus_valid = 1'b1;
                if (bus_ack) begin
                    if (dec_category == `CAT_JUMP) begin
                        rf_pc_wr_en    = 1'b1;
                        rf_pc_wr_data  = {indirect_hi, indirect_lo};
                        rf_pbr_wr_en   = 1'b1;
                        rf_pbr_wr_data = bus_rdata[7:0];
                        next_state = `S_FETCH_OP;
                    end else if (dec_is_store)
                        next_state = `S_DATA_WR;
                    else if (dec_mem_read)
                        next_state = `S_DATA_RD;
                    else
                        next_state = `S_EXECUTE;
                end
            end

            // ==========================================
            // DATA READ (16-bit, single cycle)
            // ==========================================
            `S_DATA_RD: begin
                bus_addr  = ag_eff_addr;
                bus_re    = 1'b1;
                bus_valid = 1'b1;
                bus_width = 1'b1;
                if (bus_ack)
                    next_state = `S_EXECUTE;
            end

            // ==========================================
            // EXECUTE
            // ==========================================
            `S_EXECUTE: begin
                case (dec_category)
                    `CAT_ALU: begin
                        if (dec_addr_mode == `AM_ACC) begin
                            alu_a_in = rf_a_out;
                            alu_b_in = rf_a_out;
                        end else begin
                            alu_a_in = rf_rd_data_a;
                            alu_b_in = data_latch;
                        end

                        if (dec_reg_write) begin
                            rf_wr_en   = 1'b1;
                            rf_wr_sel  = dec_dst_reg;
                            rf_wr_data = alu_result;
                        end
                    end

                    `CAT_RMW: begin
                        alu_a_in = data_latch;
                        alu_b_in = data_latch;
                    end

                    `CAT_FLAG: begin
                        if (opcode == 8'hC2) begin // REP
                            rf_p_wr_en   = 1'b1;
                            rf_p_wr_data = rf_p_out & ~operand_lo;
                            rf_p_wr_mask = 8'hFF;
                        end else if (opcode == 8'hE2) begin // SEP
                            rf_p_wr_en   = 1'b1;
                            rf_p_wr_data = rf_p_out | operand_lo;
                            rf_p_wr_mask = 8'hFF;
                        end
                    end

                    `CAT_XFER: begin
                        rf_rd_sel_a = dec_src_reg;
                        rf_wr_en    = dec_reg_write;
                        rf_wr_sel   = dec_dst_reg;
                        rf_wr_data  = rf_rd_data_a;
                        if (dec_alu_op == `ALU_INC || dec_alu_op == `ALU_DEC) begin
                            alu_a_in   = rf_rd_data_a;
                            rf_wr_data = alu_result;
                        end
                    end

                    default: ;
                endcase

                // Update flags
                if (dec_flag_update && dec_category != `CAT_FLAG) begin
                    rf_p_wr_en = 1'b1;
                    rf_p_wr_mask = 8'h00;
                    rf_p_wr_data = rf_p_out;
                    rf_p_wr_mask = rf_p_wr_mask | (8'd1 << `P_N);
                    rf_p_wr_data[`P_N] = alu_neg;
                    rf_p_wr_mask = rf_p_wr_mask | (8'd1 << `P_Z);
                    rf_p_wr_data[`P_Z] = alu_zero;
                    if (dec_alu_op == `ALU_ADC || dec_alu_op == `ALU_SBC ||
                        dec_alu_op == `ALU_CMP ||
                        dec_alu_op == `ALU_ASL || dec_alu_op == `ALU_LSR ||
                        dec_alu_op == `ALU_ROL || dec_alu_op == `ALU_ROR) begin
                        rf_p_wr_mask = rf_p_wr_mask | (8'd1 << `P_C);
                        rf_p_wr_data[`P_C] = alu_carry;
                    end
                    if (dec_alu_op == `ALU_ADC || dec_alu_op == `ALU_SBC ||
                        dec_alu_op == `ALU_BIT) begin
                        rf_p_wr_mask = rf_p_wr_mask | (8'd1 << `P_V);
                        rf_p_wr_data[`P_V] = alu_ovf;
                    end
                end

                if (dec_category == `CAT_RMW)
                    next_state = `S_DATA_WR;
                else
                    next_state = `S_FETCH_OP;
            end

            // ==========================================
            // DATA WRITE (16-bit, single cycle)
            // ==========================================
            `S_DATA_WR: begin
                bus_addr  = ag_eff_addr;
                bus_we    = 1'b1;
                bus_valid = 1'b1;
                bus_width = 1'b1;
                if (dec_category == `CAT_RMW)
                    bus_wdata = alu_result;
                else if (dec_is_store) begin
                    if (opcode == 8'h64 || opcode == 8'h74 ||
                        opcode == 8'h9C || opcode == 8'h9E)
                        bus_wdata = 16'h0000; // STZ
                    else
                        bus_wdata = rf_rd_data_a;
                end
                if (bus_ack)
                    next_state = `S_FETCH_OP;
            end

            // ==========================================
            // BRANCH
            // ==========================================
            `S_BRANCH: begin
                if (branch_taken) begin
                    if (dec_addr_mode == `AM_RELL) begin
                        rf_pc_wr_en   = 1'b1;
                        rf_pc_wr_data = rf_pc_out + branch_offset_16;
                    end else begin
                        rf_pc_wr_en   = 1'b1;
                        rf_pc_wr_data = rf_pc_out + branch_offset_8;
                    end
                end
                next_state = `S_FETCH_OP;
            end

            // ==========================================
            // PUSH (8-bit or 16-bit, single cycle)
            // ==========================================
            `S_PUSH: begin
                rf_rd_sel_a = dec_src_reg;
                bus_we    = 1'b1;
                bus_valid = 1'b1;
                if (push_is_byte) begin
                    bus_addr  = {8'h00, rf_sp_out};
                    bus_width = 1'b0;
                    if (dec_src_reg == `REG_P)
                        bus_wdata = {8'h00, rf_p_out};
                    else if (dec_src_reg == `REG_PBR)
                        bus_wdata = {8'h00, rf_pbr_out};
                    else if (dec_src_reg == `REG_DBR)
                        bus_wdata = {8'h00, rf_dbr_out};
                    else
                        bus_wdata = {8'h00, rf_rd_data_a[7:0]};
                    if (bus_ack) begin
                        rf_sp_dec  = 1'b1;
                        next_state = `S_FETCH_OP;
                    end
                end else begin
                    bus_addr  = {8'h00, rf_sp_out - 16'd1};
                    bus_width = 1'b1;
                    if (dec_addr_mode == `AM_PEA)
                        bus_wdata = {operand_hi, operand_lo};
                    else if (dec_addr_mode == `AM_PER)
                        bus_wdata = rf_pc_out + branch_offset_16;
                    else if (dec_addr_mode == `AM_PEI)
                        bus_wdata = {indirect_hi, indirect_lo};
                    else
                        bus_wdata = rf_rd_data_a;
                    if (bus_ack) begin
                        rf_sp_dec2 = 1'b1;
                        next_state = `S_FETCH_OP;
                    end
                end
            end

            `S_PUSH_BK: begin
                bus_addr  = {8'h00, rf_sp_out};
                bus_we    = 1'b1;
                bus_valid = 1'b1;
                bus_wdata = {8'h00, rf_pbr_out};
                if (bus_ack) begin
                    rf_sp_dec  = 1'b1;
                    next_state = `S_JSR_PUSH;
                end
            end

            // ==========================================
            // PULL (8-bit or 16-bit, single cycle)
            // ==========================================
            `S_PULL: begin
                bus_re    = 1'b1;
                bus_valid = 1'b1;
                if (pull_is_byte) begin
                    bus_addr  = {8'h00, rf_sp_out + 16'd1};
                    bus_width = 1'b0;
                    if (bus_ack) begin
                        rf_sp_inc = 1'b1;
                        if (dec_dst_reg == `REG_P) begin
                            rf_p_wr_en   = 1'b1;
                            rf_p_wr_data = bus_rdata[7:0];
                            rf_p_wr_mask = 8'hFF;
                        end else if (dec_dst_reg == `REG_DBR) begin
                            rf_dbr_wr_en   = 1'b1;
                            rf_dbr_wr_data = bus_rdata[7:0];
                        end
                        next_state = `S_FETCH_OP;
                    end
                end else begin
                    bus_addr  = {8'h00, rf_sp_out + 16'd1};
                    bus_width = 1'b1;
                    if (bus_ack) begin
                        rf_sp_inc2 = 1'b1;
                        rf_wr_en   = 1'b1;
                        rf_wr_sel  = dec_dst_reg;
                        rf_wr_data = bus_rdata;
                        if (dec_flag_update) begin
                            rf_p_wr_en   = 1'b1;
                            rf_p_wr_mask = (8'd1 << `P_N) | (8'd1 << `P_Z);
                            rf_p_wr_data = rf_p_out;
                            rf_p_wr_data[`P_N] = bus_rdata[15];
                            rf_p_wr_data[`P_Z] = (bus_rdata == 16'h0000);
                        end
                        next_state = `S_FETCH_OP;
                    end
                end
            end

            // ==========================================
            // JSR / JSL (16-bit push of PC-1)
            // ==========================================
            `S_JSR_PUSH_BK: begin
                bus_addr  = {8'h00, rf_sp_out};
                bus_we    = 1'b1;
                bus_valid = 1'b1;
                bus_wdata = {8'h00, rf_pbr_out};
                if (bus_ack) begin
                    rf_sp_dec  = 1'b1;
                    next_state = `S_JSR_PUSH;
                end
            end

            `S_JSR_PUSH: begin
                bus_addr  = {8'h00, rf_sp_out - 16'd1};
                bus_we    = 1'b1;
                bus_valid = 1'b1;
                bus_width = 1'b1;
                bus_wdata = rf_pc_out - 16'd1;
                if (bus_ack) begin
                    rf_sp_dec2 = 1'b1;
                    if (opcode == 8'h22) begin // JSL
                        rf_pbr_wr_en   = 1'b1;
                        rf_pbr_wr_data = operand_bk;
                    end
                    if (ag_needs_indirect) begin
                        rf_pc_wr_en   = 1'b1;
                        rf_pc_wr_data = {indirect_hi, indirect_lo};
                    end else begin
                        rf_pc_wr_en   = 1'b1;
                        rf_pc_wr_data = {operand_hi, operand_lo};
                    end
                    next_state = `S_FETCH_OP;
                end
            end

            // ==========================================
            // RTS / RTL (16-bit pull of PC)
            // ==========================================
            `S_RTS_PULL: begin
                bus_addr  = {8'h00, rf_sp_out + 16'd1};
                bus_re    = 1'b1;
                bus_valid = 1'b1;
                bus_width = 1'b1;
                if (bus_ack) begin
                    rf_sp_inc2    = 1'b1;
                    rf_pc_wr_en   = 1'b1;
                    rf_pc_wr_data = bus_rdata + 16'd1;
                    if (opcode == 8'h6B) // RTL: also need to pull PBR
                        next_state = `S_RTL_PULL_BK;
                    else
                        next_state = `S_FETCH_OP;
                end
            end

            `S_RTL_PULL_BK: begin
                bus_addr  = {8'h00, rf_sp_out + 16'd1};
                bus_re    = 1'b1;
                bus_valid = 1'b1;
                if (bus_ack) begin
                    rf_sp_inc      = 1'b1;
                    rf_pbr_wr_en   = 1'b1;
                    rf_pbr_wr_data = bus_rdata[7:0];
                    next_state = `S_FETCH_OP;
                end
            end

            // ==========================================
            // INTERRUPT SEQUENCE
            // ==========================================
            `S_INT_PUSH_PBR: begin
                bus_addr  = {8'h00, rf_sp_out};
                bus_we    = 1'b1;
                bus_valid = 1'b1;
                bus_wdata = {8'h00, rf_pbr_out};
                if (bus_ack) begin
                    rf_sp_dec  = 1'b1;
                    next_state = `S_INT_PUSH_PC;
                end
            end

            `S_INT_PUSH_PC: begin
                bus_addr  = {8'h00, rf_sp_out - 16'd1};
                bus_we    = 1'b1;
                bus_valid = 1'b1;
                bus_width = 1'b1;
                bus_wdata = rf_pc_out;
                if (bus_ack) begin
                    rf_sp_dec2 = 1'b1;
                    next_state = `S_INT_PUSH_P;
                end
            end

            `S_INT_PUSH_P: begin
                bus_addr  = {8'h00, rf_sp_out};
                bus_we    = 1'b1;
                bus_valid = 1'b1;
                bus_wdata = {8'h00, rf_p_out};
                if (bus_ack) begin
                    rf_sp_dec = 1'b1;
                    rf_p_wr_en   = 1'b1;
                    rf_p_wr_data = rf_p_out | (8'd1 << `P_I);
                    rf_p_wr_mask = 8'hFF;
                    rf_pbr_wr_en   = 1'b1;
                    rf_pbr_wr_data = 8'h00;
                    next_state = `S_INT_VEC;
                end
            end

            `S_INT_VEC: begin
                bus_addr  = {8'h00, int_vector};
                bus_re    = 1'b1;
                bus_valid = 1'b1;
                bus_width = 1'b1;
                if (bus_ack) begin
                    rf_pc_wr_en   = 1'b1;
                    rf_pc_wr_data = bus_rdata;
                    int_ack = 1'b1;
                    next_state = `S_FETCH_OP;
                end
            end

            // ==========================================
            // RTI
            // ==========================================
            `S_RTI_PULL_P: begin
                bus_addr  = {8'h00, rf_sp_out + 16'd1};
                bus_re    = 1'b1;
                bus_valid = 1'b1;
                if (bus_ack) begin
                    rf_sp_inc    = 1'b1;
                    rf_p_wr_en   = 1'b1;
                    rf_p_wr_data = bus_rdata[7:0];
                    rf_p_wr_mask = 8'hFF;
                    next_state = `S_RTI_PULL_PC;
                end
            end

            `S_RTI_PULL_PC: begin
                bus_addr  = {8'h00, rf_sp_out + 16'd1};
                bus_re    = 1'b1;
                bus_valid = 1'b1;
                bus_width = 1'b1;
                if (bus_ack) begin
                    rf_sp_inc2 = 1'b1;
                    next_state = `S_RTI_PULL_PBR;
                end
            end

            `S_RTI_PULL_PBR: begin
                bus_addr  = {8'h00, rf_sp_out + 16'd1};
                bus_re    = 1'b1;
                bus_valid = 1'b1;
                if (bus_ack) begin
                    rf_sp_inc      = 1'b1;
                    rf_pbr_wr_en   = 1'b1;
                    rf_pbr_wr_data = bus_rdata[7:0];
                    rf_pc_wr_en    = 1'b1;
                    rf_pc_wr_data  = data_latch;
                    next_state = `S_FETCH_OP;
                end
            end

            // ==========================================
            // BLOCK MOVE (MVP/MVN) - stays 8-bit
            // ==========================================
            `S_BM_READ: begin
                bus_addr  = {operand_hi, rf_x_out};
                bus_re    = 1'b1;
                bus_valid = 1'b1;
                if (bus_ack)
                    next_state = `S_BM_WRITE;
            end

            `S_BM_WRITE: begin
                bus_addr  = {operand_lo, rf_y_out};
                bus_we    = 1'b1;
                bus_valid = 1'b1;
                bus_wdata = {8'h00, data_latch[7:0]};
                if (bus_ack)
                    next_state = `S_BM_NEXT;
            end

            `S_BM_NEXT: begin
                if (opcode == 8'h54) begin // MVN: increment
                    rf_wr_en = 1'b1; rf_wr_sel = `REG_X;
                    rf_wr_data = rf_x_out + 16'd1;
                end else begin // MVP: decrement
                    rf_wr_en = 1'b1; rf_wr_sel = `REG_X;
                    rf_wr_data = rf_x_out - 16'd1;
                end
                if (rf_a_out == 16'hFFFF) begin
                    rf_dbr_wr_en   = 1'b1;
                    rf_dbr_wr_data = operand_lo;
                    next_state = `S_FETCH_OP;
                end else begin
                    rf_pc_wr_en   = 1'b1;
                    rf_pc_wr_data = rf_pc_out - 16'd3;
                    next_state = `S_BM_READ;
                end
            end

            // ==========================================
            // SPECIAL
            // ==========================================
            `S_WAI: begin
                if (int_pending)
                    next_state = `S_FETCH_OP;
            end

            `S_STP: begin
                // Halted until reset
            end

            `S_XBA: begin
                rf_wr_en   = 1'b1;
                rf_wr_sel  = `REG_A;
                rf_wr_data = {rf_a_out[7:0], rf_a_out[15:8]};
                rf_p_wr_en   = 1'b1;
                rf_p_wr_mask = (8'd1 << `P_N) | (8'd1 << `P_Z);
                rf_p_wr_data = rf_p_out;
                rf_p_wr_data[`P_N] = rf_a_out[15];
                rf_p_wr_data[`P_Z] = (rf_a_out[15:8] == 8'h00);
                next_state = `S_FETCH_OP;
            end

            default: next_state = `S_RESET;
        endcase
    end

    // ==============================================================
    // Sequential data latching
    // ==============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            opcode      <= 8'h00;
            operand_lo  <= 8'h00;
            operand_hi  <= 8'h00;
            operand_bk  <= 8'h00;
            indirect_lo <= 8'h00;
            indirect_hi <= 8'h00;
            indirect_bk <= 8'h00;
            data_latch  <= 16'h0000;
            eff_addr_r  <= 24'h000000;
        end else if (!dma_active) begin
            case (state)
                `S_FETCH_OP: begin
                    if (bus_ack)
                        opcode <= bus_rdata[7:0];
                end

                `S_DECODE: begin
                    eff_addr_r <= ag_eff_addr;
                end

                `S_FETCH_OP1: begin
                    if (bus_ack) begin
                        operand_lo <= bus_rdata[7:0];
                        data_latch[7:0] <= bus_rdata[7:0];
                        eff_addr_r <= ag_eff_addr;
                    end
                end

                `S_FETCH_OP2: begin
                    if (bus_ack) begin
                        operand_hi <= bus_rdata[7:0];
                        data_latch[15:8] <= bus_rdata[7:0];
                        eff_addr_r <= ag_eff_addr;
                    end
                end

                `S_FETCH_OP3: begin
                    if (bus_ack) begin
                        operand_bk <= bus_rdata[7:0];
                        eff_addr_r <= ag_eff_addr;
                    end
                end

                `S_ADDR: begin
                    if (bus_ack) begin
                        indirect_lo <= bus_rdata[7:0];
                        indirect_hi <= bus_rdata[15:8];
                        eff_addr_r  <= ag_eff_addr;
                    end
                end

                `S_ADDR_BK: begin
                    if (bus_ack) begin
                        indirect_bk <= bus_rdata[7:0];
                        eff_addr_r  <= ag_eff_addr;
                    end
                end

                `S_DATA_RD: begin
                    if (bus_ack)
                        data_latch <= bus_rdata;
                end

                `S_EXECUTE: begin
                    result_latch <= alu_result;
                end

                `S_RTI_PULL_PC: begin
                    if (bus_ack)
                        data_latch <= bus_rdata;
                end

                `S_BM_READ: begin
                    if (bus_ack)
                        data_latch[7:0] <= bus_rdata[7:0];
                end

                default: ;
            endcase
        end
    end

endmodule
