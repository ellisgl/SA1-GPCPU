`include "cpu_defines.vh"

module interrupt_ctrl (
    input  wire        clk,
    input  wire        rst_n,

    // External interrupt inputs
    input  wire        irq_n,       // Active low IRQ
    input  wire        nmi_n,       // Active low NMI (edge-sensitive)

    // Internal interrupt sources
    input  wire        timer_irq,   // Timer interrupt
    input  wire        dma_irq,     // DMA completion interrupt
    input  wire        math_irq,    // Math unit completion

    // CPU status
    input  wire        irq_disable, // P register I flag
    input  wire        cpu_brk,     // BRK instruction
    input  wire        cpu_cop,     // COP instruction
    input  wire        int_ack,     // CPU acknowledged interrupt

    // Interrupt output to CPU
    output reg         int_pending,
    output reg  [15:0] int_vector,
    output reg  [2:0]  int_type,    // For priority tracking

    // Interrupt enable/status registers (memory-mapped)
    input  wire        reg_wr_en,
    input  wire [1:0]  reg_addr,
    input  wire [7:0]  reg_wr_data,
    output reg  [7:0]  reg_rd_data
);

    localparam INT_NONE  = 3'd0;
    localparam INT_IRQ   = 3'd1;
    localparam INT_NMI   = 3'd2;
    localparam INT_BRK   = 3'd3;
    localparam INT_COP   = 3'd4;
    localparam INT_TIMER = 3'd5;
    localparam INT_DMA   = 3'd6;
    localparam INT_MATH  = 3'd7;

    reg [7:0] int_enable;    // Which internal sources are enabled
    reg [7:0] int_status;    // Which sources are active
    reg       nmi_prev;
    reg       nmi_pending;

    wire nmi_edge = nmi_prev & ~nmi_n;
    wire irq_active = ~irq_n | (timer_irq & int_enable[0]) |
                      (dma_irq & int_enable[1]) | (math_irq & int_enable[2]);

    // NMI edge detection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nmi_prev    <= 1'b1;
            nmi_pending <= 1'b0;
        end else begin
            nmi_prev <= nmi_n;
            if (nmi_edge)
                nmi_pending <= 1'b1;
            else if (int_ack && int_type == INT_NMI)
                nmi_pending <= 1'b0;
        end
    end

    // Interrupt status tracking
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_status <= 8'h00;
        end else begin
            int_status[0] <= timer_irq;
            int_status[1] <= dma_irq;
            int_status[2] <= math_irq;
            int_status[3] <= ~irq_n;
        end
    end

    // Priority encoder
    always @(*) begin
        int_pending = 1'b0;
        int_vector  = 16'h0000;
        int_type    = INT_NONE;

        if (cpu_brk) begin
            int_pending = 1'b1;
            int_vector  = `VEC_BRK;
            int_type    = INT_BRK;
        end else if (cpu_cop) begin
            int_pending = 1'b1;
            int_vector  = `VEC_COP;
            int_type    = INT_COP;
        end else if (nmi_pending) begin
            int_pending = 1'b1;
            int_vector  = `VEC_NMI;
            int_type    = INT_NMI;
        end else if (irq_active && !irq_disable) begin
            int_pending = 1'b1;
            int_vector  = `VEC_IRQ;
            int_type    = INT_IRQ;
        end
    end

    // Register interface
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_enable <= 8'h00;
        end else if (reg_wr_en) begin
            case (reg_addr)
                2'd0: int_enable <= reg_wr_data;
                default: ;
            endcase
        end
    end

    always @(*) begin
        case (reg_addr)
            2'd0: reg_rd_data = int_enable;
            2'd1: reg_rd_data = int_status;
            2'd2: reg_rd_data = {5'd0, int_type};
            default: reg_rd_data = 8'h00;
        endcase
    end

endmodule
