# RV32I Processor Core

This directory contains the synthesizable Verilog implementation of a **single-cycle RISC-V 32-bit (RV32I)** processor core.

---

## Directory Modules

| File | Module | Type | Description |
| :--- | :--- | :--- | :--- |
| [`Datapath.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/Datapath.v) | `Datapath` | Top-Level Core | Wires the PC, instruction memory, decoder, control logic, register file, ALU subsystem, and data memory. |
| [`ProgramCounter.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/ProgramCounter.v) | `ProgramCounter` | Sequential Unit | Computes the next program counter value: sequential (`PC+4`), branch (`PC+imm`), `JAL` (`PC+imm`), or `JALR` (`(rs1+imm)&~1`). |
| [`instructionMemory.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/instructionMemory.v) | `instructionMemory` | Memory (ROM) | 256-byte byte-addressable ROM holding up to 64 instructions. Initialized via `$readmemh("instructions.hex", temp_mem)`. |
| [`decoder.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/decoder.v) | `decoder` | Combinational | Extracts opcode, rd, rs1, rs2, func3, func7, and produces sign-extended 32-bit immediates for I, S, B, U, and J instruction formats. |
| [`ControlLogic.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/ControlLogic.v) | `ControlLogic` | Combinational | Generates datapath control signals based on the 7-bit opcode (`reg_write`, `mem_read`, `mem_write`, `alu_src`, `mem_to_reg`, `branch`, `jump`, `alu_op`). |
| [`RegFile.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/RegFile.v) | `RegFile` | Sequential / Regs | 32 x 32-bit General Purpose Register File (`x0`-`x31`). Combinational read, synchronous write. `x0` is hardwired to 0. |
| [`alu.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/alu.v) | `alu` | Execution Unit | Top ALU wrapper combining arithmetic/logic (`RI_alu`) and branching logic (`bAlu`), plus memory address, AUIPC, LUI, and return link multiplexing. |
| [`RI_alu.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/RI_alu.v) | `RI_alu` | Execution Unit | Arithmetic and logic unit for R-type and I-type instructions (ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND). |
| [`bAlu.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/bAlu.v) | `bAlu` | Branch Unit | Evaluates branch conditions (BEQ, BNE, BLT, BGE, BLTU, BGEU) and asserts `jump`. |
| [`dataMemory.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/dataMemory.v) | `dataMemory` | Memory (RAM) | 256-byte synchronous RAM supporting little-endian 32-bit word read (`load`) and write (`write`). |

---

## Top-Level Interface (`Datapath.v`)

```verilog
module Datapath (
    input             clk,          // System clock
    input             reset,        // Active-high synchronous reset
    output     [31:0] pcRegister,   // Current Program Counter value
    
    // External memory bus monitoring & interconnect signals
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

- **Endianness**: Little-endian byte ordering for both instruction and data memories.
- **Program Memory Initialization**: `instructionMemory` expects an `instructions.hex` file containing 32-bit hexadecimal instruction words in the simulation directory.
- **Write-Back Selection**:
  - `mem_to_reg == 2'b01`: Selects `mem_data_out` from `dataMemory` (`LW`).
  - Otherwise: Selects `alu_out` (handles R/I-type ALU results, `PC + 4` for JAL/JALR, `imm` for LUI, and `PC + imm` for AUIPC).
