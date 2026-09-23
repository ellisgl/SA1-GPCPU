# SA1-GPCPU

A custom 16-bit CPU implemented in Verilog, inspired by the WDC 65C816 with SA-1/5A22 coprocessor features. Targets the **Gowin GW5AST-138B** FPGA.

> This project was designed and implemented by [Claude](https://claude.com) (Anthropic's AI assistant), collaborating with a human developer.

## Architecture Overview

- **16-bit data bus** with byte/word transfer support (`bus_width` signal)
- **24-bit address bus** (16MB address space) using PBR/DBR bank registers
- **16-bit registers**: A, X, Y, SP, DP (no 6502 8-bit emulation mode)
- **Multi-cycle state machine** with bus handshake protocol
- **33 CPU states**, reduced from 49 by merging byte-pair operations into single word transfers
- Full 65C816 instruction set support including all addressing modes

## Block Diagram

```
                    +-----------------------------+
                    |       sa1_gpcpu_top         |
                    |                             |
  IRQ/NMI -------->|  +----------+  +---------+  |
                    |  | CPU Core |  | Intc    |  |
                    |  |          |<>|         |  |
                    |  +----+-----+  +---------+  |
                    |       |                     |
                    |       v  I/O ($4200-$43FF)  |
                    |  +----------+               |
                    |  | Bus      | +---------+   |
                    |  | Arbiter  | | Timer   |   |     +--------+
                    |  |          | +---------+   |     |External|
                    |  | CPU      | +---------+   |<--->|Memory  |
                    |  | DMA      | | Math    |   |     +--------+
                    |  | VLB      | +---------+   |
                    |  +----------+ +---------+   |
                    |               | DMA Ctrl|   |
                    |               +---------+   |
                    |               +---------+   |
                    |               | VarLen  |   |
                    |               | BitProc |   |
                    |               +---------+   |
                    +-----------------------------+
```

## Source Files

### CPU Core (`src/`)

| File | Lines | Description |
|------|------:|-------------|
| `cpu_core.v` | 1113 | Main CPU state machine and datapath |
| `control_unit.v` | 1087 | Combinational instruction decoder (opcode to control signals) |
| `register_file.v` | 157 | Register file (A, X, Y, SP, DP, PC, PBR, DBR, P) |
| `alu.v` | 145 | 16-bit ALU (ADC, SBC, AND, ORA, EOR, shifts, CMP, BIT, etc.) |
| `address_gen.v` | 211 | Address computation for all 65C816 addressing modes |
| `cpu_defines.vh` | 154 | Shared defines (ALU ops, addressing modes, states, vectors) |

### SoC Peripherals (`src/`)

| File | Lines | Description |
|------|------:|-------------|
| `sa1_gpcpu_top.v` | 366 | Top-level SoC: CPU + bus arbiter + I/O peripherals |
| `bus_arbiter.v` | 111 | Bus arbiter: CPU vs DMA vs VarLen (priority-based) |
| `interrupt_ctrl.v` | 124 | Interrupt controller (IRQ, NMI, Timer, DMA, BRK, COP) |
| `timer.v` | 143 | Dual timer with prescaler and auto-reload |
| `dma_controller.v` | 202 | 4-channel DMA controller (5A22/SA-1 inspired) |
| `math_unit.v` | 102 | Hardware multiply/divide with cumulative sum |
| `varlen_bitproc.v` | 180 | Variable-length bit field extractor (SA-1 inspired) |

### Testbenches (`tb/`)

| File | Tests | Description |
|------|------:|-------------|
| `tb_cpu_core.v` | 23 | CPU instruction tests (ALU, branches, stack, JSR/RTS, RMW, etc.) |
| `tb_sa1_gpcpu_top.v` | 6 | End-to-end SoC tests (bus arbiter, I/O, math unit) |
| `tb_alu.v` | - | ALU unit tests |
| `tb_math_unit.v` | - | Math unit tests |
| `tb_timer.v` | - | Timer unit tests |

## I/O Memory Map

All I/O registers are in bank `$00`, addresses `$4200`-`$43FF`:

| Address Range | Peripheral |
|---------------|------------|
| `$4200`-`$420F` | Interrupt controller |
| `$4210`-`$421F` | Timer |
| `$4220`-`$425F` | DMA controller (4 channels) |
| `$4260`-`$426F` | Math unit (multiply, divide, cumulative sum) |
| `$4270`-`$427F` | Variable-length bit processor |

## Building & Testing

### Prerequisites

- [Verilator](https://www.veripool.org/verilator/) 5.x (required for `--timing` support)
- iverilog is **not** recommended due to a simulator bug with `always @(*)`

### Running Tests

CPU core tests (23 assertions):
```bash
cd tb
verilator --binary --timing -I../src -Wall \
  -Wno-WIDTHTRUNC -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN \
  -Wno-WIDTHEXPAND -Wno-CASEINCOMPLETE \
  -o Vtb_cpu_core \
  tb_cpu_core.v ../src/cpu_core.v ../src/control_unit.v \
  ../src/register_file.v ../src/alu.v ../src/address_gen.v
./obj_dir/Vtb_cpu_core
```

Top-level SoC tests (6 assertions):
```bash
cd tb
verilator --binary --timing -I../src -Wall \
  -Wno-WIDTHTRUNC -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN \
  -Wno-WIDTHEXPAND -Wno-CASEINCOMPLETE \
  -Wno-PINCONNECTEMPTY -Wno-UNUSEDPARAM \
  -o Vtb_sa1_gpcpu_top \
  tb_sa1_gpcpu_top.v ../src/*.v
./obj_dir/Vtb_sa1_gpcpu_top
```

### FPGA Synthesis

The project includes a Gowin EDA project file (`SA1-GPCPU.gprj`) targeting the GW5AST-138B.

## Key Design Decisions

- **16-bit only**: No 6502 emulation mode. The M and X status bits are hardwired to 0 (always 16-bit accumulator and index registers).
- **Bus handshake**: Uses `bus_valid`/`bus_ready` handshake. The CPU's ack condition is `bus_ready & (state == state_prev)`, ensuring the response matches the current request.
- **Word-aligned I/O**: The math unit supports 16-bit word reads/writes at even-aligned addresses, allowing a single `STA` to write both bytes of a register pair.
- **CMP is carry-independent**: `result = a - b; carry_out = (a >= b)` -- the incoming carry flag does not affect CMP, matching 65C816 behavior.
- **JSR/RTS convention**: JSR pushes PC-1 (address of the last byte of the JSR instruction). RTS pulls and adds 1 to get the correct return address.

## License

This project is provided as-is for educational and hobbyist purposes.
