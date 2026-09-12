`timescale 1ns / 1ps

`ifndef AXI_LITE_TYPES_SV
`define AXI_LITE_TYPES_SV

package axi_lite_types_pkg;

  // AXI4-Lite Transaction Type
  typedef enum bit {
    AXI_READ  = 1'b0,
    AXI_WRITE = 1'b1
  } axi_op_e;

  // AXI4-Lite Standard Response Codes
  typedef enum bit [1:0] {
    AXI_RESP_OKAY   = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11
  } axi_resp_e;

  // Target Memory Region for Verification
  typedef enum {
    REGION_DATA_MEM,     // 0x0000_0000 - 0x0000_00FF
    REGION_VGA_REG,      // 0x1000_0000 - 0x1000_001F
    REGION_FRAMEBUFFER,  // 0x5000_0000 - 0x5012_BFFF
    REGION_UNMAPPED      // Invalid/Hole addresses
  } axi_region_e;

endpackage : axi_lite_types_pkg

`endif // AXI_LITE_TYPES_SV
