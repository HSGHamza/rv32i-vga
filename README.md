# RV32I Processor Core with VGA Subsystem

A 32-bit RISC-V (RV32I Base Integer ISA) processor core written in synthesizable Verilog HDL, designed as the central processing unit for an integrated System-on-Chip (SoC) featuring an AXI-4 interconnect and a hardware VGA graphics controller.

---

## Table of Contents

- [Overview](#overview)
- [Architecture & Features](#architecture--features)
- [Microarchitecture Datapath](#microarchitecture-datapath)
- [Module Breakdown](#module-breakdown)
- [Instruction Set Architecture (ISA) Support](#instruction-set-architecture-isa-support)
- [Control Logic Unit](#control-logic-unit)
- [Memory Organization](#memory-organization)
- [System Integration (RV32I + AXI + VGA)](#system-integration-rv32i--axi--vga)
- [Simulation & Verification](#simulation--verification)
- [File Structure](#file-structure)

---

## Overview

This repository contains the complete single-cycle implementation of a **RISC-V 32-bit Integer (RV32I)** microprocessor core. The core provides native execution for all fundamental integer instructions including register-register operations, immediate arithmetic, loads, stores, conditional branches, and unconditional jumps.

The processor is integrated with an on-chip **AXI crossbar bus** (`rtl/bus/axi_decoder.v`) and an **on-chip VGA display controller subsystem** (`rtl/vga/`), enabling real-time frame rendering directly driven by CPU memory-mapped writes.

```
+-------------------------------------------------------------+
|                      RV32I-VGA SoC                          |
|                                                             |
|  +--------------------+             +--------------------+  |
|  |                    |   Memory    |                    |  |
|  |  RV32I Processor   |------------>|    AXI Crossbar    |  |
|  |     Core (CPU)     |  Bus / MMIO |    Bus Decoder     |  |
|  +--------------------+             +--------------------+  |
|                                            |     |          |
|                                            v     v          |
|                     +-------------------------+  +-------+  |
|                     |     VGA Subsystem       |  | Frame |  |
|                     | (Timing, Control, Regs) |  | SRAM  |  |
|                     +-------------------------+  +-------+  |
|                                  |                          |
|                                  v                          |
|                         VGA RGB / Sync Pins                 |
+-------------------------------------------------------------+
```

---

## Architecture & Features

- **Standard**: RISC-V unprivileged ISA specification (RV32I Base Integer Instruction Set).
- **Execution Model**: Single-cycle microarchitecture. Every instruction fetches, decodes, executes, accesses memory, and commits write-back in a single clock cycle.
- **Data Width**: 32-bit datapath, 32-bit Program Counter (PC), 32-bit ALU, 32-bit General Purpose Registers (GPRs).
- **Register File**: 32 x 32-bit integer registers (`x0` through `x31`), with `x0` hardwired to constant `0`. Dual asynchronous read ports, single synchronous write port.
- **Instruction Memory (Local ROM)**: 256-byte byte-addressable memory (stores up to 64 instructions), pre-loadable via `$readmemh("instructions.hex", ...)`.
- **Data Memory (Local RAM)**: 256-byte byte-addressable memory with synchronous read and write.
- **Branch & Jump Handling**: Dedicated Branch ALU (`bAlu`) supporting signed/unsigned relational comparisons and dedicated target address generation in the Program Counter.
- **Bus Monitoring Interface**: Direct top-level access to memory address (`mem_addr`), write data (`mem_wdata`), memory write enable (`mem_write`), and memory read enable (`mem_read`) for bus bridging and verification.

---

## Microarchitecture Datapath

The complete processor core is structured inside `rv32i/Datapath.v`. The diagram below illustrates the signal routing and interconnection of all constituent hardware units:

```mermaid
flowchart LR
    subgraph IF [Instruction Fetch]
        PC[ProgramCounter]
        IMEM[instructionMemory]
        PC -->|pcRegister[31:0]| IMEM
    end

    subgraph ID [Decode & Control]
        DEC[decoder]
        CTRL[ControlLogic]
        IMEM -->|instr[31:0]| DEC
        DEC -->|opcodout[6:0]| CTRL
    end

    subgraph RF [Register File]
        REG[RegFile (32x32)]
        DEC -->|rs1, rs2, rd| REG
        CTRL -->|reg_write| REG
    end

    subgraph EX [Execution & ALU]
        ALU_TOP[alu]
        RI[RI_alu]
        BA[bAlu]
        ALU_TOP -.-> RI
        ALU_TOP -.-> BA
        REG -->|rs1out, rs2out| ALU_TOP
        DEC -->|imm, func3, func7| ALU_TOP
        PC -->|pcRegister| ALU_TOP
        ALU_TOP -->|doesB (jump)| PC
        DEC -->|imm| PC
    end

    subgraph MEM [Data Memory]
        DMEM[dataMemory]
        ALU_TOP -->|alu_out (address)| DMEM
        REG -->|rs2out (data_in)| DMEM
        CTRL -->|mem_read, mem_write| DMEM
    end

    subgraph WB [Write-Back]
        MUX_WB{"mem_to_reg == 2'b01"}
        DMEM -->|mem_data_out| MUX_WB
        ALU_TOP -->|alu_out| MUX_WB
        MUX_WB -->|rw| REG
    end
```

---

## Module Breakdown

All hardware modules of the RV32I core reside in the [`rv32i/`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i) directory:

| Module File | Top Module Name | Description |
| :--- | :--- | :--- |
| [`Datapath.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/Datapath.v) | `Datapath` | Top-level processor core connecting PC, Instruction Memory, Decoder, Control Logic, Register File, ALU subsystem, Data Memory, and Write-Back logic. |
| [`ProgramCounter.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/ProgramCounter.v) | `ProgramCounter` | Generates next PC address: sequential (`PC+4`), branch target (`PC+imm`), direct jump (`PC+imm` for JAL), or indirect jump (`(rs1+imm) & ~1` for JALR). |
| [`instructionMemory.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/instructionMemory.v) | `instructionMemory` | Byte-addressable ROM containing 256 bytes (64 instructions). Little-endian reconstruction from byte slices. Preloaded from `instructions.hex`. |
| [`decoder.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/decoder.v) | `decoder` | Combinational instruction decoder. Extracts `opcode`, `rd`, `rs1`, `rs2`, `func3`, `func7`, and produces sign-extended 32-bit immediates for I, S, B, U, and J formats. |
| [`ControlLogic.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/ControlLogic.v) | `ControlLogic` | Main control unit translating 7-bit opcodes into control signals (`reg_write`, `mem_read`, `mem_write`, `alu_src`, `mem_to_reg`, `branch`, `jump`, `alu_op`). |
| [`RegFile.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/RegFile.v) | `RegFile` | 32 x 32-bit general-purpose register file (`x0`-`x31`). Dual asynchronous read ports (`rs1out`, `rs2out`) and one synchronous write port (`rw` to `rd`). `x0` hardwired to 0. |
| [`alu.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/alu.v) | `alu` | Top-level arithmetic module encapsulating `RI_alu` and `bAlu`. Also computes memory effective addresses, AUIPC (`PC + imm`), LUI (`imm`), and jump return links (`PC + 4`). |
| [`RI_alu.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/RI_alu.v) | `RI_alu` | Execution unit for register-register (R-type) and register-immediate (I-type) arithmetic and logical instructions (ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND). |
| [`bAlu.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/bAlu.v) | `bAlu` | Branch comparison unit computing branch outcomes (`jump = 1'b1`) for BEQ, BNE, BLT, BGE, BLTU, and BGEU based on `func3`. |
| [`dataMemory.v`](file:///c:/Users/HSG/Desktop/rv32i-vga/rv32i/dataMemory.v) | `dataMemory` | Synchronous 256-byte data RAM. Supports 32-bit word loads and stores with little-endian byte ordering. |

---

## Instruction Set Architecture (ISA) Support

The core implements the standard 32-bit RV32I Base Integer instruction set:

### 1. R-Type (Register-Register Arithmetic & Logic)
- **Opcode**: `7'b0110011` (`7'd51`)
- **Format**: `func7[31:25] | rs2[24:20] | rs1[19:15] | func3[14:12] | rd[11:7] | opcode[6:0]`

| Mnemonic | func3 | func7 | Operation | Description |
| :--- | :---: | :---: | :--- | :--- |
| **ADD** | `000` | `0000000` | `rd = rs1 + rs2` | Integer Addition |
| **SUB** | `000` | `0100000` | `rd = rs1 - rs2` | Integer Subtraction |
| **SLL** | `001` | `0000000` | `rd = rs1 << rs2[4:0]` | Shift Left Logical |
| **SLT** | `010` | `0000000` | `rd = ($signed(rs1) < $signed(rs2)) ? 1 : 0` | Set Less Than (Signed) |
| **SLTU** | `011` | `0000000` | `rd = (rs1 < rs2) ? 1 : 0` | Set Less Than Unsigned |
| **XOR** | `100` | `0000000` | `rd = rs1 ^ rs2` | Bitwise Exclusive-OR |
| **SRL** | `101` | `0000000` | `rd = rs1 >> rs2[4:0]` | Shift Right Logical |
| **SRA** | `101` | `0100000` | `rd = $signed(rs1) >>> rs2[4:0]` | Shift Right Arithmetic (Sign-Extended) |
| **OR** | `110` | `0000000` | `rd = rs1 \| rs2` | Bitwise OR |
| **AND** | `111` | `0000000` | `rd = rs1 & rs2` | Bitwise AND |

### 2. I-Type (Register-Immediate ALU)
- **Opcode**: `7'b0010011` (`7'd19`)
- **Format**: `imm[31:20] | rs1[19:15] | func3[14:12] | rd[11:7] | opcode[6:0]`
- **Immediate**: Sign-extended 12-bit immediate: `{{20{instr[31]}}, instr[31:20]}`

| Mnemonic | func3 | func7 | Operation | Description |
| :--- | :---: | :---: | :--- | :--- |
| **ADDI** | `000` | — | `rd = rs1 + imm` | Add Immediate |
| **SLLI** | `001` | `0000000` | `rd = rs1 << imm[4:0]` | Shift Left Logical Immediate |
| **SLTI** | `010` | — | `rd = ($signed(rs1) < $signed(imm)) ? 1 : 0` | Set Less Than Immediate (Signed) |
| **SLTIU** | `011` | — | `rd = (rs1 < imm) ? 1 : 0` | Set Less Than Immediate Unsigned |
| **XORI** | `100` | — | `rd = rs1 ^ imm` | Bitwise XOR Immediate |
| **SRLI** | `101` | `0000000` | `rd = rs1 >> imm[4:0]` | Shift Right Logical Immediate |
| **SRAI** | `101` | `0100000` | `rd = $signed(rs1) >>> imm[4:0]` | Shift Right Arithmetic Immediate |
| **ORI** | `110` | — | `rd = rs1 \| imm` | Bitwise OR Immediate |
| **ANDI** | `111` | — | `rd = rs1 & imm` | Bitwise AND Immediate |

### 3. Load & Store Instructions
- **LW (Load Word)**: Opcode `7'b0000011` (`7'd3`), `func3 = 3'b010`. Address = `rs1 + imm`. Loads 32-bit little-endian word from `dataMemory` to `rd`.
- **SW (Store Word)**: Opcode `7'b0100011` (`7'd35`), `func3 = 3'b010`. Address = `rs1 + imm`. Stores 32-bit little-endian word from `rs2` into `dataMemory`.

### 4. Branch Instructions (B-Type)
- **Opcode**: `7'b1100011` (`7'd99`)
- **Immediate**: Reconstructed B-immediate with bit 0 set to 0. Target = `PC + imm`.

| Mnemonic | func3 | Condition Evaluated in `bAlu` |
| :--- | :---: | :--- |
| **BEQ** | `000` | `$signed(rs1) == $signed(rs2)` |
| **BNE** | `001` | `$signed(rs1) != $signed(rs2)` |
| **BLT** | `100` | `$signed(rs1) < $signed(rs2)` (Signed) |
| **BGE** | `101` | `$signed(rs1) >= $signed(rs2)` (Signed) |
| **BLTU** | `110` | `rs1 < rs2` (Unsigned) |
| **BGEU** | `111` | `rs1 >= rs2` (Unsigned) |

### 5. Upper Immediate Instructions (U-Type)
- **LUI (Load Upper Immediate)**: Opcode `7'b0110111` (`7'd55`). Loads `imm[31:12] << 12` into `rd`.
- **AUIPC (Add Upper Immediate to PC)**: Opcode `7'b0010111` (`7'd23`). `rd = PC + (imm[31:12] << 12)`.

### 6. Unconditional Jumps
- **JAL (Jump and Link)**: Opcode `7'b1101111` (`7'd111`). Target = `PC + imm`. Link address `PC + 4` stored into `rd`.
- **JALR (Jump and Link Register)**: Opcode `7'b1100111` (`7'd103`). Target = `(rs1 + imm) & ~32'd1`. Link address `PC + 4` stored into `rd`.

---

## Control Logic Unit

The `ControlLogic` module decodes the 7-bit opcode combinational matrix into the core execution control lines:

| Opcode (`opcode[6:0]`) | Instruction Class | `reg_write` | `mem_read` | `mem_write` | `alu_src` | `mem_to_reg` | `branch` | `jump` | `alu_op` |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `7'd51` (`0110011`) | R-Type ALU | `1` | `0` | `0` | `0` (rs2) | `2'b00` | `0` | `0` | `2'b10` |
| `7'd19` (`0010011`) | I-Type ALU | `1` | `0` | `0` | `1` (imm) | `2'b00` | `0` | `0` | `2'b10` |
| `7'd3` (`0000011`) | Load (LW) | `1` | `1` | `0` | `1` (imm) | `2'b01` | `0` | `0` | `2'b00` |
| `7'd35` (`0100011`) | Store (SW) | `0` | `0` | `1` | `1` (imm) | `2'b00` | `0` | `0` | `2'b00` |
| `7'd99` (`1100011`) | Branch (B-Type) | `0` | `0` | `0` | `0` (rs2) | `2'b00` | `1` | `0` | `2'b01` |
| `7'd55` (`0110111`) | LUI | `1` | `0` | `0` | `0` | `2'b11` | `0` | `0` | `2'b11` |
| `7'd23` (`0010111`) | AUIPC | `1` | `0` | `0` | `1` (imm) | `2'b00` | `0` | `0` | `2'b00` |
| `7'd111` (`1101111`) | JAL | `1` | `0` | `0` | `0` | `2'b10` | `0` | `1` | `2'b00` |
| `7'd103` (`1100111`) | JALR | `1` | `0` | `0` | `1` (imm) | `2'b10` | `0` | `1` | `2'b00` |

### Write-Back Multiplexer Encoding
The `mem_to_reg` bus selects the source committed to `rd` in the register file:
- **`2'b01`**: Memory read output (`mem_data_out`) from `dataMemory` (used for `LW`).
- **All other values (`2'b00`, `2'b10`, `2'b11`)**: `alu_out` from `alu.v`, which directly contains:
  - Computed arithmetic/logic result for R-type and I-type (`mem_to_reg == 2'b00`)
  - `PC + 4` return link address for `JAL` and `JALR` (`mem_to_reg == 2'b10`)
  - Upper immediate value for `LUI` (`mem_to_reg == 2'b11`)
  - `PC + imm` address for `AUIPC` (`mem_to_reg == 2'b00`)

---

## Memory Organization

The core employs separate byte-addressable memories for instructions and data:

### Endianness & Byte Swizzling
Both `instructionMemory` and `dataMemory` store bytes in standard **RISC-V Little-Endian** format:
- **Byte 0**: bits `[7:0]` (LSB) at address `A + 0`
- **Byte 1**: bits `[15:8]` at address `A + 1`
- **Byte 2**: bits `[23:16]` at address `A + 2`
- **Byte 3**: bits `[31:24]` (MSB) at address `A + 3`

When reading a 32-bit word, the modules concatenate:
```verilog
data_out <= {memory[address + 3], memory[address + 2], memory[address + 1], memory[address]};
```

### Program Initialization
`instructionMemory.v` automatically loads hex instruction words from `instructions.hex` on simulation start:
```verilog
reg [31:0] temp_mem [0:63];
initial begin
    $readmemh("instructions.hex", temp_mem);
    for (k = 0; k < 64; k = k + 1) begin
        memory[4*k + 0] = temp_mem[k][7:0];
        memory[4*k + 1] = temp_mem[k][15:8];
        memory[4*k + 2] = temp_mem[k][23:16];
        memory[4*k + 3] = temp_mem[k][31:24];
    end
end
```

---

## System Integration (RV32I + AXI + VGA)

The RV32I core exposes direct memory bus monitoring ports on its top-level module:
```verilog
module Datapath (
    input             clk,
    input             reset,
    output     [31:0] pcRegister,
    output     [31:0] mem_addr,
    output     [31:0] mem_wdata,
    output            mem_write,
    output            mem_read
);
```

### Interconnect Architecture
These memory interface signals are mapped into the AXI crossbar decoder (`rtl/bus/axi_decoder.v`) to facilitate communication with peripheral subsystems:

1. **Local Data RAM**: Addresses `0x0000_0000 - 0x0000_00FF` (Core internal).
2. **VGA Control Registers**: Base address `0x4000_0000` (`rtl/vga/vga_registers.v`).
   - Framebuffer base pointers, resolution settings, color mode, status registers.
3. **VGA Framebuffer Memory**: Base address `0x5000_0000` (`rtl/vga/framebuffer_sram.v` via `axi_framebuffer.v`).
   - Dual-port video SRAM allowing the CPU to draw pixels while the VGA timing controller (`vga_timing.v` & `pixel_addr_gen.v`) continuously streams pixels to DAC pins (`rgb_output.v`).

---

## Simulation & Verification

### 1. Generating `instructions.hex`
To execute software on the core, assemble your RISC-V program into 32-bit hexadecimal words:

```assembly
# example.s
_start:
    addi x1, x0, 10       # x1 = 10
    addi x2, x0, 20       # x2 = 20
    add  x3, x1, x2       # x3 = 30
    sw   x3, 0(x0)        # memory[0] = 30
    lw   x4, 0(x0)        # x4 = memory[0]
loop:
    beq  x3, x4, loop     # infinite loop
```

Assemble using the GNU RISC-V Toolchain:
```bash
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 example.s -o example.o
riscv64-unknown-elf-objcopy -O binary example.o example.bin
hexdump -v -e '1/4 "%08x\n"' example.bin > instructions.hex
```

Place `instructions.hex` in the simulation working directory.

### 2. Creating a Testbench
A basic Verilog testbench instantiating `Datapath`:

```verilog
`timescale 1ns / 1ps

module tb_rv32i;
    reg clk;
    reg reset;
    wire [31:0] pc;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire        mem_write;
    wire        mem_read;

    Datapath uut (
        .clk(clk),
        .reset(reset),
        .pcRegister(pc),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_write(mem_write),
        .mem_read(mem_read)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        #20 reset = 0;

        #500;
        $finish;
    end
endmodule
```

### 3. Simulating with Icarus Verilog
Compile and run with `iverilog`:
```bash
iverilog -o sim_rv32i \
    rv32i/Datapath.v \
    rv32i/ProgramCounter.v \
    rv32i/instructionMemory.v \
    rv32i/decoder.v \
    rv32i/ControlLogic.v \
    rv32i/RegFile.v \
    rv32i/alu.v \
    rv32i/RI_alu.v \
    rv32i/bAlu.v \
    rv32i/dataMemory.v \
    tb_rv32i.v

vvp sim_rv32i
```

---

## File Structure

```
rv32i-vga/
├── README.md                  # Project & Core Documentation
├── rv32i/                     # Active Single-Cycle RV32I Processor Core
│   ├── ControlLogic.v         # Main Control Unit (Opcode Decoder)
│   ├── Datapath.v             # Core Top-Level Datapath & Interconnect
│   ├── ProgramCounter.v       # PC Generator (Sequential, Branch, Jump)
│   ├── RegFile.v              # 32x32 General Purpose Register File
│   ├── RI_alu.v               # Register-Immediate & Register-Register ALU
│   ├── alu.v                  # Top ALU & Address/Link Multiplexer
│   ├── bAlu.v                 # Branch Comparison Unit
│   ├── dataMemory.v           # 256-Byte Byte-Addressable RAM
│   ├── decoder.v              # Combinational Decoder & Immediate Generator
│   └── instructionMemory.v    # 256-Byte Byte-Addressable ROM (loads instructions.hex)
├── rtl/
│   ├── bus/
│   │   └── axi_decoder.v      # AXI-4 / AXI-Lite Crossbar Interconnect
│   ├── rv32i/                 # Modular RV32I Development RTL
│   └── vga/                   # Complete Hardware VGA Subsystem
│       ├── axi_framebuffer.v  # AXI Interface to Video Buffer
│       ├── framebuffer_sram.v # Dual-Port Video Memory
│       ├── pixel_addr_gen.v   # Raster Address Generator
│       ├── rgb_output.v       # DAC / Color Output Formatter
│       ├── vga_controller.v   # Subsystem Top-Level Controller
│       ├── vga_registers.v    # Memory-Mapped Video Config Registers
│       └── vga_timing.v       # HSync, VSync & Active Video Generator
└── tb/                        # Testbenches
    ├── axi_decoder_tb.sv      # AXI Bus Interconnect Verification
    ├── vga_registers_tb.v     # VGA Register Interface Verification
    ├── vga_subsystem_tb.sv    # Full VGA Subsystem Testbench
    └── vga_tb.v               # VGA Controller Timing Testbench
```

---

## Authors & License

Developed as part of the **RV32I-VGA SoC Project**.
Licensed under the MIT License.
