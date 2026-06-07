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

// Transaction 1: READ Register1  (addr_byte=0x81: RnW=1, addr=0x01; default value 0x0B expected on MISO)
// Transaction 2: WRITE 0xFF to Register3 (addr_byte=0x03: RnW=0, addr=0x03; data_byte=0xFF)
initial begin
	addr=8'd3;
	mosi=0;
	rst_n=0;
 	sck=0;
	ssel=1;
	#10 rst_n=1;

	// --- Transaction 1: READ addr=0x01 (addr_byte=0x81) ---
	#10 ssel=0;
	#10 sck=1;
	mosi=1; // bit7: RnW=1 (Read)
	#10 sck=0;
	#10 sck=1;
	mosi=0; // bit6
	#10 sck=0;
	#10 sck=1;
	mosi=0; // bit5
	#10 sck=0;
	#10 sck=1;
	mosi=0; // bit4
	#10 sck=0;
	#10 sck=1;
	mosi=0; // bit3
	#10 sck=0;
	#10 sck=1;
	mosi=0; // bit2
	#10 sck=0;
	#10 sck=1;
	mosi=0; // bit1
	#10 sck=0;
	#10 sck=1;
	mosi=1; // bit0 (LSB) → addr=0x01
	#10 sck=0;
	// data phase: 8 clocks; MISO shifts out Register1 (reset value 0x0B)
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

	// --- Transaction 2: WRITE 0xFF to addr=0x03 (addr_byte=0x03) ---
	#10 ssel=0;
	#10 sck=1;
	mosi=0; // bit7: RnW=0 (Write)
	#10 sck=0;
	#10 sck=1;
	mosi=0; // bit6
	#10 sck=0;
	#10 sck=1;
	mosi=0; // bit5
	#10 sck=0;
	#10 sck=1;
	mosi=0; // bit4
	#10 sck=0;
	#10 sck=1;
	mosi=0; // bit3
	#10 sck=0;
	#10 sck=1;
	mosi=0; // bit2
	#10 sck=0;
	#10 sck=1;
	mosi=1; // bit1
	#10 sck=0;
	#10 sck=1;
	mosi=1; // bit0 (LSB) → addr=0x03
	#10 sck=0;
	// data byte: 0xFF
	#10 sck=1;
	mosi=1; // bit7 (MSB)
	#10 sck=0;
	#10 sck=1;
	mosi=1; // bit6
	#10 sck=0;
	#10 sck=1;
	mosi=1; // bit5
	#10 sck=0;
	#10 sck=1;
	mosi=1; // bit4
	#10 sck=0;
	#10 sck=1;
	mosi=1; // bit3
	#10 sck=0;
	#10 sck=1;
	mosi=1; // bit2
	#10 sck=0;
	#10 sck=1;
	mosi=1; // bit1
	#10 sck=0;
	#10 sck=1;
	mosi=1; // bit0 (LSB) → data=0xFF
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
