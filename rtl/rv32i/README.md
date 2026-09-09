# RV32I Processor Core

This directory contains the synthesizable Verilog implementation of a **single-cycle RISC-V 32-bit (RV32I)** processor core with bus stall capability.

---

## Directory Modules

| File | Module | Type | Description |
| :--- | :--- | :--- | :--- |
| [`Datapath.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rtl/rv32i/Datapath.v) | `Datapath` | Top-Level Core | Wires the PC, instruction memory, decoder, control logic, register file, ALU subsystem, and write-back multiplexer. |
| [`ProgramCounter.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rtl/rv32i/ProgramCounter.v) | `ProgramCounter` | Sequential Unit | Computes next PC: sequential (`PC+4`), branch (`PC+imm`), `JAL` (`PC+imm`), or `JALR` (`(rs1+imm)&~1`), with pipeline stall support. |
| [`instructionMemory.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rtl/rv32i/instructionMemory.v) | `instructionMemory` | Memory (ROM) | 1 KB word-addressed ROM (256 instructions). Initialized via `$readmemh("instructions.hex", memory)`. |
| [`decoder.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rtl/rv32i/decoder.v) | `decoder` | Combinational | Extracts opcode, rd, rs1, rs2, func3, func7, and produces sign-extended 32-bit immediates for I, S, B, U, and J instruction formats. |
| [`ControlLogic.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rtl/rv32i/ControlLogic.v) | `ControlLogic` | Combinational | Generates datapath control signals based on 7-bit opcodes (`reg_write`, `mem_read`, `mem_write`, `alu_src`, `mem_to_reg`, `branch`, `jump`, `alu_op`). |
| [`RegFile.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rtl/rv32i/RegFile.v) | `RegFile` | Sequential / Regs | 32 x 32-bit General Purpose Register File (`x0`-`x31`). Dual asynchronous read ports, synchronous write port. Write gated by `!stall`. `x0` hardwired to 0. |
| [`alu.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rtl/rv32i/alu.v) | `alu` | Execution Unit | Top ALU wrapper combining arithmetic/logic (`RI_alu`) and branching (`bAlu`), plus memory address, AUIPC, LUI, and return link multiplexing. |
| [`RI_alu.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rtl/rv32i/RI_alu.v) | `RI_alu` | Execution Unit | Arithmetic and logic unit for R-type and I-type instructions (ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND). |
| [`bAlu.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rtl/rv32i/bAlu.v) | `bAlu` | Branch Unit | Evaluates branch conditions (BEQ, BNE, BLT, BGE, BLTU, BGEU) and asserts `jump`. |
| [`dataMemory.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rtl/rv32i/dataMemory.v) | `dataMemory` | Memory (RAM) | Standalone 256-byte synchronous RAM supporting little-endian 32-bit word read (`load`) and write (`write`). |
| [`immTo32.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rtl/rv32i/immTo32.v) | `immTo32` | Utility | Sign-extends 12-bit immediate values to 32 bits. |
| [`sram.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rtl/rv32i/sram.v) | `sram` | Template | Synchronous SRAM block template. |

---

## Top-Level Interface (`Datapath.v`)

```verilog
module Datapath (
    input             clk,          // System clock
    input             reset,        // Active-high synchronous reset
    input             stall,        // Pipeline stall from AXI bridge (freezes PC & RegFile write)
    input      [31:0] mem_rdata,    // Read data returned from memory/interconnect
    output     [31:0] pcRegister,   // Current Program Counter value
    output     [31:0] mem_addr,     // Memory address computed by ALU (rs1 + imm)
    output     [31:0] mem_wdata,    // Store data from rs2
    output            mem_write,    // Memory write enable (active high)
    output            mem_read      // Memory read enable (active high)
);
```

---

## Supported Instruction Set (RV32I)

1. **R-Type**: `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`
2. **I-Type ALU**: `ADDI`, `SLLI`, `SLTI`, `SLTIU`, `XORI`, `SRLI`, `SRAI`, `ORI`, `ANDI`
3. **I-Type Load**: `LW`
4. **S-Type Store**: `SW`
5. **B-Type Branch**: `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`
6. **U-Type Upper Immediate**: `LUI`, `AUIPC`
7. **J-Type / I-Type Jumps**: `JAL`, `JALR`

---

## Memory & Execution Notes

- **Endianness**: Little-endian byte ordering.
- **Program Memory Initialization**: `instructionMemory.v` loads 32-bit hexadecimal words directly from `instructions.hex` on reset.
- **Write-Back Selection**:
  - `mem_to_reg == 2'b01`: Selects `mem_rdata` from external memory / AXI bridge (`LW`).
  - Otherwise: Selects `alu_out` (handles R/I-type ALU results, `PC + 4` for JAL/JALR, `imm` for LUI, and `PC + imm` for AUIPC).
- **Stall Handling**: When the CPU performs a load or store across the AXI bridge, `stall` is asserted until completion, preventing the PC from incrementing and blocking spurious register writes.
