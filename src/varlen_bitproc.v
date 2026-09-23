`include "cpu_defines.vh"

// Variable-length bit processing unit (SA1-inspired)
// Extracts variable-width fields from a byte stream
module varlen_bitproc (
    input  wire        clk,
    input  wire        rst_n,

    // Memory interface for stream reading
    output reg  [23:0] stream_addr,
    input  wire [7:0]  stream_data,
    output reg         stream_re,
    input  wire        stream_ready,

    // Register interface
    input  wire        reg_wr_en,
    input  wire [3:0]  reg_addr,
    input  wire [7:0]  reg_wr_data,
    output reg  [7:0]  reg_rd_data,

    output wire        busy
);

    // Stream base address
    reg [23:0] base_addr;
    // Current bit offset from base
    reg [23:0] bit_offset;
    // Bit field width (1-16)
    reg [4:0]  field_width;
    // Extracted value
    reg [15:0] field_value;
    // Auto-increment: advance bit_offset after each read
    reg        auto_advance;

    // Internal state
    reg [2:0]  state;
    reg [4:0]  bits_remaining;
    reg [4:0]  bits_collected;
    reg [15:0] collect_reg;
    reg [23:0] cur_byte_addr;
    reg [2:0]  cur_bit_pos;

    localparam VS_IDLE    = 3'd0;
    localparam VS_FETCH   = 3'd1;
    localparam VS_WAIT    = 3'd2;
    localparam VS_EXTRACT = 3'd3;
    localparam VS_DONE    = 3'd4;

    assign busy = (state != VS_IDLE);

    // Compute byte address and bit position from bit offset
    wire [23:0] byte_addr = base_addr + bit_offset[23:3];
    wire [2:0]  bit_pos   = bit_offset[2:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= VS_IDLE;
            base_addr      <= 24'd0;
            bit_offset     <= 24'd0;
            field_width    <= 5'd1;
            field_value    <= 16'd0;
            auto_advance   <= 1'b0;
            bits_remaining <= 5'd0;
            bits_collected <= 5'd0;
            collect_reg    <= 16'd0;
            stream_re      <= 1'b0;
            stream_addr    <= 24'd0;
            cur_byte_addr  <= 24'd0;
            cur_bit_pos    <= 3'd0;
        end else begin
            case (state)
                VS_IDLE: begin
                    stream_re <= 1'b0;
                    // Trigger extraction on write to control register
                end

                VS_FETCH: begin
                    stream_addr <= cur_byte_addr;
                    stream_re   <= 1'b1;
                    state       <= VS_WAIT;
                end

                VS_WAIT: begin
                    if (stream_ready) begin
                        stream_re <= 1'b0;
                        state     <= VS_EXTRACT;
                    end
                end

                VS_EXTRACT: begin
                    // Extract bits from the fetched byte
                    begin : extract_block
                        reg [3:0] avail;
                        reg [3:0] take;
                        avail = 4'd8 - {1'b0, cur_bit_pos};
                        take  = (bits_remaining > {1'b0, avail}) ? avail : {1'b0, bits_remaining[2:0]};

                        // Shift bits from stream_data into collect_reg (LSB first)
                        begin : shift_block
                            integer j;
                            for (j = 0; j < 8; j = j + 1) begin
                                if (j[3:0] < take) begin
                                    collect_reg[bits_collected + j[4:0]] <=
                                        stream_data[cur_bit_pos + j[2:0]];
                                end
                            end
                        end

                        bits_collected <= bits_collected + {1'b0, take};
                        bits_remaining <= bits_remaining - {1'b0, take};

                        if (bits_remaining <= {1'b0, take}) begin
                            state <= VS_DONE;
                        end else begin
                            cur_byte_addr <= cur_byte_addr + 24'd1;
                            cur_bit_pos   <= 3'd0;
                            state         <= VS_FETCH;
                        end
                    end
                end

                VS_DONE: begin
                    field_value <= collect_reg;
                    if (auto_advance)
                        bit_offset <= bit_offset + {19'd0, field_width};
                    state <= VS_IDLE;
                end
            endcase

            // Register writes
            if (reg_wr_en) begin
                case (reg_addr)
                    // Base address
                    4'd0: base_addr[7:0]   <= reg_wr_data;
                    4'd1: base_addr[15:8]  <= reg_wr_data;
                    4'd2: base_addr[23:16] <= reg_wr_data;
                    // Bit offset
                    4'd3: bit_offset[7:0]   <= reg_wr_data;
                    4'd4: bit_offset[15:8]  <= reg_wr_data;
                    4'd5: bit_offset[23:16] <= reg_wr_data;
                    // Field width + control
                    4'd6: begin
                        field_width  <= reg_wr_data[4:0];
                        auto_advance <= reg_wr_data[7];
                    end
                    // Trigger extraction
                    4'd7: begin
                        if (state == VS_IDLE && field_width != 5'd0) begin
                            bits_remaining <= field_width;
                            bits_collected <= 5'd0;
                            collect_reg    <= 16'd0;
                            cur_byte_addr  <= byte_addr;
                            cur_bit_pos    <= bit_pos;
                            state          <= VS_FETCH;
                        end
                    end
                    default: ;
                endcase
            end
        end
    end

    // Register reads
    always @(*) begin
        case (reg_addr)
            4'd0: reg_rd_data = base_addr[7:0];
            4'd1: reg_rd_data = base_addr[15:8];
            4'd2: reg_rd_data = base_addr[23:16];
            4'd3: reg_rd_data = bit_offset[7:0];
            4'd4: reg_rd_data = bit_offset[15:8];
            4'd5: reg_rd_data = bit_offset[23:16];
            4'd6: reg_rd_data = {auto_advance, 2'b00, field_width};
            4'd7: reg_rd_data = {7'd0, busy};
            4'd8: reg_rd_data = field_value[7:0];
            4'd9: reg_rd_data = field_value[15:8];
            default: reg_rd_data = 8'h00;
        endcase
    end

endmodule
