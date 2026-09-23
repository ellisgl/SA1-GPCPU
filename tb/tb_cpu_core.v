`include "cpu_defines.vh"
`timescale 1ns / 1ps

module tb_cpu_core;

    reg         clk, rst_n;

    // CPU bus (16-bit data)
    wire [23:0] bus_addr;
    wire [15:0] bus_wdata;
    reg  [15:0] bus_rdata;
    wire        bus_we, bus_re, bus_valid;
    reg         bus_ready;
    wire        bus_width;

    // Interrupts
    reg         int_pending;
    reg  [15:0] int_vector;
    wire        int_ack;
    wire        cpu_brk, cpu_cop;

    // Debug
    wire [23:0] dbg_pc;
    wire [7:0]  dbg_opcode;
    wire [5:0]  dbg_state;
    wire [7:0]  p_out;

    cpu_core uut (
        .clk        (clk),
        .rst_n      (rst_n),
        .bus_addr   (bus_addr),
        .bus_wdata  (bus_wdata),
        .bus_rdata  (bus_rdata),
        .bus_we     (bus_we),
        .bus_re     (bus_re),
        .bus_valid  (bus_valid),
        .bus_ready  (bus_ready),
        .bus_width  (bus_width),
        .int_pending(int_pending),
        .int_vector (int_vector),
        .int_ack    (int_ack),
        .cpu_brk    (cpu_brk),
        .cpu_cop    (cpu_cop),
        .dma_active (1'b0),
        .p_out      (p_out),
        .dbg_pc     (dbg_pc),
        .dbg_opcode (dbg_opcode),
        .dbg_state  (dbg_state)
    );

    always #5 clk = ~clk;

    // ==============================================================
    // Simulated 64KB RAM (bank 0 only for tests)
    // ==============================================================
    reg [7:0] ram [0:65535];

    // Single-cycle memory with byte/word support
    always @(posedge clk) begin
        bus_ready <= 1'b0;
        if (bus_valid) begin
            if (bus_re) begin
                if (bus_width)
                    bus_rdata <= {ram[bus_addr[15:0] + 1], ram[bus_addr[15:0]]};
                else
                    bus_rdata <= {8'h00, ram[bus_addr[15:0]]};
                bus_ready <= 1'b1;
            end else if (bus_we) begin
                ram[bus_addr[15:0]] <= bus_wdata[7:0];
                if (bus_width)
                    ram[bus_addr[15:0] + 1] <= bus_wdata[15:8];
                bus_ready <= 1'b1;
            end
        end
    end

    integer pass_count = 0;
    integer fail_count = 0;
    integer i;
    integer cycle_count;
    integer max_cycles;

    // Wait for CPU to reach a specific PC (with timeout)
    task wait_for_pc;
        input [15:0] target_pc;
        input integer timeout;
        begin
            cycle_count = 0;
            while (dbg_pc[15:0] !== target_pc && cycle_count < timeout) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
            end
            if (cycle_count >= timeout)
                $display("  WARNING: Timeout waiting for PC=%04X (at PC=%04X state=%0d)",
                         target_pc, dbg_pc[15:0], dbg_state);
        end
    endtask

    // Wait for CPU to execute N instructions (reach FETCH_OP N times)
    task run_instructions;
        input integer count;
        integer inst;
        begin
            for (inst = 0; inst < count; inst = inst + 1) begin
                // Wait for a FETCH_OP state
                cycle_count = 0;
                @(posedge clk);
                while (dbg_state !== `S_FETCH_OP && cycle_count < 200) begin
                    @(posedge clk);
                    cycle_count = cycle_count + 1;
                end
                // Then wait for it to leave FETCH_OP (instruction fetched)
                while (dbg_state === `S_FETCH_OP && cycle_count < 200) begin
                    @(posedge clk);
                    cycle_count = cycle_count + 1;
                end
            end
        end
    endtask

    // Run until STP instruction (opcode DB) or timeout
    task run_until_stp;
        input integer timeout;
        begin
            cycle_count = 0;
            while (dbg_state !== `S_STP && cycle_count < timeout) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
            end
            if (cycle_count >= timeout)
                $display("  WARNING: Timeout waiting for STP (at PC=%04X state=%0d)",
                         dbg_pc[15:0], dbg_state);
        end
    endtask

    task check_ram;
        input [15:0] addr;
        input [7:0]  expected;
        input [127:0] name;
        begin
            if (ram[addr] !== expected) begin
                $display("FAIL %0s: RAM[%04X] = %02X, expected %02X",
                         name, addr, ram[addr], expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS %0s: RAM[%04X] = %02X", name, addr, ram[addr]);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task check_ram16;
        input [15:0] addr;
        input [15:0] expected;
        input [127:0] name;
        begin
            if ({ram[addr+1], ram[addr]} !== expected) begin
                $display("FAIL %0s: RAM[%04X] = %04X, expected %04X",
                         name, addr, {ram[addr+1], ram[addr]}, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS %0s: RAM[%04X] = %04X", name, addr, {ram[addr+1], ram[addr]});
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        // $dumpfile("tb_cpu_core.vcd");
        // $dumpvars(0, tb_cpu_core);

        clk = 0; rst_n = 0;
        bus_rdata = 16'h0000; bus_ready = 1'b0;
        int_pending = 1'b0; int_vector = 16'h0000;
        max_cycles = 2000;

        // Clear RAM
        for (i = 0; i < 65536; i = i + 1) ram[i] = 8'h00;

        // ============================================================
        // Test 1: LDA immediate + STA absolute
        // Program at $8000:
        //   LDA #$1234    ; A9 34 12
        //   STA $0200     ; 8D 00 02
        //   STP           ; DB
        // ============================================================
        $display("=== Test 1: LDA #imm + STA abs ===");

        ram[16'hFFFC] = 8'h00; // Reset vector low
        ram[16'hFFFD] = 8'h80; // Reset vector high -> $8000

        ram[16'h8000] = 8'hA9; // LDA #imm
        ram[16'h8001] = 8'h34; // Low byte
        ram[16'h8002] = 8'h12; // High byte
        ram[16'h8003] = 8'h8D; // STA abs
        ram[16'h8004] = 8'h00; // Address low
        ram[16'h8005] = 8'h02; // Address high
        ram[16'h8006] = 8'hDB; // STP

        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        run_until_stp(max_cycles);
        check_ram16(16'h0200, 16'h1234, "LDA/STA result");

        // ============================================================
        // Test 2: ADC - Addition
        // Program:
        //   CLC           ; 18
        //   LDA #$0010    ; A9 10 00
        //   ADC #$0020    ; 69 20 00
        //   STA $0210     ; 8D 10 02
        //   STP           ; DB
        // ============================================================
        $display("");
        $display("=== Test 2: ADC Addition ===");

        for (i = 16'h8000; i < 16'h8020; i = i + 1) ram[i] = 8'h00;

        ram[16'h8000] = 8'h18; // CLC
        ram[16'h8001] = 8'hA9; // LDA #imm
        ram[16'h8002] = 8'h10;
        ram[16'h8003] = 8'h00;
        ram[16'h8004] = 8'h69; // ADC #imm
        ram[16'h8005] = 8'h20;
        ram[16'h8006] = 8'h00;
        ram[16'h8007] = 8'h8D; // STA abs
        ram[16'h8008] = 8'h10;
        ram[16'h8009] = 8'h02;
        ram[16'h800A] = 8'hDB; // STP

        ram[16'hFFFC] = 8'h00; ram[16'hFFFD] = 8'h80;
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        run_until_stp(max_cycles);
        check_ram16(16'h0210, 16'h0030, "ADC $10+$20");

        // ============================================================
        // Test 3: SBC - Subtraction
        // Program:
        //   SEC           ; 38
        //   LDA #$0050    ; A9 50 00
        //   SBC #$0020    ; E9 20 00
        //   STA $0220     ; 8D 20 02
        //   STP           ; DB
        // ============================================================
        $display("");
        $display("=== Test 3: SBC Subtraction ===");

        for (i = 16'h8000; i < 16'h8020; i = i + 1) ram[i] = 8'h00;

        ram[16'h8000] = 8'h38; // SEC
        ram[16'h8001] = 8'hA9; // LDA #
        ram[16'h8002] = 8'h50;
        ram[16'h8003] = 8'h00;
        ram[16'h8004] = 8'hE9; // SBC #
        ram[16'h8005] = 8'h20;
        ram[16'h8006] = 8'h00;
        ram[16'h8007] = 8'h8D; // STA abs
        ram[16'h8008] = 8'h20;
        ram[16'h8009] = 8'h02;
        ram[16'h800A] = 8'hDB; // STP

        ram[16'hFFFC] = 8'h00; ram[16'hFFFD] = 8'h80;
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        run_until_stp(max_cycles);
        check_ram16(16'h0220, 16'h0030, "SBC $50-$20");

        // ============================================================
        // Test 4: LDX, LDY, INX, DEY, transfers
        // Program:
        //   LDX #$000A    ; A2 0A 00
        //   LDY #$0005    ; A0 05 00
        //   INX           ; E8
        //   DEY           ; 88
        //   TXA           ; 8A
        //   STA $0230     ; 8D 30 02    -> should be $000B (X after INX)
        //   TYA           ; 98
        //   STA $0232     ; 8D 32 02    -> should be $0004 (Y after DEY)
        //   STP           ; DB
        // ============================================================
        $display("");
        $display("=== Test 4: LDX/LDY/INX/DEY/TXA/TYA ===");

        for (i = 16'h8000; i < 16'h8020; i = i + 1) ram[i] = 8'h00;

        ram[16'h8000] = 8'hA2; // LDX #
        ram[16'h8001] = 8'h0A;
        ram[16'h8002] = 8'h00;
        ram[16'h8003] = 8'hA0; // LDY #
        ram[16'h8004] = 8'h05;
        ram[16'h8005] = 8'h00;
        ram[16'h8006] = 8'hE8; // INX
        ram[16'h8007] = 8'h88; // DEY
        ram[16'h8008] = 8'h8A; // TXA
        ram[16'h8009] = 8'h8D; // STA abs
        ram[16'h800A] = 8'h30;
        ram[16'h800B] = 8'h02;
        ram[16'h800C] = 8'h98; // TYA
        ram[16'h800D] = 8'h8D; // STA abs
        ram[16'h800E] = 8'h32;
        ram[16'h800F] = 8'h02;
        ram[16'h8010] = 8'hDB; // STP

        ram[16'hFFFC] = 8'h00; ram[16'hFFFD] = 8'h80;
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        run_until_stp(max_cycles);
        check_ram16(16'h0230, 16'h000B, "TXA (X=A+1=B)");
        check_ram16(16'h0232, 16'h0004, "TYA (Y=5-1=4)");

        // ============================================================
        // Test 5: Branch BEQ/BNE
        // Program:
        //   LDA #$0000    ; A9 00 00
        //   BEQ +3        ; F0 03       -> skip next instruction
        //   LDA #$DEAD    ; A9 AD DE    (should be skipped)
        //   STA $0240     ; 8D 40 02    -> should be $0000
        //   LDA #$0001    ; A9 01 00
        //   BNE +3        ; D0 03       -> skip next instruction
        //   LDA #$DEAD    ; A9 AD DE    (should be skipped)
        //   STA $0242     ; 8D 42 02    -> should be $0001
        //   STP           ; DB
        // ============================================================
        $display("");
        $display("=== Test 5: BEQ/BNE Branching ===");

        for (i = 16'h8000; i < 16'h8030; i = i + 1) ram[i] = 8'h00;

        ram[16'h8000] = 8'hA9; // LDA #$0000
        ram[16'h8001] = 8'h00;
        ram[16'h8002] = 8'h00;
        ram[16'h8003] = 8'hF0; // BEQ +3
        ram[16'h8004] = 8'h03;
        ram[16'h8005] = 8'hA9; // LDA #$DEAD (skipped)
        ram[16'h8006] = 8'hAD;
        ram[16'h8007] = 8'hDE;
        ram[16'h8008] = 8'h8D; // STA $0240
        ram[16'h8009] = 8'h40;
        ram[16'h800A] = 8'h02;
        ram[16'h800B] = 8'hA9; // LDA #$0001
        ram[16'h800C] = 8'h01;
        ram[16'h800D] = 8'h00;
        ram[16'h800E] = 8'hD0; // BNE +3
        ram[16'h800F] = 8'h03;
        ram[16'h8010] = 8'hA9; // LDA #$DEAD (skipped)
        ram[16'h8011] = 8'hAD;
        ram[16'h8012] = 8'hDE;
        ram[16'h8013] = 8'h8D; // STA $0242
        ram[16'h8014] = 8'h42;
        ram[16'h8015] = 8'h02;
        ram[16'h8016] = 8'hDB; // STP

        ram[16'hFFFC] = 8'h00; ram[16'hFFFD] = 8'h80;
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        run_until_stp(max_cycles);
        check_ram16(16'h0240, 16'h0000, "BEQ skipped LDA");
        check_ram16(16'h0242, 16'h0001, "BNE skipped LDA");

        // ============================================================
        // Test 6: PHA / PLA (stack push/pull)
        // Program:
        //   LDA #$ABCD    ; A9 CD AB
        //   PHA           ; 48
        //   LDA #$0000    ; A9 00 00
        //   PLA           ; 68
        //   STA $0250     ; 8D 50 02   -> should be $ABCD
        //   STP           ; DB
        // ============================================================
        $display("");
        $display("=== Test 6: PHA/PLA Stack ===");

        for (i = 16'h8000; i < 16'h8020; i = i + 1) ram[i] = 8'h00;

        ram[16'h8000] = 8'hA9; // LDA #$ABCD
        ram[16'h8001] = 8'hCD;
        ram[16'h8002] = 8'hAB;
        ram[16'h8003] = 8'h48; // PHA
        ram[16'h8004] = 8'hA9; // LDA #$0000
        ram[16'h8005] = 8'h00;
        ram[16'h8006] = 8'h00;
        ram[16'h8007] = 8'h68; // PLA
        ram[16'h8008] = 8'h8D; // STA $0250
        ram[16'h8009] = 8'h50;
        ram[16'h800A] = 8'h02;
        ram[16'h800B] = 8'hDB; // STP

        ram[16'hFFFC] = 8'h00; ram[16'hFFFD] = 8'h80;
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        run_until_stp(max_cycles);
        check_ram16(16'h0250, 16'hABCD, "PHA/PLA roundtrip");

        // ============================================================
        // Test 7: JSR / RTS
        // Program at $8000:
        //   JSR $8010     ; 20 10 80
        //   STA $0260     ; 8D 60 02   -> should be $0042 from subroutine
        //   STP           ; DB
        //
        // Subroutine at $8010:
        //   LDA #$0042    ; A9 42 00
        //   RTS           ; 60
        // ============================================================
        $display("");
        $display("=== Test 7: JSR/RTS ===");

        for (i = 16'h8000; i < 16'h8020; i = i + 1) ram[i] = 8'h00;

        ram[16'h8000] = 8'h20; // JSR $8010
        ram[16'h8001] = 8'h10;
        ram[16'h8002] = 8'h80;
        ram[16'h8003] = 8'h8D; // STA $0260
        ram[16'h8004] = 8'h60;
        ram[16'h8005] = 8'h02;
        ram[16'h8006] = 8'hDB; // STP

        ram[16'h8010] = 8'hA9; // LDA #$0042
        ram[16'h8011] = 8'h42;
        ram[16'h8012] = 8'h00;
        ram[16'h8013] = 8'h60; // RTS

        ram[16'hFFFC] = 8'h00; ram[16'hFFFD] = 8'h80;
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        run_until_stp(max_cycles);
        check_ram16(16'h0260, 16'h0042, "JSR/RTS subroutine");

        // ============================================================
        // Test 8: Logic operations (AND, ORA, EOR)
        // Program:
        //   LDA #$FF0F    ; A9 0F FF
        //   AND #$0FF0    ; 29 F0 0F
        //   STA $0270     ; 8D 70 02    -> $0F00
        //   LDA #$F000    ; A9 00 F0
        //   ORA #$000F    ; 09 0F 00
        //   STA $0272     ; 8D 72 02    -> $F00F
        //   LDA #$AAAA    ; A9 AA AA
        //   EOR #$FFFF    ; 49 FF FF
        //   STA $0274     ; 8D 74 02    -> $5555
        //   STP           ; DB
        // ============================================================
        $display("");
        $display("=== Test 8: AND/ORA/EOR ===");

        for (i = 16'h8000; i < 16'h8030; i = i + 1) ram[i] = 8'h00;

        ram[16'h8000] = 8'hA9; ram[16'h8001] = 8'h0F; ram[16'h8002] = 8'hFF;
        ram[16'h8003] = 8'h29; ram[16'h8004] = 8'hF0; ram[16'h8005] = 8'h0F;
        ram[16'h8006] = 8'h8D; ram[16'h8007] = 8'h70; ram[16'h8008] = 8'h02;
        ram[16'h8009] = 8'hA9; ram[16'h800A] = 8'h00; ram[16'h800B] = 8'hF0;
        ram[16'h800C] = 8'h09; ram[16'h800D] = 8'h0F; ram[16'h800E] = 8'h00;
        ram[16'h800F] = 8'h8D; ram[16'h8010] = 8'h72; ram[16'h8011] = 8'h02;
        ram[16'h8012] = 8'hA9; ram[16'h8013] = 8'hAA; ram[16'h8014] = 8'hAA;
        ram[16'h8015] = 8'h49; ram[16'h8016] = 8'hFF; ram[16'h8017] = 8'hFF;
        ram[16'h8018] = 8'h8D; ram[16'h8019] = 8'h74; ram[16'h801A] = 8'h02;
        ram[16'h801B] = 8'hDB; // STP

        ram[16'hFFFC] = 8'h00; ram[16'hFFFD] = 8'h80;
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        run_until_stp(max_cycles);
        check_ram16(16'h0270, 16'h0F00, "AND FF0F & 0FF0");
        check_ram16(16'h0272, 16'hF00F, "ORA F000 | 000F");
        check_ram16(16'h0274, 16'h5555, "EOR AAAA ^ FFFF");

        // ============================================================
        // Test 9: Shift operations (ASL A, LSR A, ROL A, ROR A)
        // Program:
        //   LDA #$0001    ; A9 01 00
        //   ASL A         ; 0A
        //   ASL A         ; 0A
        //   STA $0280     ; 8D 80 02    -> $0004
        //   LDA #$8000    ; A9 00 80
        //   LSR A         ; 4A
        //   STA $0282     ; 8D 82 02    -> $4000
        //   CLC           ; 18
        //   LDA #$8001    ; A9 01 80
        //   ROL A         ; 2A          -> $0002, C=1
        //   ROL A         ; 2A          -> $0005, C=0
        //   STA $0284     ; 8D 84 02    -> $0005
        //   STP           ; DB
        // ============================================================
        $display("");
        $display("=== Test 9: ASL/LSR/ROL Shifts ===");

        for (i = 16'h8000; i < 16'h8030; i = i + 1) ram[i] = 8'h00;

        ram[16'h8000] = 8'hA9; ram[16'h8001] = 8'h01; ram[16'h8002] = 8'h00;
        ram[16'h8003] = 8'h0A; // ASL A
        ram[16'h8004] = 8'h0A; // ASL A
        ram[16'h8005] = 8'h8D; ram[16'h8006] = 8'h80; ram[16'h8007] = 8'h02;
        ram[16'h8008] = 8'hA9; ram[16'h8009] = 8'h00; ram[16'h800A] = 8'h80;
        ram[16'h800B] = 8'h4A; // LSR A
        ram[16'h800C] = 8'h8D; ram[16'h800D] = 8'h82; ram[16'h800E] = 8'h02;
        ram[16'h800F] = 8'h18; // CLC
        ram[16'h8010] = 8'hA9; ram[16'h8011] = 8'h01; ram[16'h8012] = 8'h80;
        ram[16'h8013] = 8'h2A; // ROL A  -> 0002, C=1
        ram[16'h8014] = 8'h2A; // ROL A  -> 0005, C=0
        ram[16'h8015] = 8'h8D; ram[16'h8016] = 8'h84; ram[16'h8017] = 8'h02;
        ram[16'h8018] = 8'hDB; // STP

        ram[16'hFFFC] = 8'h00; ram[16'hFFFD] = 8'h80;
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        run_until_stp(max_cycles);
        check_ram16(16'h0280, 16'h0004, "ASL A twice");
        check_ram16(16'h0282, 16'h4000, "LSR $8000");
        check_ram16(16'h0284, 16'h0005, "ROL A twice with carry");

        // ============================================================
        // Test 10: Loop with branch (count down from 5)
        // Program:
        //   LDX #$0005    ; A2 05 00
        // loop:
        //   DEX           ; CA
        //   BNE loop      ; D0 FD  (-3)
        //   TXA           ; 8A
        //   STA $0290     ; 8D 90 02   -> $0000 (X counted to 0)
        //   STP           ; DB
        // ============================================================
        $display("");
        $display("=== Test 10: Loop with BNE ===");

        for (i = 16'h8000; i < 16'h8020; i = i + 1) ram[i] = 8'h00;

        ram[16'h8000] = 8'hA2; // LDX #5
        ram[16'h8001] = 8'h05;
        ram[16'h8002] = 8'h00;
        ram[16'h8003] = 8'hCA; // DEX
        ram[16'h8004] = 8'hD0; // BNE -3 (back to $8003)
        ram[16'h8005] = 8'hFD;
        ram[16'h8006] = 8'h8A; // TXA
        ram[16'h8007] = 8'h8D; // STA $0290
        ram[16'h8008] = 8'h90;
        ram[16'h8009] = 8'h02;
        ram[16'h800A] = 8'hDB; // STP

        ram[16'hFFFC] = 8'h00; ram[16'hFFFD] = 8'h80;
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        run_until_stp(5000);
        check_ram16(16'h0290, 16'h0000, "Loop DEX to 0");

        // ============================================================
        // Test 11: Direct page addressing
        // Program:
        //   LDA #$BEEF    ; A9 EF BE
        //   STA $10       ; 85 10      (store to DP+$10 = $0010)
        //   LDA #$0000    ; A9 00 00
        //   LDA $10       ; A5 10      (load from DP+$10)
        //   STA $02A0     ; 8D A0 02
        //   STP           ; DB
        // ============================================================
        $display("");
        $display("=== Test 11: Direct Page Addressing ===");

        for (i = 16'h8000; i < 16'h8020; i = i + 1) ram[i] = 8'h00;

        ram[16'h8000] = 8'hA9; ram[16'h8001] = 8'hEF; ram[16'h8002] = 8'hBE;
        ram[16'h8003] = 8'h85; ram[16'h8004] = 8'h10; // STA dp $10
        ram[16'h8005] = 8'hA9; ram[16'h8006] = 8'h00; ram[16'h8007] = 8'h00;
        ram[16'h8008] = 8'hA5; ram[16'h8009] = 8'h10; // LDA dp $10
        ram[16'h800A] = 8'h8D; ram[16'h800B] = 8'hA0; ram[16'h800C] = 8'h02;
        ram[16'h800D] = 8'hDB; // STP

        ram[16'hFFFC] = 8'h00; ram[16'hFFFD] = 8'h80;
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        run_until_stp(max_cycles);
        check_ram16(16'h02A0, 16'hBEEF, "DP load/store");

        // ============================================================
        // Test 12: CMP and flag-based branching
        // Program:
        //   LDA #$0010
        //   CMP #$0010    ; Should set Z=1
        //   BEQ equal     ; branch if equal
        //   LDA #$DEAD    ; (skipped)
        // equal:
        //   STA $02B0     ; -> should be $0010
        //   LDA #$0020
        //   CMP #$0010    ; A>M, should set C=1, Z=0
        //   BCS greater   ; branch if carry set (A >= M)
        //   LDA #$DEAD
        // greater:
        //   STA $02B2     ; -> should be $0020
        //   STP
        // ============================================================
        $display("");
        $display("=== Test 12: CMP + Flag Branches ===");

        for (i = 16'h8000; i < 16'h8030; i = i + 1) ram[i] = 8'h00;

        ram[16'h8000] = 8'hA9; ram[16'h8001] = 8'h10; ram[16'h8002] = 8'h00; // LDA #$0010
        ram[16'h8003] = 8'hC9; ram[16'h8004] = 8'h10; ram[16'h8005] = 8'h00; // CMP #$0010
        ram[16'h8006] = 8'hF0; ram[16'h8007] = 8'h03;                         // BEQ +3
        ram[16'h8008] = 8'hA9; ram[16'h8009] = 8'hAD; ram[16'h800A] = 8'hDE; // LDA #$DEAD
        ram[16'h800B] = 8'h8D; ram[16'h800C] = 8'hB0; ram[16'h800D] = 8'h02; // STA $02B0
        ram[16'h800E] = 8'hA9; ram[16'h800F] = 8'h20; ram[16'h8010] = 8'h00; // LDA #$0020
        ram[16'h8011] = 8'hC9; ram[16'h8012] = 8'h10; ram[16'h8013] = 8'h00; // CMP #$0010
        ram[16'h8014] = 8'hB0; ram[16'h8015] = 8'h03;                         // BCS +3
        ram[16'h8016] = 8'hA9; ram[16'h8017] = 8'hAD; ram[16'h8018] = 8'hDE; // LDA #$DEAD
        ram[16'h8019] = 8'h8D; ram[16'h801A] = 8'hB2; ram[16'h801B] = 8'h02; // STA $02B2
        ram[16'h801C] = 8'hDB; // STP

        ram[16'hFFFC] = 8'h00; ram[16'hFFFD] = 8'h80;
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        run_until_stp(max_cycles);
        check_ram16(16'h02B0, 16'h0010, "CMP equal BEQ taken");
        check_ram16(16'h02B2, 16'h0020, "CMP greater BCS taken");

        // ============================================================
        // Test 13: XBA (exchange B and A bytes)
        // Program:
        //   LDA #$1234
        //   XBA           ; A becomes $3412
        //   STA $02C0
        //   STP
        // ============================================================
        $display("");
        $display("=== Test 13: XBA ===");

        for (i = 16'h8000; i < 16'h8020; i = i + 1) ram[i] = 8'h00;

        ram[16'h8000] = 8'hA9; ram[16'h8001] = 8'h34; ram[16'h8002] = 8'h12;
        ram[16'h8003] = 8'hEB; // XBA
        ram[16'h8004] = 8'h8D; ram[16'h8005] = 8'hC0; ram[16'h8006] = 8'h02;
        ram[16'h8007] = 8'hDB;

        ram[16'hFFFC] = 8'h00; ram[16'hFFFD] = 8'h80;
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        run_until_stp(max_cycles);
        check_ram16(16'h02C0, 16'h3412, "XBA swap bytes");

        // ============================================================
        // Test 14: INC/DEC memory (RMW)
        // Program:
        //   LDA #$00FF
        //   STA $0040       ; store $00FF at dp $40
        //   INC $40         ; dp $40 becomes $0100
        //   LDA $40
        //   STA $02D0
        //   DEC $40         ; dp $40 back to $00FF
        //   LDA $40
        //   STA $02D2
        //   STP
        // ============================================================
        $display("");
        $display("=== Test 14: INC/DEC Memory (RMW) ===");

        for (i = 16'h8000; i < 16'h8030; i = i + 1) ram[i] = 8'h00;

        ram[16'h8000] = 8'hA9; ram[16'h8001] = 8'hFF; ram[16'h8002] = 8'h00; // LDA #$00FF
        ram[16'h8003] = 8'h85; ram[16'h8004] = 8'h40;                         // STA $40
        ram[16'h8005] = 8'hE6; ram[16'h8006] = 8'h40;                         // INC $40
        ram[16'h8007] = 8'hA5; ram[16'h8008] = 8'h40;                         // LDA $40
        ram[16'h8009] = 8'h8D; ram[16'h800A] = 8'hD0; ram[16'h800B] = 8'h02; // STA $02D0
        ram[16'h800C] = 8'hC6; ram[16'h800D] = 8'h40;                         // DEC $40
        ram[16'h800E] = 8'hA5; ram[16'h800F] = 8'h40;                         // LDA $40
        ram[16'h8010] = 8'h8D; ram[16'h8011] = 8'hD2; ram[16'h8012] = 8'h02; // STA $02D2
        ram[16'h8013] = 8'hDB;

        ram[16'hFFFC] = 8'h00; ram[16'hFFFD] = 8'h80;
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        run_until_stp(max_cycles);
        check_ram16(16'h02D0, 16'h0100, "INC dp $FF->$100");
        check_ram16(16'h02D2, 16'h00FF, "DEC dp $100->$FF");

        // ============================================================
        // Test 15: STZ (store zero)
        // Program:
        //   LDA #$FFFF
        //   STA $0050
        //   STZ $0050       ; should write $0000
        //   LDA $0050
        //   STA $02E0
        //   STP
        // ============================================================
        $display("");
        $display("=== Test 15: STZ ===");

        for (i = 16'h8000; i < 16'h8020; i = i + 1) ram[i] = 8'h00;

        ram[16'h8000] = 8'hA9; ram[16'h8001] = 8'hFF; ram[16'h8002] = 8'hFF;
        ram[16'h8003] = 8'h85; ram[16'h8004] = 8'h50;
        ram[16'h8005] = 8'h64; ram[16'h8006] = 8'h50; // STZ dp
        ram[16'h8007] = 8'hA5; ram[16'h8008] = 8'h50;
        ram[16'h8009] = 8'h8D; ram[16'h800A] = 8'hE0; ram[16'h800B] = 8'h02;
        ram[16'h800C] = 8'hDB;

        ram[16'hFFFC] = 8'h00; ram[16'hFFFD] = 8'h80;
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        run_until_stp(max_cycles);
        check_ram16(16'h02E0, 16'h0000, "STZ clears memory");

        // ============================================================
        // Summary
        // ============================================================
        $display("");
        $display("========================================");
        $display("CPU Core Tests: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================");
        if (fail_count > 0) $display("*** FAILURES DETECTED ***");
        $finish;
    end

endmodule
