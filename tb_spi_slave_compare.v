// Koen Van Caekenberghe, ChipDesign B.V., 06.2026
// Test bench for SPI Slave comparison between RTL and synthesized netlist
`timescale 1ns/1ns

`ifndef SYNTH
`include "SPI_Slave.v"
`endif

module tb_SPI_Slave_compare();

reg [7:0] addr;
reg clk;
initial begin
    clk = 0;
    forever #1 clk = ~clk;
end

wire [7:0] data;
wire [7:0] debug;
wire miso;
reg mosi;
reg rst_n;
reg sck;
reg ssel;

SPI_Slave spi_slave1(
    .Clk(clk),
    .iRST_N(rst_n),
    .SCK(sck),
    .MOSI(mosi),
    .SSEL(ssel),
    .MISO(miso),
    .Add2_in(addr),
    .Data2_out(data),
    .debug(debug)
);

initial begin
    addr = 8'd3;
    mosi = 0;
    rst_n = 0;
    sck = 0;
    ssel = 1;
    #10 rst_n = 1;
    #10 ssel = 0;
    #10 sck = 1;
    mosi = 1;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1;
    #10 sck = 0;
    #10 sck = 1;
    #10 sck = 0;
    #10 sck = 1;
    #10 sck = 0;
    #10 sck = 1;
    #10 sck = 0;
    #10 sck = 1;
    #10 sck = 0;
    #10 ssel = 1;
    #10 ssel = 0;
    #10 sck = 1;
    mosi = 0;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1;
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1;
    #10 sck = 0;
end

initial begin
    #750;
    $display("FINISH %t: addr=%h data=%h debug=%h miso=%b ssel=%b", $time, addr, data, debug, miso, ssel);
    $finish;
end

initial begin
    $dumpfile("tb_SPI_Slave_compare.vcd");
    $dumpvars(0,tb_SPI_Slave_compare);
end

endmodule
