`include "cpu_defines.vh"
`timescale 1ns / 1ps

module tb_sa1_gpcpu_top;

    reg         clk, rst_n;
    wire [23:0] mem_addr;
    wire [15:0] mem_wdata;
    reg  [15:0] mem_rdata;
    wire        mem_we, mem_re, mem_valid;
    reg         mem_ready;
    wire        mem_width;
    reg         irq_n, nmi_n;
    wire [23:0] dbg_pc;
    wire [7:0]  dbg_opcode;
    wire [5:0]  dbg_state;

    sa1_gpcpu_top uut (
        .clk        (clk),
        .rst_n      (rst_n),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_rdata  (mem_rdata),
        .mem_we     (mem_we),
        .mem_re     (mem_re),
        .mem_valid  (mem_valid),
        .mem_ready  (mem_ready),
        .mem_width  (mem_width),
        .irq_n      (irq_n),
        .nmi_n      (nmi_n),
        .dbg_pc     (dbg_pc),
        .dbg_opcode (dbg_opcode),
        .dbg_state  (dbg_state)
    );

    always #5 clk = ~clk;

    // 64KB simulated memory (bank 0 only for simplicity)
    reg [7:0] ram [0:65535];

    always @(posedge clk) begin
        mem_ready <= 1'b0;
        if (mem_valid) begin
            if (mem_re) begin
                if (mem_width)
                    mem_rdata <= {ram[mem_addr[15:0] + 1], ram[mem_addr[15:0]]};
                else
                    mem_rdata <= {8'h00, ram[mem_addr[15:0]]};
                mem_ready <= 1'b1;
            end else if (mem_we) begin
                ram[mem_addr[15:0]] <= mem_wdata[7:0];
                if (mem_width)
                    ram[mem_addr[15:0] + 1] <= mem_wdata[15:8];
                mem_ready <= 1'b1;
            end
        end
    end

    // ============================================================
    // Helper tasks
    // ============================================================
    integer cycle_count;
    integer pass_count, fail_count;
    integer max_cycles;

    task reset_system;
        integer i;
        begin
            rst_n = 0;
            irq_n = 1;
            nmi_n = 1;
            for (i = 0; i < 65536; i = i + 1) ram[i] = 8'h00;
            ram[16'hFFFC] = 8'h00;
            ram[16'hFFFD] = 8'h80;
            repeat(4) @(posedge clk);
            rst_n = 1;
        end
    endtask

    task run_until_stp;
        input integer limit;
        begin
            cycle_count = 0;
            while (dbg_state != `S_STP && cycle_count < limit) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
            end
        end
    endtask

    task check_ram16;
        input [15:0] addr;
        input [15:0] expected;
        input [255:0] label;
        reg [15:0] actual;
        begin
            actual = {ram[addr+1], ram[addr]};
            if (actual === expected) begin
                $display("PASS %0s: RAM[%04X] = %04X", label, addr, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL %0s: RAM[%04X] = %04X (expected %04X)", label, addr, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_ram8;
        input [15:0] addr;
        input [7:0] expected;
        input [255:0] label;
        begin
            if (ram[addr] === expected) begin
                $display("PASS %0s: RAM[%04X] = %02X", label, addr, ram[addr]);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL %0s: RAM[%04X] = %02X (expected %02X)", label, addr, ram[addr], expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ============================================================
    // Tests
    // ============================================================
    initial begin
        clk = 0;
        rst_n = 0;
        mem_rdata = 16'h0000;
        mem_ready = 0;
        irq_n = 1;
        nmi_n = 1;
        pass_count = 0;
        fail_count = 0;
        max_cycles = 500;

        // ============================================================
        // Test 1: Basic CPU through full system (LDA/STA)
        // ============================================================
        $display("\n=== Test 1: CPU through bus arbiter (LDA/STA) ===");
        reset_system;
        ram[16'h8000] = 8'hA9; // LDA #$34
        ram[16'h8001] = 8'h34;
        ram[16'h8002] = 8'h12;
        ram[16'h8003] = 8'h8D; // STA $0200
        ram[16'h8004] = 8'h00;
        ram[16'h8005] = 8'h02;
        ram[16'h8006] = 8'hDB; // STP
        run_until_stp(max_cycles);
        check_ram16(16'h0200, 16'h1234, "LDA/STA through system");

        // ============================================================
        // Test 2: JSR/RTS through full system
        // ============================================================
        $display("\n=== Test 2: JSR/RTS through full system ===");
        reset_system;
        // Main: JSR $8010, STP
        ram[16'h8000] = 8'h20; // JSR $8010
        ram[16'h8001] = 8'h10;
        ram[16'h8002] = 8'h80;
        ram[16'h8003] = 8'h8D; // STA $0300
        ram[16'h8004] = 8'h00;
        ram[16'h8005] = 8'h03;
        ram[16'h8006] = 8'hDB; // STP
        // Subroutine at $8010: LDA #$42, RTS
        ram[16'h8010] = 8'hA9; // LDA #$0042
        ram[16'h8011] = 8'h42;
        ram[16'h8012] = 8'h00;
        ram[16'h8013] = 8'h60; // RTS
        run_until_stp(max_cycles);
        check_ram16(16'h0300, 16'h0042, "JSR/RTS through system");

        // ============================================================
        // Test 3: Math unit - multiply via I/O registers
        // ============================================================
        $display("\n=== Test 3: Math unit multiply (I/O mapped) ===");
        reset_system;
        // Write multiplicand = $000A (10) to $4260-$4261
        ram[16'h8000] = 8'hA9; // LDA #$000A
        ram[16'h8001] = 8'h0A;
        ram[16'h8002] = 8'h00;
        ram[16'h8003] = 8'h8D; // STA $4260 (mul_a low)
        ram[16'h8004] = 8'h60;
        ram[16'h8005] = 8'h42;
        ram[16'h8006] = 8'hA9; // LDA #$0000
        ram[16'h8007] = 8'h00;
        ram[16'h8008] = 8'h00;
        ram[16'h8009] = 8'h8D; // STA $4261 (mul_a high - actually byte store)
        ram[16'h800A] = 8'h61;
        ram[16'h800B] = 8'h42;
        // Write multiplier = $0014 (20) to $4262-$4263 (triggers multiply)
        ram[16'h800C] = 8'hA9; // LDA #$0014
        ram[16'h800D] = 8'h14;
        ram[16'h800E] = 8'h00;
        ram[16'h800F] = 8'h8D; // STA $4262 (mul_b low)
        ram[16'h8010] = 8'h62;
        ram[16'h8011] = 8'h42;
        ram[16'h8012] = 8'hA9; // LDA #$0000
        ram[16'h8013] = 8'h00;
        ram[16'h8014] = 8'h00;
        ram[16'h8015] = 8'h8D; // STA $4263 (mul_b high - triggers multiply)
        ram[16'h8016] = 8'h63;
        ram[16'h8017] = 8'h42;
        // Wait a few cycles then read result from $4264-$4265
        ram[16'h8018] = 8'hEA; // NOP (wait for multiply to finish)
        ram[16'h8019] = 8'hEA; // NOP
        ram[16'h801A] = 8'hEA; // NOP
        ram[16'h801B] = 8'hEA; // NOP
        ram[16'h801C] = 8'hAD; // LDA $4264 (result low)
        ram[16'h801D] = 8'h64;
        ram[16'h801E] = 8'h42;
        ram[16'h801F] = 8'h8D; // STA $0310
        ram[16'h8020] = 8'h10;
        ram[16'h8021] = 8'h03;
        ram[16'h8022] = 8'hDB; // STP
        run_until_stp(max_cycles);
        // 10 * 20 = 200 = $00C8
        check_ram16(16'h0310, 16'h00C8, "Math multiply 10*20");

        // ============================================================
        // Test 4: Loop with memory operations through system
        // ============================================================
        $display("\n=== Test 4: Loop through full system ===");
        reset_system;
        // LDX #$03, loop: DEX, BNE loop, STX $0320, STP
        ram[16'h8000] = 8'hA2; // LDX #$0003
        ram[16'h8001] = 8'h03;
        ram[16'h8002] = 8'h00;
        ram[16'h8003] = 8'hCA; // DEX
        ram[16'h8004] = 8'hD0; // BNE -3 (back to DEX)
        ram[16'h8005] = 8'hFD; // -3 relative
        ram[16'h8006] = 8'h8E; // STX $0320
        ram[16'h8007] = 8'h20;
        ram[16'h8008] = 8'h03;
        ram[16'h8009] = 8'hDB; // STP
        run_until_stp(max_cycles);
        check_ram16(16'h0320, 16'h0000, "Loop DEX to 0 through system");

        // ============================================================
        // Test 5: INC/DEC memory through bus arbiter
        // ============================================================
        $display("\n=== Test 5: INC/DEC memory (RMW) through system ===");
        reset_system;
        // Store $00FF to DP $10, INC it, load result
        ram[16'h8000] = 8'hA9; // LDA #$00FF
        ram[16'h8001] = 8'hFF;
        ram[16'h8002] = 8'h00;
        ram[16'h8003] = 8'h85; // STA dp $10
        ram[16'h8004] = 8'h10;
        ram[16'h8005] = 8'hE6; // INC dp $10
        ram[16'h8006] = 8'h10;
        ram[16'h8007] = 8'hA5; // LDA dp $10
        ram[16'h8008] = 8'h10;
        ram[16'h8009] = 8'h8D; // STA $0330
        ram[16'h800A] = 8'h30;
        ram[16'h800B] = 8'h03;
        ram[16'h800C] = 8'hDB; // STP
        run_until_stp(max_cycles);
        check_ram16(16'h0330, 16'h0100, "INC dp $FF->$0100 through system");

        // ============================================================
        // Test 6: CMP + Branch through full system
        // ============================================================
        $display("\n=== Test 6: CMP + Branch through system ===");
        reset_system;
        ram[16'h8000] = 8'hA9; // LDA #$0010
        ram[16'h8001] = 8'h10;
        ram[16'h8002] = 8'h00;
        ram[16'h8003] = 8'hC9; // CMP #$0010
        ram[16'h8004] = 8'h10;
        ram[16'h8005] = 8'h00;
        ram[16'h8006] = 8'hF0; // BEQ +3
        ram[16'h8007] = 8'h03;
        ram[16'h8008] = 8'hA9; // LDA #$FFFF (should be skipped)
        ram[16'h8009] = 8'hFF;
        ram[16'h800A] = 8'hFF;
        ram[16'h800B] = 8'h8D; // STA $0340
        ram[16'h800C] = 8'h40;
        ram[16'h800D] = 8'h03;
        ram[16'h800E] = 8'hDB; // STP
        run_until_stp(max_cycles);
        check_ram16(16'h0340, 16'h0010, "CMP equal BEQ through system");

        // ============================================================
        // Summary
        // ============================================================
        $display("\n========================================");
        $display("Top-Level Tests: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================");
        $finish;
    end

endmodule
