
`include "ram_design.sv"

module axi4_lite_top #(
    parameter data_width = 32,
    parameter addr_width = 4,
    parameter width      = 16
)(
    input  wire aclk,
    input  wire aresetn,

    // Write address channel
    input  wire [addr_width-1:0] s_axi_awaddr,
    input  wire                 s_axi_awvalid,
    output reg                  s_axi_awready,

    // Write data channel
    input  wire [data_width-1:0] s_axi_wdata,
    input  wire                  s_axi_wvalid,
    output reg                   s_axi_wready,

    // Write response channel
    output reg [1:0] s_axi_bresp,
    output reg       s_axi_bvalid,
    input  wire      s_axi_bready,

    // Read data channel
    output reg [data_width-1:0] s_axi_rdata,
    output reg [1:0]            rresp,
    output reg                  s_axi_rvalid,
    input  wire                 s_axi_rready,

    // Read address channel
    input  wire [addr_width-1:0] s_axi_araddr,
    input  wire                  s_axi_arvalid,
    output reg                   s_axi_arready
);

    // AXI response codes
    localparam [1:0] RESP_OKAY = 2'b00;

    // Controller states
    localparam [2:0] IDLE        = 3'b000;
    localparam [2:0] WRITE_EXEC  = 3'b001;
    localparam [2:0] WRITE_RESP  = 3'b010;
    localparam [2:0] READ_ACCESS = 3'b011;
    localparam [2:0] READ_CAPTURE= 3'b100;
    localparam [2:0] READ_RESP   = 3'b101;

    reg [2:0] state;

    // Buffered AXI request information
    reg [addr_width-1:0] write_addr_reg;
    reg [data_width-1:0] write_data_reg;
    reg [addr_width-1:0] read_addr_reg;

    reg aw_pending;
    reg w_pending;
    reg ar_pending;

    // RAM interface
    reg  [addr_width-1:0] ram_addr;
    wire [data_width-1:0] ram_rdata;
    wire                  ram_write_enable;

    // Write to RAM only during WRITE_EXEC.
    assign ram_write_enable = (state == WRITE_EXEC);

    ram_design #(
        .addr_width (addr_width),
        .data_width (data_width),
        .depth      (width)
    ) ram_inst (
        .clk   (aclk),
        .rst_n (aresetn),
        .wr_enb(ram_write_enable),
        .addr  (ram_addr),
        .wdata (write_data_reg),
        .rdata (ram_rdata)
    );

    // ------------------------------------------------
    // AXI READY signals
    // ------------------------------------------------
    // One buffered request per address/data channel.
    // Reset is active-low.

    always @(*) begin
        s_axi_awready = 1'b0;
        s_axi_wready  = 1'b0;
        s_axi_arready = 1'b0;

        if (aresetn) begin
            s_axi_awready = !aw_pending;
            s_axi_wready  = !w_pending;
            s_axi_arready = !ar_pending && !s_axi_rvalid;
        end
    end

    // ------------------------------------------------
    // Capture write address and write data independently
    // ------------------------------------------------
    // AXI allows AW and W to arrive in different cycles.

    always @(posedge aclk) begin
        if (!aresetn) begin
            write_addr_reg <= {addr_width{1'b0}};
            write_data_reg <= {data_width{1'b0}};
            aw_pending     <= 1'b0;
            w_pending      <= 1'b0;
        end
        else begin

            // Accept write address
            if (s_axi_awvalid && s_axi_awready) begin
                write_addr_reg <= s_axi_awaddr;
                aw_pending     <= 1'b1;
            end

            // Accept write data
            if (s_axi_wvalid && s_axi_wready) begin
                write_data_reg <= s_axi_wdata;
                w_pending      <= 1'b1;
            end

            // Consume the buffered request when executing
            // the RAM write. READY is low while pending,
            // so a new request cannot overwrite this one.
            if (state == WRITE_EXEC) begin
                aw_pending <= 1'b0;
                w_pending  <= 1'b0;
            end
        end
    end

    // ------------------------------------------------
    // Capture read address
    // ------------------------------------------------

    always @(posedge aclk) begin
        if (!aresetn) begin
            read_addr_reg <= {addr_width{1'b0}};
            ar_pending    <= 1'b0;
        end
        else begin
            if (s_axi_arvalid && s_axi_arready) begin
                read_addr_reg <= s_axi_araddr;
                ar_pending    <= 1'b1;
            end

            if (state == READ_ACCESS) begin
                ar_pending <= 1'b0;
            end
        end
    end

    // ------------------------------------------------
    // Shared RAM address selection
    // ------------------------------------------------
    // The RAM is single-port, so only one operation can
    // access it at a time.

    always @(*) begin
        ram_addr = {addr_width{1'b0}};

        case (state)
            WRITE_EXEC:  ram_addr = write_addr_reg;
            READ_ACCESS: ram_addr = read_addr_reg;
            default:     ram_addr = {addr_width{1'b0}};
        endcase
    end

    // ------------------------------------------------
    // Main transaction controller
    // ------------------------------------------------

    always @(posedge aclk) begin
        if (!aresetn) begin
            state <= IDLE;
        end
        else begin
            case (state)

                IDLE: begin
                    // Give a complete write request priority
                    // over a pending read request.
                    if (aw_pending && w_pending)
                        state <= WRITE_EXEC;
                    else if (ar_pending)
                        state <= READ_ACCESS;
                end

                WRITE_EXEC: begin
                    // RAM samples address and data on this
                    // clock edge, then generate write response.
                    state <= WRITE_RESP;
                end

                WRITE_RESP: begin
                    // Keep response state until accepted.
                    if (s_axi_bvalid && s_axi_bready)
                        state <= IDLE;
                end

                READ_ACCESS: begin
                    // Synchronous RAM performs the read
                    // on this clock edge.
                    state <= READ_CAPTURE;
                end

                READ_CAPTURE: begin
                    // Capture RAM output on the next edge.
                    state <= READ_RESP;
                end

                READ_RESP: begin
                    // Keep response state until accepted.
                    if (s_axi_rvalid && s_axi_rready)
                        state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

    // ------------------------------------------------
    // Write response channel (B)
    // ------------------------------------------------

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= RESP_OKAY;
        end
        else begin
            if (state == WRITE_RESP && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= RESP_OKAY;
            end
            else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // ------------------------------------------------
    // Read response channel (R)
    // ------------------------------------------------

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axi_rdata  <= {data_width{1'b0}};
            rresp        <= RESP_OKAY;
            s_axi_rvalid <= 1'b0;
        end
        else begin
            // RAM output is available after READ_ACCESS.
            if (state == READ_CAPTURE && !s_axi_rvalid) begin
                s_axi_rdata  <= ram_rdata;
                rresp        <= RESP_OKAY;
                s_axi_rvalid <= 1'b1;
            end
            else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
