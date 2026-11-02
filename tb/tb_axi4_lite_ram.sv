
`timescale 1ns/1ps

module tb_axi4_lite_ram;

  parameter DATA_WIDTH = 32;
  parameter ADDR_WIDTH = 4;
  parameter CLK_PERIOD = 10;

  reg aclk;
  reg aresetn;

  // Write address channel
  reg  [ADDR_WIDTH-1:0] s_axi_awaddr;
  reg                   s_axi_awvalid;
  wire                  s_axi_awready;

  // Write data channel
  reg  [DATA_WIDTH-1:0] s_axi_wdata;
  reg                   s_axi_wvalid;
  wire                  s_axi_wready;

  // Write response channel
  wire [1:0] s_axi_bresp;
  wire       s_axi_bvalid;
  reg        s_axi_bready;

  // Read address channel
  reg  [ADDR_WIDTH-1:0] s_axi_araddr;
  reg                   s_axi_arvalid;
  wire                  s_axi_arready;

  // Read data channel
  wire [DATA_WIDTH-1:0] s_axi_rdata;
  wire [1:0]            rresp;
  wire                  s_axi_rvalid;
  reg                   s_axi_rready;

  reg [DATA_WIDTH-1:0] read_data;

  // DUT
  axi4_lite_top #(
    .data_width(DATA_WIDTH),
    .addr_width(ADDR_WIDTH)
  ) dut (
    .aclk          (aclk),
    .aresetn       (aresetn),

    .s_axi_awaddr  (s_axi_awaddr),
    .s_axi_awvalid (s_axi_awvalid),
    .s_axi_awready (s_axi_awready),

    .s_axi_wdata   (s_axi_wdata),
    .s_axi_wvalid  (s_axi_wvalid),
    .s_axi_wready  (s_axi_wready),

    .s_axi_bresp   (s_axi_bresp),
    .s_axi_bvalid  (s_axi_bvalid),
    .s_axi_bready  (s_axi_bready),

    .s_axi_araddr  (s_axi_araddr),
    .s_axi_arvalid (s_axi_arvalid),
    .s_axi_arready (s_axi_arready),

    .s_axi_rdata   (s_axi_rdata),
    .rresp         (rresp),
    .s_axi_rvalid  (s_axi_rvalid),
    .s_axi_rready  (s_axi_rready)
  );

  // Clock generation
  initial begin
    aclk = 1'b0;
    forever #(CLK_PERIOD/2) aclk = ~aclk;
  end

  // Write transaction
  task axi_write;
    input [ADDR_WIDTH-1:0] addr;
    input [DATA_WIDTH-1:0] data;
    integer timeout;
    begin
      @(negedge aclk);
      s_axi_awaddr  = addr;
      s_axi_awvalid = 1'b1;
      timeout = 0;

      // Wait for AW handshake
      do begin
        @(posedge aclk);
        timeout = timeout + 1;
        if (timeout > 100)
          $fatal(1, "Timeout waiting for AWREADY");
      end while (!s_axi_awready);

      @(negedge aclk);
      s_axi_awvalid = 1'b0;
      s_axi_wdata   = data;
      s_axi_wvalid  = 1'b1;
      timeout = 0;

      // Wait for W handshake
      do begin
        @(posedge aclk);
        timeout = timeout + 1;
        if (timeout > 100)
          $fatal(1, "Timeout waiting for WREADY");
      end while (!s_axi_wready);

      @(negedge aclk);
      s_axi_wvalid = 1'b0;
      s_axi_bready = 1'b1;
      timeout = 0;

      // Wait for B response
      do begin
        @(posedge aclk);
        timeout = timeout + 1;
        if (timeout > 100)
          $fatal(1, "Timeout waiting for BVALID");
      end while (!s_axi_bvalid);

      if (s_axi_bresp !== 2'b00)
        $error("Unexpected BRESP: %b", s_axi_bresp);

      @(negedge aclk);
      s_axi_bready = 1'b0;

      $display("[WRITE] addr=%h data=%h",
               addr, data);
    end
  endtask

  // Read transaction
  task axi_read;
    input  [ADDR_WIDTH-1:0] addr;
    output [DATA_WIDTH-1:0] data;
    integer timeout;
    begin
      @(negedge aclk);
      s_axi_araddr  = addr;
      s_axi_arvalid = 1'b1;
      timeout = 0;

      // Wait for AR handshake
      do begin
        @(posedge aclk);
        timeout = timeout + 1;
        if (timeout > 100)
          $fatal(1, "Timeout waiting for ARREADY");
      end while (!s_axi_arready);

      @(negedge aclk);
      s_axi_arvalid = 1'b0;
      s_axi_rready  = 1'b1;
      timeout = 0;

      // Wait for R response
      do begin
        @(posedge aclk);
        timeout = timeout + 1;
        if (timeout > 100)
          $fatal(1, "Timeout waiting for RVALID");
      end while (!s_axi_rvalid);

      data = s_axi_rdata;

      @(negedge aclk);
      s_axi_rready = 1'b0;

      $display("[READ]  addr=%h data=%h",
               addr, data);
    end
  endtask

  // Reset and tests
  initial begin
    aresetn       = 1'b0;
    s_axi_awaddr  = 0;
    s_axi_awvalid = 0;
    s_axi_wdata   = 0;
    s_axi_wvalid  = 0;
    s_axi_bready  = 0;
    s_axi_araddr  = 0;
    s_axi_arvalid = 0;
    s_axi_rready  = 0;
    read_data     = 0;

    repeat (5) @(negedge aclk);
    aresetn = 1'b1;

    $display("=== AXI4-Lite RAM test started ===");

    axi_write(4'h4, 32'hDEADBEEF);
    axi_read (4'h4, read_data);

    if (read_data !== 32'hDEADBEEF)
      $error("TEST FAILED: expected DEADBEEF, got %h",
             read_data);
    else
      $display("TEST PASSED: address 4");

    axi_write(4'h8, 32'h12345678);
    axi_read (4'h8, read_data);

    if (read_data !== 32'h12345678)
      $error("TEST FAILED: expected 12345678, got %h",
             read_data);
    else
      $display("TEST PASSED: address 8");

    $display("=== Test sequence completed ===");
    $finish;
  end

endmodule
