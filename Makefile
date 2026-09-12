SHELL := /bin/bash

# F4PGA Open-Source FPGA Toolchain Configuration
F4PGA_INSTALL_DIR ?= /home/cl4/opt/f4pga
FPGA_FAM          ?= xc7
PART              ?= xc7z010clg400-1
DEVICE_ARCH       ?= xc7z010_test
BOARD             ?= zybo_z7_10

BUILD_DIR         := build/zybo
BITSTREAM         := $(BUILD_DIR)/zybo_top.bit
FASM              := $(BUILD_DIR)/zybo_top.fasm
EBLIF             := $(BUILD_DIR)/zybo_top.eblif
NET               := $(BUILD_DIR)/zybo_top.net
SDC               := $(BUILD_DIR)/zybo_top.sdc
XDC               := constraints/zybo_z7_10.xdc

# Source Files
VERILOG_SRCS := \
	rtl/fpga/zybo_top.v \
	rtl/soc_top.v \
	rtl/rv32i/ControlLogic.v \
	rtl/rv32i/Datapath.v \
	rtl/rv32i/ProgramCounter.v \
	rtl/rv32i/RI_alu.v \
	rtl/rv32i/RegFile.v \
	rtl/rv32i/alu.v \
	rtl/rv32i/bAlu.v \
	rtl/rv32i/dataMemory.v \
	rtl/rv32i/decoder.v \
	rtl/rv32i/instructionMemory.v \
	rtl/bus/rv32i_axi_bridge.v \
	rtl/bus/axi_decoder.v \
	rtl/bus/axi_data_memory.v \
	rtl/vga/vga_registers.v \
	rtl/vga/vga_controller.v \
	rtl/vga/vga_timing.v \
	rtl/vga/pixel_addr_gen.v \
	rtl/vga/rgb_output.v \
	rtl/vga/framebuffer_sram.v

ENV_ACTIVATE := export F4PGA_INSTALL_DIR=$(F4PGA_INSTALL_DIR) && export FPGA_FAM=$(FPGA_FAM) && source $(F4PGA_INSTALL_DIR)/$(FPGA_FAM)/conda/etc/profile.d/conda.sh && conda activate $(FPGA_FAM)

.PHONY: all bitstream synth pack place route fasm prog sim clean help \
        uvm_compile uvm_sanity uvm_unmapped uvm_random uvm_concurrent uvm_all

all: bitstream

help:
	@echo "========================================================================"
	@echo " RV32I-VGA SoC Build System (Digilent Zybo Z7-10)"
	@echo "========================================================================"
	@echo " make bitstream     : Run full F4PGA flow and generate build/zybo/zybo_top.bit"
	@echo " make prog          : Flash bitstream to Zybo Z7-10 via openFPGALoader"
	@echo " make sim           : Run QuestaSim end-to-end SoC simulation"
	@echo " make uvm_compile   : Compile UVM VIP, Environment, Tests, and Top"
	@echo " make uvm_sanity    : Run UVM directed sanity test"
	@echo " make uvm_unmapped  : Run UVM unmapped address error slave test"
	@echo " make uvm_random    : Run UVM constrained-random stress test"
	@echo " make uvm_concurrent: Run UVM concurrent back-to-back burst test"
	@echo " make uvm_all       : Run complete UVM test suite"
	@echo " make clean         : Remove build artifacts"
	@echo "========================================================================"

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
	cp instructions.hex $(BUILD_DIR)/instructions.hex

synth: $(EBLIF)

$(EBLIF): $(VERILOG_SRCS) $(XDC) instructions.hex | $(BUILD_DIR)
	@echo ">>> [1/5] Synthesizing design with symbiflow_synth..."
	cp instructions.hex $(BUILD_DIR)/instructions.hex
	cd $(BUILD_DIR) && $(ENV_ACTIVATE) && symbiflow_synth \
		-t zybo_top \
		-v $(addprefix ../../, $(VERILOG_SRCS)) \
		-d zynq7 \
		-p $(PART) \
		-x ../../$(XDC)

pack: $(NET)

$(NET): $(EBLIF)
	@echo ">>> [2/5] Packing logic with symbiflow_pack..."
	cd $(BUILD_DIR) && $(ENV_ACTIVATE) && symbiflow_pack \
		-e zybo_top.eblif \
		-d $(DEVICE_ARCH) \
		-s zybo_top.sdc \
		-P $(PART)

place: $(BUILD_DIR)/zybo_top.place

$(BUILD_DIR)/zybo_top.place: $(NET)
	@echo ">>> [3/5] Placing blocks with symbiflow_place..."
	cd $(BUILD_DIR) && $(ENV_ACTIVATE) && symbiflow_place \
		-e zybo_top.eblif \
		-d $(DEVICE_ARCH) \
		-n zybo_top.net \
		-P $(PART) \
		-s zybo_top.sdc

route: $(BUILD_DIR)/zybo_top.route

$(BUILD_DIR)/zybo_top.route: $(BUILD_DIR)/zybo_top.place
	@echo ">>> [4/5] Routing connections with symbiflow_route..."
	cd $(BUILD_DIR) && $(ENV_ACTIVATE) && symbiflow_route \
		-e zybo_top.eblif \
		-d $(DEVICE_ARCH) \
		-s zybo_top.sdc \
		-P $(PART)

fasm: $(FASM)

$(FASM): $(BUILD_DIR)/zybo_top.route
	@echo ">>> [5/6] Generating FASM configuration with symbiflow_write_fasm..."
	cd $(BUILD_DIR) && $(ENV_ACTIVATE) && symbiflow_write_fasm \
		-e zybo_top.eblif \
		-d $(DEVICE_ARCH) \
		-s zybo_top.sdc \
		-P $(PART)

bitstream: $(BITSTREAM)

$(BITSTREAM): $(FASM)
	@echo ">>> [6/6] Assembling bitstream with symbiflow_write_bitstream..."
	cd $(BUILD_DIR) && $(ENV_ACTIVATE) && symbiflow_write_bitstream \
		-d zynq7 \
		-p $(PART) \
		-f zybo_top.fasm \
		-b zybo_top.bit
	@echo "SUCCESS: Bitstream created at $(BITSTREAM)"
	@ls -lh $(BITSTREAM)

prog: $(BITSTREAM)
	@echo "Flashing Zybo Z7-10 via openFPGALoader..."
	$(ENV_ACTIVATE) && openFPGALoader -b $(BOARD) $(BITSTREAM)

sim:
	vlib work
	vlog -sv \
		+incdir+rtl/rv32i \
		+incdir+rtl/bus \
		+incdir+rtl/vga \
		rtl/rv32i/*.v \
		rtl/bus/*.v \
		rtl/vga/*.v \
		rtl/soc_top.v \
		tb/soc_top_tb.sv
	vsim -c -do "run 200us; quit -f" soc_top_tb

# -----------------------------------------------------------------------------
# UVM Verification Suite
# -----------------------------------------------------------------------------
UVM_SRCS := \
	rtl/bus/axi_decoder.v \
	rtl/bus/axi_data_memory.v \
	rtl/vga/vga_registers.v \
	rtl/vga/framebuffer_sram.v \
	tb/uvm/vip/axi_lite/axi_lite_types.sv \
	tb/uvm/vip/axi_lite/axi_lite_if.sv \
	tb/uvm/vip/axi_lite/axi_lite_pkg.sv \
	tb/uvm/env/axi_decoder_env_pkg.sv \
	tb/uvm/tests/axi_decoder_test_pkg.sv \
	tb/uvm/tb_top.sv

UVM_INCDIRS := \
	+incdir+rtl/bus \
	+incdir+rtl/vga \
	+incdir+tb/uvm/vip/axi_lite \
	+incdir+tb/uvm/env \
	+incdir+tb/uvm/tests

uvm_compile:
	@mkdir -p work
	vlib work
	vlog -sv $(UVM_INCDIRS) $(UVM_SRCS)

uvm_sanity: uvm_compile
	vsim -c -do "run -all; quit -f" +UVM_TESTNAME=axi_decoder_sanity_test tb_top

uvm_unmapped: uvm_compile
	vsim -c -do "run -all; quit -f" +UVM_TESTNAME=axi_decoder_unmapped_test tb_top

uvm_random: uvm_compile
	vsim -c -do "run -all; quit -f" +UVM_TESTNAME=axi_decoder_random_test tb_top

uvm_concurrent: uvm_compile
	vsim -c -do "run -all; quit -f" +UVM_TESTNAME=axi_decoder_concurrent_test tb_top

uvm_all: uvm_compile uvm_sanity uvm_unmapped uvm_random uvm_concurrent
	@echo "========================================================================"
	@echo "  ALL UVM VERIFICATION TESTS COMPLETED SUCCESSFULLY!                    "
	@echo "========================================================================"

clean:
	rm -rf $(BUILD_DIR) work transcript *.wlf
