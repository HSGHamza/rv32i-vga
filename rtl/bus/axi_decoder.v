`timescale 1ns / 1ps

module axi_decoder #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32
)(
    input  wire                          clk,
    input  wire                          rst,

    // =========================================================================
    // Master Interface (Connected to RV32I CPU AXI4-Lite Master)
    // =========================================================================
    // Write Address Channel
    input  wire [AXI_ADDR_WIDTH-1:0]     m_axi_awaddr,
    input  wire                          m_axi_awvalid,
    output wire                          m_axi_awready,

    // Write Data Channel
    input  wire [AXI_DATA_WIDTH-1:0]     m_axi_wdata,
    input  wire [AXI_DATA_WIDTH/8-1:0]   m_axi_wstrb,
    input  wire                          m_axi_wvalid,
    output wire                          m_axi_wready,

    // Write Response Channel
    output wire [1:0]                    m_axi_bresp,
    output wire                          m_axi_bvalid,
    input  wire                          m_axi_bready,

    // Read Address Channel
    input  wire [AXI_ADDR_WIDTH-1:0]     m_axi_araddr,
    input  wire                          m_axi_arvalid,
    output wire                          m_axi_arready,

    // Read Data Channel
    output wire [AXI_DATA_WIDTH-1:0]     m_axi_rdata,
    output wire [1:0]                    m_axi_rresp,
    output wire                          m_axi_rvalid,
    input  wire                          m_axi_rready,

    // =========================================================================
    // Slave 0 Interface: Data SRAM (Reserved / Future Integration)
    // =========================================================================
    output wire [AXI_ADDR_WIDTH-1:0]     s0_axi_awaddr,
    output wire                          s0_axi_awvalid,
    input  wire                          s0_axi_awready,

    output wire [AXI_DATA_WIDTH-1:0]     s0_axi_wdata,
    output wire [AXI_DATA_WIDTH/8-1:0]   s0_axi_wstrb,
    output wire                          s0_axi_wvalid,
    input  wire                          s0_axi_wready,

    input  wire [1:0]                    s0_axi_bresp,
    input  wire                          s0_axi_bvalid,
    output wire                          s0_axi_bready,

    output wire [AXI_ADDR_WIDTH-1:0]     s0_axi_araddr,
    output wire                          s0_axi_arvalid,
    input  wire                          s0_axi_arready,

    input  wire [AXI_DATA_WIDTH-1:0]     s0_axi_rdata,
    input  wire [1:0]                    s0_axi_rresp,
    input  wire                          s0_axi_rvalid,
    output wire                          s0_axi_rready,

    // =========================================================================
    // Slave 1 Interface: VGA Subsystem (vga_registers)
    // =========================================================================
    output wire [AXI_ADDR_WIDTH-1:0]     s1_axi_awaddr,
    output wire                          s1_axi_awvalid,
    input  wire                          s1_axi_awready,

    output wire [AXI_DATA_WIDTH-1:0]     s1_axi_wdata,
    output wire [AXI_DATA_WIDTH/8-1:0]   s1_axi_wstrb,
    output wire                          s1_axi_wvalid,
    input  wire                          s1_axi_wready,

    input  wire [1:0]                    s1_axi_bresp,
    input  wire                          s1_axi_bvalid,
    output wire                          s1_axi_bready,

    output wire [AXI_ADDR_WIDTH-1:0]     s1_axi_araddr,
    output wire                          s1_axi_arvalid,
    input  wire                          s1_axi_arready,

    input  wire [AXI_DATA_WIDTH-1:0]     s1_axi_rdata,
    input  wire [1:0]                    s1_axi_rresp,
    input  wire                          s1_axi_rvalid,
    output wire                          s1_axi_rready
);

    // -------------------------------------------------------------------------
    // AXI Standard Response Codes
    // -------------------------------------------------------------------------
    localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;

    // -------------------------------------------------------------------------
    // Slave Target Enumeration
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        TARGET_UNMAPPED = 2'b00,
        TARGET_SLAVE0   = 2'b01,  // Data SRAM (Future)
        TARGET_SLAVE1   = 2'b10   // VGA Subsystem (vga_registers)
    } target_slave_t;

    // -------------------------------------------------------------------------
    // Address Decoding Logic
    // -------------------------------------------------------------------------
    // Region A: VGA MMIO Registers (0x1000_0000 - 0x1000_000F)
    // Region B: Framebuffer CPU Window (0x5000_0000 - 0x5012_BFFF)
    function automatic target_slave_t decode_address(input [31:0] addr);
        // ======================================================
        // TODO: SLAVE 0 - DATA SRAM
        //
        // Data SRAM and its address range will be implemented later.
        // Future logic:
        //   if ((addr >= DATA_SRAM_BASE) && (addr <= DATA_SRAM_END))
        //       return TARGET_SLAVE0;
        // ======================================================

        // Slave 1: VGA Subsystem (MMIO Registers + Framebuffer Range)
        if (((addr >= 32'h1000_0000) && (addr <= 32'h1000_000F)) ||
            ((addr >= 32'h5000_0000) && (addr <= 32'h5012_BFFF))) begin
            return TARGET_SLAVE1;
        end

        // Unmapped Address Space
        return TARGET_UNMAPPED;
    endfunction

    // -------------------------------------------------------------------------
    // Write Channel Buffers & State Machine
    // Handles AW and W channel independence (AW first, W first, or concurrent)
    // -------------------------------------------------------------------------
    reg [AXI_ADDR_WIDTH-1:0]     awaddr_reg;
    reg [AXI_DATA_WIDTH-1:0]     wdata_reg;
    reg [AXI_DATA_WIDTH/8-1:0]   wstrb_reg;
    reg                          aw_latched;
    reg                          w_latched;
    target_slave_t               wr_target_owner;

    typedef enum logic [2:0] {
        WR_IDLE       = 3'b000,
        WR_ROUTE_S1   = 3'b001,
        WR_ROUTE_S0   = 3'b010,
        WR_WAIT_RESP  = 3'b011,
        WR_UNMAPPED   = 3'b100
    } wr_state_t;

    wr_state_t wr_state;

    // Effective write signals to eliminate 1-cycle latency when arriving together
    wire [AXI_ADDR_WIDTH-1:0]   eff_awaddr = aw_latched ? awaddr_reg : m_axi_awaddr;
    wire [AXI_DATA_WIDTH-1:0]   eff_wdata  = w_latched  ? wdata_reg  : m_axi_wdata;
    wire [AXI_DATA_WIDTH/8-1:0] eff_wstrb  = w_latched  ? wstrb_reg  : m_axi_wstrb;

    // Master AWREADY and WREADY handshake controls
    assign m_axi_awready = (wr_state == WR_IDLE) && !aw_latched;
    assign m_axi_wready  = (wr_state == WR_IDLE) && !w_latched;

    // Slave 1 Write Channels Routing
    reg s1_awvalid_reg, s1_wvalid_reg;
    assign s1_axi_awaddr  = eff_awaddr;
    assign s1_axi_awvalid = (wr_state == WR_ROUTE_S1) ? s1_awvalid_reg : 1'b0;
    assign s1_axi_wdata   = eff_wdata;
    assign s1_axi_wstrb   = eff_wstrb;
    assign s1_axi_wvalid  = (wr_state == WR_ROUTE_S1) ? s1_wvalid_reg  : 1'b0;
    assign s1_axi_bready  = (wr_state == WR_WAIT_RESP && wr_target_owner == TARGET_SLAVE1) ? m_axi_bready : 1'b0;

    // Slave 0 Write Channels (Reserved / Tied-off)
    assign s0_axi_awaddr  = eff_awaddr;
    assign s0_axi_awvalid = 1'b0;
    assign s0_axi_wdata   = eff_wdata;
    assign s0_axi_wstrb   = eff_wstrb;
    assign s0_axi_wvalid  = 1'b0;
    assign s0_axi_bready  = 1'b0;

    // Master Write Response Routing
    reg        unmapped_bvalid_reg;
    reg [1:0]  unmapped_bresp_reg;

    assign m_axi_bvalid = (wr_state == WR_WAIT_RESP && wr_target_owner == TARGET_SLAVE1) ? s1_axi_bvalid :
                          (wr_state == WR_WAIT_RESP && wr_target_owner == TARGET_SLAVE0) ? s0_axi_bvalid :
                          (wr_state == WR_UNMAPPED)                                      ? unmapped_bvalid_reg : 1'b0;

    assign m_axi_bresp  = (wr_state == WR_WAIT_RESP && wr_target_owner == TARGET_SLAVE1) ? s1_axi_bresp :
                          (wr_state == WR_WAIT_RESP && wr_target_owner == TARGET_SLAVE0) ? s0_axi_bresp :
                          (wr_state == WR_UNMAPPED)                                      ? unmapped_bresp_reg : AXI_RESP_SLVERR;

    // Write FSM
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            awaddr_reg          <= '0;
            wdata_reg           <= '0;
            wstrb_reg           <= '0;
            aw_latched          <= 1'b0;
            w_latched           <= 1'b0;
            wr_target_owner     <= TARGET_UNMAPPED;
            s1_awvalid_reg      <= 1'b0;
            s1_wvalid_reg       <= 1'b0;
            unmapped_bvalid_reg <= 1'b0;
            unmapped_bresp_reg  <= AXI_RESP_OKAY;
            wr_state            <= WR_IDLE;
        end else begin
            // Latch Master Write Address
            if (m_axi_awvalid && m_axi_awready) begin
                awaddr_reg <= m_axi_awaddr;
                aw_latched <= 1'b1;
            end

            // Latch Master Write Data
            if (m_axi_wvalid && m_axi_wready) begin
                wdata_reg <= m_axi_wdata;
                wstrb_reg <= m_axi_wstrb;
                w_latched <= 1'b1;
            end

            case (wr_state)
                WR_IDLE: begin
                    // Once both AW and W are available (either latched or live handshaking)
                    if ((aw_latched || (m_axi_awvalid && m_axi_awready)) &&
                        (w_latched  || (m_axi_wvalid  && m_axi_wready))) begin
                        
                        target_slave_t decoded_target;
                        decoded_target  = decode_address(eff_awaddr);
                        wr_target_owner <= decoded_target;

                        if (decoded_target == TARGET_SLAVE1) begin
                            s1_awvalid_reg <= 1'b1;
                            s1_wvalid_reg  <= 1'b1;
                            wr_state       <= WR_ROUTE_S1;
                        end else if (decoded_target == TARGET_SLAVE0) begin
                            // Future Slave 0 Routing
                            wr_state <= WR_ROUTE_S0;
                        end else begin
                            // Unmapped Address: Generate AXI SLVERR
                            unmapped_bvalid_reg <= 1'b1;
                            unmapped_bresp_reg  <= AXI_RESP_SLVERR;
                            wr_state            <= WR_UNMAPPED;
                        end
                    end
                end

                WR_ROUTE_S1: begin
                    // Handshake downstream slave channels independently
                    if (s1_axi_awready && s1_awvalid_reg) begin
                        s1_awvalid_reg <= 1'b0;
                    end
                    if (s1_axi_wready && s1_wvalid_reg) begin
                        s1_wvalid_reg <= 1'b0;
                    end

                    // Once both downstream handshakes complete, wait for response
                    if ((!s1_awvalid_reg || s1_axi_awready) &&
                        (!s1_wvalid_reg  || s1_axi_wready)) begin
                        wr_state <= WR_WAIT_RESP;
                    end
                end

                WR_ROUTE_S0: begin
                    // Reserved for Slave 0
                    wr_state <= WR_WAIT_RESP;
                end

                WR_WAIT_RESP: begin
                    // Hold transaction until CPU master completes B handshake
                    if (m_axi_bvalid && m_axi_bready) begin
                        aw_latched <= 1'b0;
                        w_latched  <= 1'b0;
                        wr_state   <= WR_IDLE;
                    end
                end

                WR_UNMAPPED: begin
                    if (unmapped_bvalid_reg && m_axi_bready) begin
                        unmapped_bvalid_reg <= 1'b0;
                        aw_latched          <= 1'b0;
                        w_latched           <= 1'b0;
                        wr_state            <= WR_IDLE;
                    end
                end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Read Channel Buffers & State Machine
    // -------------------------------------------------------------------------
    reg [AXI_ADDR_WIDTH-1:0] araddr_reg;
    target_slave_t           rd_target_owner;

    typedef enum logic [2:0] {
        RD_IDLE       = 3'b000,
        RD_ROUTE_S1   = 3'b001,
        RD_ROUTE_S0   = 3'b010,
        RD_WAIT_RESP  = 3'b011,
        RD_UNMAPPED   = 3'b100
    } rd_state_t;

    rd_state_t rd_state;

    assign m_axi_arready = (rd_state == RD_IDLE);

    // Slave 1 Read Channel
    reg s1_arvalid_reg;
    assign s1_axi_araddr  = araddr_reg;
    assign s1_axi_arvalid = (rd_state == RD_ROUTE_S1) ? s1_arvalid_reg : 1'b0;
    assign s1_axi_rready  = (rd_state == RD_WAIT_RESP && rd_target_owner == TARGET_SLAVE1) ? m_axi_rready : 1'b0;

    // Slave 0 Read Channel (Reserved / Tied-off)
    assign s0_axi_araddr  = araddr_reg;
    assign s0_axi_arvalid = 1'b0;
    assign s0_axi_rready  = 1'b0;

    // Master Read Data Routing
    reg        unmapped_rvalid_reg;
    reg [1:0]  unmapped_rresp_reg;
    reg [31:0] unmapped_rdata_reg;

    assign m_axi_rvalid = (rd_state == RD_WAIT_RESP && rd_target_owner == TARGET_SLAVE1) ? s1_axi_rvalid :
                          (rd_state == RD_WAIT_RESP && rd_target_owner == TARGET_SLAVE0) ? s0_axi_rvalid :
                          (rd_state == RD_UNMAPPED)                                      ? unmapped_rvalid_reg : 1'b0;

    assign m_axi_rdata  = (rd_state == RD_WAIT_RESP && rd_target_owner == TARGET_SLAVE1) ? s1_axi_rdata :
                          (rd_state == RD_WAIT_RESP && rd_target_owner == TARGET_SLAVE0) ? s0_axi_rdata :
                          (rd_state == RD_UNMAPPED)                                      ? unmapped_rdata_reg : 32'd0;

    assign m_axi_rresp  = (rd_state == RD_WAIT_RESP && rd_target_owner == TARGET_SLAVE1) ? s1_axi_rresp :
                          (rd_state == RD_WAIT_RESP && rd_target_owner == TARGET_SLAVE0) ? s0_axi_rresp :
                          (rd_state == RD_UNMAPPED)                                      ? unmapped_rresp_reg : AXI_RESP_SLVERR;

    // Read FSM
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            araddr_reg          <= '0;
            rd_target_owner     <= TARGET_UNMAPPED;
            s1_arvalid_reg      <= 1'b0;
            unmapped_rvalid_reg <= 1'b0;
            unmapped_rresp_reg  <= AXI_RESP_OKAY;
            unmapped_rdata_reg  <= 32'd0;
            rd_state            <= RD_IDLE;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        target_slave_t decoded_target;
                        araddr_reg     <= m_axi_araddr;
                        decoded_target  = decode_address(m_axi_araddr);
                        rd_target_owner <= decoded_target;

                        if (decoded_target == TARGET_SLAVE1) begin
                            s1_arvalid_reg <= 1'b1;
                            rd_state       <= RD_ROUTE_S1;
                        end else if (decoded_target == TARGET_SLAVE0) begin
                            // Future Slave 0 Routing
                            rd_state <= RD_ROUTE_S0;
                        end else begin
                            // Unmapped Address: Return SLVERR with 0 data
                            unmapped_rvalid_reg <= 1'b1;
                            unmapped_rresp_reg  <= AXI_RESP_SLVERR;
                            unmapped_rdata_reg  <= 32'h0000_0000;
                            rd_state            <= RD_UNMAPPED;
                        end
                    end
                end

                RD_ROUTE_S1: begin
                    if (s1_axi_arready && s1_arvalid_reg) begin
                        s1_arvalid_reg <= 1'b0;
                        rd_state       <= RD_WAIT_RESP;
                    end
                end

                RD_ROUTE_S0: begin
                    // Reserved for Slave 0
                    rd_state <= RD_WAIT_RESP;
                end

                RD_WAIT_RESP: begin
                    // Hold until master completes R handshake
                    if (m_axi_rvalid && m_axi_rready) begin
                        rd_state <= RD_IDLE;
                    end
                end

                RD_UNMAPPED: begin
                    if (unmapped_rvalid_reg && m_axi_rready) begin
                        unmapped_rvalid_reg <= 1'b0;
                        rd_state            <= RD_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
