`include "cpu_defines.vh"

// Programmable interval timer
// Two 16-bit timers with auto-reload and interrupt generation
module timer (
    input  wire        clk,
    input  wire        rst_n,

    // Timer interrupt outputs
    output wire        timer0_irq,
    output wire        timer1_irq,

    // Register interface
    input  wire        reg_wr_en,
    input  wire        reg_rd_en,   // Active read strobe
    input  wire [3:0]  reg_addr,
    input  wire [7:0]  reg_wr_data,
    output reg  [7:0]  reg_rd_data
);

    // Timer 0
    reg [15:0] timer0_reload;
    reg [15:0] timer0_count;
    reg        timer0_enable;
    reg        timer0_irq_en;
    reg        timer0_fired;

    // Timer 1
    reg [15:0] timer1_reload;
    reg [15:0] timer1_count;
    reg        timer1_enable;
    reg        timer1_irq_en;
    reg        timer1_fired;

    // Prescaler
    reg [7:0]  prescaler_val;
    reg [7:0]  prescaler_count;
    wire       prescaler_tick = (prescaler_count == 8'd0);

    assign timer0_irq = timer0_fired & timer0_irq_en;
    assign timer1_irq = timer1_fired & timer1_irq_en;

    // Prescaler
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prescaler_count <= 8'd0;
        end else begin
            if (prescaler_count == 8'd0)
                prescaler_count <= prescaler_val;
            else
                prescaler_count <= prescaler_count - 8'd1;
        end
    end

    // Timer 0
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer0_count  <= 16'd0;
            timer0_reload <= 16'hFFFF;
            timer0_enable <= 1'b0;
            timer0_irq_en <= 1'b0;
            timer0_fired  <= 1'b0;
        end else begin
            if (timer0_enable && prescaler_tick) begin
                if (timer0_count == 16'd0) begin
                    timer0_count <= timer0_reload;
                    timer0_fired <= 1'b1;
                end else begin
                    timer0_count <= timer0_count - 16'd1;
                end
            end
            // Clear fired flag on explicit status read
            if (reg_rd_en && reg_addr == 4'd0)
                timer0_fired <= 1'b0;
        end
    end

    // Timer 1
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer1_count  <= 16'd0;
            timer1_reload <= 16'hFFFF;
            timer1_enable <= 1'b0;
            timer1_irq_en <= 1'b0;
            timer1_fired  <= 1'b0;
        end else begin
            if (timer1_enable && prescaler_tick) begin
                if (timer1_count == 16'd0) begin
                    timer1_count <= timer1_reload;
                    timer1_fired <= 1'b1;
                end else begin
                    timer1_count <= timer1_count - 16'd1;
                end
            end
            if (reg_rd_en && reg_addr == 4'd0)
                timer1_fired <= 1'b0;
        end
    end

    // Register writes
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prescaler_val <= 8'd0;
        end else if (reg_wr_en) begin
            case (reg_addr)
                4'd0: begin
                    timer0_enable <= reg_wr_data[0];
                    timer1_enable <= reg_wr_data[1];
                    timer0_irq_en <= reg_wr_data[4];
                    timer1_irq_en <= reg_wr_data[5];
                end
                4'd1: prescaler_val <= reg_wr_data;
                4'd2: timer0_reload[7:0]  <= reg_wr_data;
                4'd3: begin
                    timer0_reload[15:8] <= reg_wr_data;
                    timer0_count <= {reg_wr_data, timer0_reload[7:0]};
                end
                4'd4: timer1_reload[7:0]  <= reg_wr_data;
                4'd5: begin
                    timer1_reload[15:8] <= reg_wr_data;
                    timer1_count <= {reg_wr_data, timer1_reload[7:0]};
                end
                default: ;
            endcase
        end
    end

    // Register reads
    always @(*) begin
        case (reg_addr)
            4'd0: reg_rd_data = {2'b00, timer1_irq_en, timer0_irq_en,
                                  timer1_fired, timer0_fired,
                                  timer1_enable, timer0_enable};
            4'd1: reg_rd_data = prescaler_val;
            4'd2: reg_rd_data = timer0_count[7:0];
            4'd3: reg_rd_data = timer0_count[15:8];
            4'd4: reg_rd_data = timer1_count[7:0];
            4'd5: reg_rd_data = timer1_count[15:8];
            default: reg_rd_data = 8'h00;
        endcase
    end

endmodule
