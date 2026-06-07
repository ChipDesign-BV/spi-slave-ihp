// Koen Van Caekenberghe (koen.vancaekenberghe@chipdesign.be), ChipDesign B.V., 06.2026
// Test bench for SPI Slave

// iverilog tb_spi_slave.v
// vvp a.out
// gtkwave tb_spi_slave.vcd

`include "spi_slave.v"
`timescale 1ns/1ns

module tb_spi_slave();

reg [7:0] addr; // IC internal register select
reg clk; // IC internal clock (PLL)
initial begin
 	clk=0;
	forever #1 clk = ~clk;  
end

wire [7:0] data; // IC internal register output
wire [7:0] debug;
wire miso; // SPI MISO
reg mosi; // SPI MOSI
reg rst_n; // IC power-on-reset
reg sck; // SPI data clock
reg ssel; // SPI slave select

spi_slave spi_slave1(clk,rst_n,sck,mosi,ssel,miso,addr,data,debug);

initial begin
	addr=8'd3;
	mosi=0; 
	rst_n=0;
 	sck=0;
	ssel=1;
	#10 rst_n=1;
	#10 ssel=0;
	#10 sck=1;	
	mosi=1; // RnW
	#10 sck=0;
	#10 sck=1;
	mosi=0; // MSB
	#10 sck=0;
	#10 sck=1;
	mosi=0;
	#10 sck=0;
	#10 sck=1;
	mosi=0;
	#10 sck=0;
	#10 sck=1;
	mosi=0;
	#10 sck=0;
	#10 sck=1;
	mosi=0;
	#10 sck=0;
	#10 sck=1;
	mosi=0;
	#10 sck=0;
	#10 sck=1;
	mosi=1; // LSB
	#10 sck=0;
	#10 sck=1;
	#10 sck=0;
	#10 sck=1;
	#10 sck=0;
	#10 sck=1;
	#10 sck=0;
	#10 sck=1;
	#10 sck=0;
	#10 sck=1;
	#10 sck=0;
	#10 sck=1;
	#10 sck=0;
	#10 sck=1;
	#10 sck=0;
	#10 sck=1;
	#10 sck=0;
	#10 ssel=1;
	#10 ssel=0;
	#10 sck=1;
	mosi=0; // RnW
	#10 sck=0;
	#10 sck=1;
	mosi=0; // MSB
	#10 sck=0;
	#10 sck=1;
	mosi=0;
	#10 sck=0;
	#10 sck=1;
	mosi=0;
	#10 sck=0;
	#10 sck=1;
	mosi=0;
	#10 sck=0;
	#10 sck=1;
	mosi=0;
	#10 sck=0;
	#10 sck=1;
	mosi=1;
	#10 sck=0;
	#10 sck=1;
	mosi=1; // LSB
	#10 sck=0;
	#10 sck=1;
	mosi=1; // MSB
	#10 sck=0;
	#10 sck=1;
	mosi=1;
	#10 sck=0;
	#10 sck=1;
	mosi=1;
	#10 sck=0;
	#10 sck=1;
	mosi=1;
	#10 sck=0;
	#10 sck=1;
	mosi=1;
	#10 sck=0;
	#10 sck=1;
	mosi=1;
	#10 sck=0;
	#10 sck=1;
	mosi=1; // LSB
	#10 sck=0;
end

initial begin 
	#750 $finish;
end

initial begin
	$dumpfile("tb_spi_slave.vcd");
	$dumpvars(0,tb_spi_slave);
end

//initial begin
//	$monitor("At time %t, Q = %h (%0d)",$time, Q, Q);
//end

endmodule
