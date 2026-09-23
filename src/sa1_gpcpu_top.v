`include "cpu_defines.vh"

module sa1_gpcpu_top (
    input  wire        clk,
    input  wire        rst_n,

    // External memory bus (16-bit data)
    output wire [23:0] mem_addr,
    output wire [15:0] mem_wdata,
    input  wire [15:0] mem_rdata,
    output wire        mem_we,
    output wire        mem_re,
    output wire        mem_valid,
    input  wire        mem_ready,
    output wire        mem_width,

    // External interrupts
    input  wire        irq_n,
    input  wire        nmi_n,

    // Debug outputs
    output wire [23:0] dbg_pc,
    output wire [7:0]  dbg_opcode,
    output wire [5:0]  dbg_state
);

    // ==============================================================
    // Internal bus signals
    // ==============================================================

    // CPU <-> Bus Arbiter (16-bit data)
    wire [23:0] cpu_addr;
    wire [15:0] cpu_wdata;
    wire [15:0] cpu_rdata;
    wire        cpu_we, cpu_re, cpu_valid, cpu_ready;
    wire        cpu_width;

    // DMA <-> Bus Arbiter (8-bit)
    wire [23:0] dma_addr;
    wire [7:0]  dma_wdata;
    wire [7:0]  dma_rdata;
    wire        dma_we, dma_re, dma_valid, dma_ready;
    wire        dma_active;

    // VarLen <-> Bus Arbiter (8-bit read-only)
    wire [23:0] vlb_addr;
    wire [7:0]  vlb_rdata;
    wire        vlb_re, vlb_ready;

    // Interrupt signals
    wire        int_pending;
    wire [15:0] int_vector;
    wire        int_ack;
    wire        cpu_brk, cpu_cop;
    wire [7:0]  p_out;
    wire        timer_irq, dma_irq;

    // ==============================================================
    // I/O Register Decode
    // ==============================================================
    // I/O region: bank $00, addresses $4200-$43FF
    wire io_select = (cpu_addr[23:16] == 8'h00) &&
                     (cpu_addr[15:9] == 7'b010_0001); // $4200-$43FF
    wire io_read   = io_select && cpu_re;
    wire io_write  = io_select && cpu_we;

    wire intc_sel  = io_select && (cpu_addr[8:4] == 5'h00); // $4200-$420F
    wire timer_sel = io_select && (cpu_addr[8:4] == 5'h01); // $4210-$421F
    wire dma_sel   = io_select && (cpu_addr[8:4] >= 5'h02)
                               && (cpu_addr[8:4] <= 5'h05); // $4220-$425F
    wire math_sel  = io_select && (cpu_addr[8:4] == 5'h06); // $4260-$426F
    wire vlb_sel   = io_select && (cpu_addr[8:4] == 5'h07); // $4270-$427F

    // I/O register interface signals
    wire [7:0] intc_rd_data, timer_rd_data, dma_rd_data, vlb_rd_data;

    // I/O read data mux (16-bit: low byte from addr, high byte from addr+1)
    reg [15:0] io_rd_data;
    reg        io_rd_valid;

    // Math unit read data (16-bit, handled inline)
    reg [15:0] math_rd_data;

    always @(*) begin
        io_rd_data  = 16'h0000;
        io_rd_valid = 1'b0;
        if (io_select) begin
            io_rd_valid = 1'b1;
            if (intc_sel)       io_rd_data = {8'h00, intc_rd_data};
            else if (timer_sel) io_rd_data = {8'h00, timer_rd_data};
            else if (dma_sel)   io_rd_data = {8'h00, dma_rd_data};
            else if (math_sel)  io_rd_data = math_rd_data;
            else if (vlb_sel)   io_rd_data = {8'h00, vlb_rd_data};
        end
    end

    // ==============================================================
    // CPU Core
    // ==============================================================
    wire [15:0] cpu_bus_rdata = io_rd_valid ? io_rd_data : cpu_rdata;
    wire        cpu_bus_ready = io_rd_valid ? cpu_valid : cpu_ready;

    cpu_core u_cpu (
        .clk        (clk),
        .rst_n      (rst_n),
        .bus_addr   (cpu_addr),
        .bus_wdata  (cpu_wdata),
        .bus_rdata  (cpu_bus_rdata),
        .bus_we     (cpu_we),
        .bus_re     (cpu_re),
        .bus_valid  (cpu_valid),
        .bus_ready  (cpu_bus_ready),
        .bus_width  (cpu_width),
        .int_pending(int_pending),
        .int_vector (int_vector),
        .int_ack    (int_ack),
        .cpu_brk    (cpu_brk),
        .cpu_cop    (cpu_cop),
        .dma_active (dma_active),
        .p_out      (p_out),
        .dbg_pc     (dbg_pc),
        .dbg_opcode (dbg_opcode),
        .dbg_state  (dbg_state)
    );

    // ==============================================================
    // Interrupt Controller
    // ==============================================================
    interrupt_ctrl u_intc (
        .clk        (clk),
        .rst_n      (rst_n),
        .irq_n      (irq_n),
        .nmi_n      (nmi_n),
        .timer_irq  (timer_irq),
        .dma_irq    (dma_irq),
        .math_irq   (1'b0),
        .irq_disable(p_out[`P_I]),
        .cpu_brk    (cpu_brk),
        .cpu_cop    (cpu_cop),
        .int_ack    (int_ack),
        .int_pending(int_pending),
        .int_vector (int_vector),
        .int_type   (),
        .reg_wr_en  (intc_sel & io_write),
        .reg_addr   (cpu_addr[1:0]),
        .reg_wr_data(cpu_wdata[7:0]),
        .reg_rd_data(intc_rd_data)
    );

    // ==============================================================
    // Timer
    // ==============================================================
    wire timer1_irq;

    timer u_timer (
        .clk        (clk),
        .rst_n      (rst_n),
        .timer0_irq (timer_irq),
        .timer1_irq (timer1_irq),
        .reg_wr_en  (timer_sel & io_write),
        .reg_rd_en  (timer_sel & io_read),
        .reg_addr   (cpu_addr[3:0]),
        .reg_wr_data(cpu_wdata[7:0]),
        .reg_rd_data(timer_rd_data)
    );

    // ==============================================================
    // DMA Controller
    // ==============================================================
    dma_controller u_dma (
        .clk        (clk),
        .rst_n      (rst_n),
        .dma_addr   (dma_addr),
        .dma_wdata  (dma_wdata),
        .dma_rdata  (dma_rdata),
        .dma_we     (dma_we),
        .dma_re     (dma_re),
        .dma_valid  (dma_valid),
        .dma_ready  (dma_ready),
        .dma_active (dma_active),
        .dma_irq    (dma_irq),
        .reg_wr_en  (dma_sel & io_write),
        .reg_addr   (cpu_addr[5:0] - 6'h20),
        .reg_wr_data(cpu_wdata[7:0]),
        .reg_rd_data(dma_rd_data)
    );

    // ==============================================================
    // Math Unit (memory-mapped, word-aware)
    // ==============================================================
    reg [15:0] math_mul_a, math_mul_b;
    reg [31:0] math_div_dividend;
    reg [15:0] math_div_divisor;
    reg        math_mul_start, math_div_start;
    reg        math_cum_add, math_cum_clear;

    wire [31:0] math_mul_result;
    wire        math_mul_done;
    wire [15:0] math_div_quotient, math_div_remainder;
    wire        math_div_done, math_div_overflow;
    wire [39:0] math_cum_sum;

    math_unit u_math (
        .clk          (clk),
        .rst_n        (rst_n),
        .mul_start    (math_mul_start),
        .mul_a        (math_mul_a),
        .mul_b        (math_mul_b),
        .mul_result   (math_mul_result),
        .mul_done     (math_mul_done),
        .div_start    (math_div_start),
        .div_dividend (math_div_dividend),
        .div_divisor  (math_div_divisor),
        .div_quotient (math_div_quotient),
        .div_remainder(math_div_remainder),
        .div_done     (math_div_done),
        .div_overflow (math_div_overflow),
        .cum_add      (math_cum_add),
        .cum_clear    (math_cum_clear),
        .cum_sum      (math_cum_sum)
    );

    // Math unit register write interface
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            math_mul_a      <= 16'd0;
            math_mul_b      <= 16'd0;
            math_div_dividend <= 32'd0;
            math_div_divisor  <= 16'd0;
            math_mul_start  <= 1'b0;
            math_div_start  <= 1'b0;
            math_cum_add    <= 1'b0;
            math_cum_clear  <= 1'b0;
        end else begin
            math_mul_start <= 1'b0;
            math_div_start <= 1'b0;
            math_cum_add   <= 1'b0;
            math_cum_clear <= 1'b0;

            if (math_mul_done)
                math_cum_add <= 1'b1;

            if (math_sel & io_write) begin
                if (cpu_width) begin
                    // Word write: even-aligned, writes both bytes
                    case (cpu_addr[3:0])
                        4'h0: math_mul_a <= cpu_wdata;
                        4'h2: begin
                            math_mul_b <= cpu_wdata;
                            math_mul_start <= 1'b1;
                        end
                        4'h8: math_div_dividend[15:0]  <= cpu_wdata;
                        4'hA: math_div_dividend[31:16] <= cpu_wdata;
                        4'hC: begin
                            math_div_divisor <= cpu_wdata;
                            math_div_start <= 1'b1;
                        end
                        4'hE: begin
                            if (cpu_wdata[8])
                                math_cum_clear <= 1'b1;
                        end
                        default: ;
                    endcase
                end else begin
                    // Byte write
                    case (cpu_addr[3:0])
                        4'h0: math_mul_a[7:0]  <= cpu_wdata[7:0];
                        4'h1: math_mul_a[15:8] <= cpu_wdata[7:0];
                        4'h2: math_mul_b[7:0]  <= cpu_wdata[7:0];
                        4'h3: begin
                            math_mul_b[15:8] <= cpu_wdata[7:0];
                            math_mul_start <= 1'b1;
                        end
                        4'h8: math_div_dividend[7:0]   <= cpu_wdata[7:0];
                        4'h9: math_div_dividend[15:8]  <= cpu_wdata[7:0];
                        4'hA: math_div_dividend[23:16] <= cpu_wdata[7:0];
                        4'hB: math_div_dividend[31:24] <= cpu_wdata[7:0];
                        4'hC: math_div_divisor[7:0]    <= cpu_wdata[7:0];
                        4'hD: begin
                            math_div_divisor[15:8] <= cpu_wdata[7:0];
                            math_div_start <= 1'b1;
                        end
                        4'hF: begin
                            if (cpu_wdata[0])
                                math_cum_clear <= 1'b1;
                        end
                        default: ;
                    endcase
                end
            end
        end
    end

    // Math unit read (word-oriented for even addresses)
    always @(*) begin
        case (cpu_addr[3:1])
            3'd0: math_rd_data = math_mul_a;
            3'd1: math_rd_data = math_mul_b;
            3'd2: math_rd_data = math_mul_result[15:0];
            3'd3: math_rd_data = math_mul_result[31:16];
            3'd4: math_rd_data = math_div_quotient;
            3'd5: math_rd_data = math_div_remainder;
            3'd6: math_rd_data = math_cum_sum[15:0];
            3'd7: math_rd_data = {math_cum_sum[23:16],
                                  math_div_overflow, math_div_done, math_mul_done, 5'd0};
        endcase
    end

    // ==============================================================
    // Variable-Length Bit Processor
    // ==============================================================
    wire vlb_busy;

    varlen_bitproc u_vlb (
        .clk         (clk),
        .rst_n       (rst_n),
        .stream_addr (vlb_addr),
        .stream_data (vlb_rdata),
        .stream_re   (vlb_re),
        .stream_ready(vlb_ready),
        .reg_wr_en   (vlb_sel & io_write),
        .reg_addr    (cpu_addr[3:0]),
        .reg_wr_data (cpu_wdata[7:0]),
        .reg_rd_data (vlb_rd_data),
        .busy        (vlb_busy)
    );

    // ==============================================================
    // Bus Arbiter
    // ==============================================================
    wire cpu_ext_valid = cpu_valid & ~io_select;

    bus_arbiter u_bus (
        .clk        (clk),
        .rst_n      (rst_n),
        .cpu_addr   (cpu_addr),
        .cpu_wdata  (cpu_wdata),
        .cpu_rdata  (cpu_rdata),
        .cpu_we     (cpu_we),
        .cpu_re     (cpu_re),
        .cpu_valid  (cpu_ext_valid),
        .cpu_ready  (cpu_ready),
        .cpu_width  (cpu_width),
        .dma_addr   (dma_addr),
        .dma_wdata  (dma_wdata),
        .dma_rdata  (dma_rdata),
        .dma_we     (dma_we),
        .dma_re     (dma_re),
        .dma_valid  (dma_valid),
        .dma_ready  (dma_ready),
        .dma_active (dma_active),
        .vlb_addr   (vlb_addr),
        .vlb_rdata  (vlb_rdata),
        .vlb_re     (vlb_re),
        .vlb_ready  (vlb_ready),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_rdata  (mem_rdata),
        .mem_we     (mem_we),
        .mem_re     (mem_re),
        .mem_valid  (mem_valid),
        .mem_ready  (mem_ready),
        .mem_width  (mem_width)
    );

endmodule
