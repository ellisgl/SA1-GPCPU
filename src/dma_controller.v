`include "cpu_defines.vh"

// Multi-channel DMA controller (5A22/SA1-inspired)
// 4 channels, configurable transfer direction and size
module dma_controller (
    input  wire        clk,
    input  wire        rst_n,

    // Bus master interface
    output reg  [23:0] dma_addr,
    output reg  [7:0]  dma_wdata,
    input  wire [7:0]  dma_rdata,
    output reg         dma_we,
    output reg         dma_re,
    output reg         dma_valid,
    input  wire        dma_ready,

    // Control
    output wire        dma_active,
    output wire        dma_irq,

    // Register interface
    input  wire        reg_wr_en,
    input  wire [5:0]  reg_addr,
    input  wire [7:0]  reg_wr_data,
    output reg  [7:0]  reg_rd_data
);

    localparam NUM_CH = 4;

    // Per-channel registers
    reg [23:0] ch_src_addr   [0:NUM_CH-1];
    reg [23:0] ch_dst_addr   [0:NUM_CH-1];
    reg [15:0] ch_count      [0:NUM_CH-1];
    reg [7:0]  ch_control    [0:NUM_CH-1]; // [0]=enable, [1]=dir, [2]=src_inc, [3]=dst_inc, [4]=src_dec, [5]=dst_dec
    reg [NUM_CH-1:0] ch_done;
    reg [NUM_CH-1:0] ch_irq_en;

    // Transfer state
    reg [1:0]  active_ch;
    reg [1:0]  dma_state;
    reg [15:0] xfer_remain;
    reg [23:0] cur_src, cur_dst;
    reg [7:0]  xfer_data;

    localparam DS_IDLE  = 2'd0;
    localparam DS_READ  = 2'd1;
    localparam DS_WRITE = 2'd2;
    localparam DS_NEXT  = 2'd3;

    wire [NUM_CH-1:0] ch_enable = {ch_control[3][0], ch_control[2][0],
                                    ch_control[1][0], ch_control[0][0]};
    assign dma_active = (dma_state != DS_IDLE);
    assign dma_irq    = |(ch_done & ch_irq_en);

    // Priority encoder: find lowest enabled channel
    reg [1:0] next_ch;
    reg       has_pending;
    always @(*) begin
        has_pending = 1'b0;
        next_ch = 2'd0;
        if (ch_enable[0] && !ch_done[0])      begin next_ch = 2'd0; has_pending = 1'b1; end
        else if (ch_enable[1] && !ch_done[1]) begin next_ch = 2'd1; has_pending = 1'b1; end
        else if (ch_enable[2] && !ch_done[2]) begin next_ch = 2'd2; has_pending = 1'b1; end
        else if (ch_enable[3] && !ch_done[3]) begin next_ch = 2'd3; has_pending = 1'b1; end
    end

    // DMA state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_state  <= DS_IDLE;
            dma_valid  <= 1'b0;
            dma_we     <= 1'b0;
            dma_re     <= 1'b0;
            dma_addr   <= 24'd0;
            dma_wdata  <= 8'd0;
            xfer_remain <= 16'd0;
            cur_src    <= 24'd0;
            cur_dst    <= 24'd0;
            active_ch  <= 2'd0;
            ch_done    <= {NUM_CH{1'b0}};
        end else begin
            case (dma_state)
                DS_IDLE: begin
                    dma_valid <= 1'b0;
                    if (has_pending) begin
                        active_ch   <= next_ch;
                        cur_src     <= ch_src_addr[next_ch];
                        cur_dst     <= ch_dst_addr[next_ch];
                        xfer_remain <= ch_count[next_ch];
                        dma_state   <= DS_READ;
                    end
                end

                DS_READ: begin
                    dma_addr  <= cur_src;
                    dma_re    <= 1'b1;
                    dma_we    <= 1'b0;
                    dma_valid <= 1'b1;
                    if (dma_ready) begin
                        xfer_data <= dma_rdata;
                        dma_valid <= 1'b0;
                        dma_re    <= 1'b0;
                        dma_state <= DS_WRITE;
                    end
                end

                DS_WRITE: begin
                    dma_addr  <= cur_dst;
                    dma_wdata <= xfer_data;
                    dma_we    <= 1'b1;
                    dma_re    <= 1'b0;
                    dma_valid <= 1'b1;
                    if (dma_ready) begin
                        dma_valid <= 1'b0;
                        dma_we    <= 1'b0;
                        dma_state <= DS_NEXT;
                    end
                end

                DS_NEXT: begin
                    // Update source address
                    if (ch_control[active_ch][2])
                        cur_src <= cur_src + 24'd1;
                    else if (ch_control[active_ch][4])
                        cur_src <= cur_src - 24'd1;

                    // Update destination address
                    if (ch_control[active_ch][3])
                        cur_dst <= cur_dst + 24'd1;
                    else if (ch_control[active_ch][5])
                        cur_dst <= cur_dst - 24'd1;

                    if (xfer_remain == 16'd0) begin
                        ch_done[active_ch] <= 1'b1;
                        dma_state <= DS_IDLE;
                    end else begin
                        xfer_remain <= xfer_remain - 16'd1;
                        dma_state <= DS_READ;
                    end
                end
            endcase

            // Clear done flags when channel is re-enabled
            if (reg_wr_en && reg_addr[5:4] == 2'b00 && reg_addr[3:0] == 4'd6) begin
                if (reg_wr_data[0])
                    ch_done[reg_addr[3:2]] <= 1'b0;
            end
        end
    end

    // Register write interface
    // Layout: 16 bytes per channel (0x00-0x0F ch0, 0x10-0x1F ch1, etc.)
    wire [1:0] ch_sel = reg_addr[5:4];
    wire [3:0] ch_reg = reg_addr[3:0];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_CH; i = i + 1) begin
                ch_src_addr[i] <= 24'd0;
                ch_dst_addr[i] <= 24'd0;
                ch_count[i]    <= 16'd0;
                ch_control[i]  <= 8'd0;
            end
            ch_irq_en <= {NUM_CH{1'b0}};
        end else if (reg_wr_en) begin
            case (ch_reg)
                4'd0: ch_src_addr[ch_sel][7:0]   <= reg_wr_data;
                4'd1: ch_src_addr[ch_sel][15:8]  <= reg_wr_data;
                4'd2: ch_src_addr[ch_sel][23:16] <= reg_wr_data;
                4'd3: ch_dst_addr[ch_sel][7:0]   <= reg_wr_data;
                4'd4: ch_dst_addr[ch_sel][15:8]  <= reg_wr_data;
                4'd5: ch_dst_addr[ch_sel][23:16] <= reg_wr_data;
                4'd6: ch_control[ch_sel] <= reg_wr_data;
                4'd7: ch_count[ch_sel][7:0]  <= reg_wr_data;
                4'd8: ch_count[ch_sel][15:8] <= reg_wr_data;
                4'd9: ch_irq_en[ch_sel] <= reg_wr_data[0];
                default: ;
            endcase
        end
    end

    // Register read interface
    always @(*) begin
        case (ch_reg)
            4'd0: reg_rd_data = ch_src_addr[ch_sel][7:0];
            4'd1: reg_rd_data = ch_src_addr[ch_sel][15:8];
            4'd2: reg_rd_data = ch_src_addr[ch_sel][23:16];
            4'd3: reg_rd_data = ch_dst_addr[ch_sel][7:0];
            4'd4: reg_rd_data = ch_dst_addr[ch_sel][15:8];
            4'd5: reg_rd_data = ch_dst_addr[ch_sel][23:16];
            4'd6: reg_rd_data = ch_control[ch_sel];
            4'd7: reg_rd_data = ch_count[ch_sel][7:0];
            4'd8: reg_rd_data = ch_count[ch_sel][15:8];
            4'd9: reg_rd_data = {7'd0, ch_irq_en[ch_sel]};
            4'd10: reg_rd_data = {7'd0, ch_done[ch_sel]};
            default: reg_rd_data = 8'h00;
        endcase
    end

endmodule
