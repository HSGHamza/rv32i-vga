## -----------------------------------------------------------------------------
## Digilent Zybo Z7-10 Pin Constraints for RV32I-AXI-VGA SoC
## Target Part: xc7z010clg400-1
## -----------------------------------------------------------------------------

## Clock Signal (125 MHz Onboard Oscillator)
set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clk }];

## Slide Switches (SW0 = Reset, SW1 = AI assist toggle)
set_property -dict { PACKAGE_PIN G15   IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]; # SW0: Reset (Up = Reset, Down = Run)
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]; # SW1: AI Assist Toggle
set_property -dict { PACKAGE_PIN W13   IOSTANDARD LVCMOS33 } [get_ports { sw[2] }]; # SW2: Unused
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { sw[3] }]; # SW3: Unused

## Push Buttons (Paddle Controls)
set_property -dict { PACKAGE_PIN K18   IOSTANDARD LVCMOS33 } [get_ports { btn[0] }]; # BTN0: Left Paddle UP
set_property -dict { PACKAGE_PIN P16   IOSTANDARD LVCMOS33 } [get_ports { btn[1] }]; # BTN1: Left Paddle DOWN
set_property -dict { PACKAGE_PIN K19   IOSTANDARD LVCMOS33 } [get_ports { btn[2] }]; # BTN2: Right Paddle UP
set_property -dict { PACKAGE_PIN Y16   IOSTANDARD LVCMOS33 } [get_ports { btn[3] }]; # BTN3: Right Paddle DOWN

## User Status LEDs
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { led[0] }]; # Active video
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { led[1] }]; # CPU stall
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { led[2] }]; # Memory write
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { led[3] }]; # Heartbeat

## -----------------------------------------------------------------------------
## VGA Output (Single Pmod Port JC: RGB111 1-bit Color Mode, 1-1-1 Cable)
## -----------------------------------------------------------------------------

## Color Channels (1 wire each: Red, Green, Blue)
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { vga_r }];  # JC1  -> Wire to Red
set_property -dict { PACKAGE_PIN W15   IOSTANDARD LVCMOS33 } [get_ports { vga_g }];  # JC2  -> Wire to Green
set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports { vga_b }];  # JC3  -> Wire to Blue

## Synchronization Signals (Horizontal & Vertical Sync)
set_property -dict { PACKAGE_PIN W14   IOSTANDARD LVCMOS33 } [get_ports { vga_hs }]; # JC7  -> Wire to HSync
set_property -dict { PACKAGE_PIN Y14   IOSTANDARD LVCMOS33 } [get_ports { vga_vs }]; # JC8  -> Wire to VSync
