`include "cpu_defines.vh"

// Bus arbiter: CPU vs DMA vs VarLen bit processor
// DMA takes priority when active (CPU is halted)
module bus_arbiter (
    input  wire        clk,
    input  wire        rst_n,

    // CPU bus interface (16-bit data)
    input  wire [23:0] cpu_addr,
    input  wire [15:0] cpu_wdata,
    output reg  [15:0] cpu_rdata,
    input  wire        cpu_we,
    input  wire        cpu_re,
    input  wire        cpu_valid,
    output reg         cpu_ready,
    input  wire        cpu_width,

    // DMA bus interface (8-bit, byte-at-a-time)
    input  wire [23:0] dma_addr,
    input  wire [7:0]  dma_wdata,
    output reg  [7:0]  dma_rdata,
    input  wire        dma_we,
    input  wire        dma_re,
    input  wire        dma_valid,
    output reg         dma_ready,
    input  wire        dma_active,

    // VarLen bit processor interface (8-bit read-only)
    input  wire [23:0] vlb_addr,
    output reg  [7:0]  vlb_rdata,
    input  wire        vlb_re,
    output reg         vlb_ready,

    // External memory bus (16-bit data)
    output reg  [23:0] mem_addr,
    output reg  [15:0] mem_wdata,
    input  wire [15:0] mem_rdata,
    output reg         mem_we,
    output reg         mem_re,
    output reg         mem_valid,
    input  wire        mem_ready,
    output reg         mem_width
);

    localparam GRANT_CPU = 2'd0;
    localparam GRANT_DMA = 2'd1;
    localparam GRANT_VLB = 2'd2;

    reg [1:0] grant;

    // Priority: DMA > VarLen > CPU
    always @(*) begin
        if (dma_active && dma_valid)
            grant = GRANT_DMA;
        else if (vlb_re)
            grant = GRANT_VLB;
        else
            grant = GRANT_CPU;
    end

    // Mux
    always @(*) begin
        mem_addr   = 24'd0;
        mem_wdata  = 16'd0;
        mem_we     = 1'b0;
        mem_re     = 1'b0;
        mem_valid  = 1'b0;
        mem_width  = 1'b0;
        cpu_rdata  = 16'd0;
        cpu_ready  = 1'b0;
        dma_rdata  = 8'd0;
        dma_ready  = 1'b0;
        vlb_rdata  = 8'd0;
        vlb_ready  = 1'b0;

        case (grant)
            GRANT_CPU: begin
                mem_addr  = cpu_addr;
                mem_wdata = cpu_wdata;
                mem_we    = cpu_we;
                mem_re    = cpu_re;
                mem_valid = cpu_valid;
                mem_width = cpu_width;
                cpu_rdata = mem_rdata;
                cpu_ready = mem_ready;
            end

            GRANT_DMA: begin
                mem_addr      = dma_addr;
                mem_wdata     = {8'h00, dma_wdata};
                mem_we        = dma_we;
                mem_re        = dma_re;
                mem_valid     = dma_valid;
                mem_width     = 1'b0;
                dma_rdata     = mem_rdata[7:0];
                dma_ready     = mem_ready;
            end

            GRANT_VLB: begin
                mem_addr  = vlb_addr;
                mem_re    = vlb_re;
                mem_valid = vlb_re;
                mem_width = 1'b0;
                vlb_rdata = mem_rdata[7:0];
                vlb_ready = mem_ready;
            end
        endcase
    end

endmodule
