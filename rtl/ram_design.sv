// Code your testbench here
// or browse Examples
module ram_design #(parameter addr_width = 4,
                    parameter data_width = 32,
                    parameter depth = 16) (
  input clk, rst_n, wr_enb, 
  input [addr_width - 1 : 0] addr,
  input [data_width - 1 : 0] wdata,
  output reg [data_width - 1 : 0] rdata);
  
  reg [data_width - 1 : 0] mem[0 : depth - 1];
  
  //reset condition
  
  always@(posedge clk)
    begin
      if(!rst_n)
        begin
          rdata <= 0;
        end
      else
        begin
          if(wr_enb)
            mem[addr] <= wdata;
          else
            rdata <= mem[addr];
        end
    end
endmodule
          