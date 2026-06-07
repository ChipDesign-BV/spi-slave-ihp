// Koen Van Caekenberghe (koen.vancaekenberghe@chipdesign.be), ChipDesign B.V., 06.2026
// Test bench for SPI Slave comparison between RTL and synthesized netlist
//
// Compile for RTL:   iverilog tb_spi_slave_compare.v
// Compile for synth: iverilog -DSYNTH tb_spi_slave_compare.v spi_slave_synth.v <cell_lib.v>
//   When -DSYNTH is defined the `include of spi_slave.v is skipped so the synthesized
//   netlist (and its cell library) can be supplied on the command line instead.
`timescale 1ns/1ns

`ifndef SYNTH
`include "spi_slave.v"
`endif

module tb_spi_slave_compare();

reg [7:0] addr;  // IC internal register select
reg clk;         // IC internal clock (PLL)
initial begin
    clk = 0;
    forever #1 clk = ~clk;
end

wire [7:0] data;  // IC internal register output
wire [7:0] debug;
wire miso;        // SPI MISO
reg mosi;         // SPI MOSI
reg rst_n;        // IC power-on-reset
reg sck;          // SPI data clock
reg ssel;         // SPI slave select

spi_slave spi_slave1(
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

// Transaction 1: READ Register1  (addr_byte=0x81: RnW=1, addr=0x01; default value 0x0B expected on MISO)
// Transaction 2: WRITE 0xFF to Register7 (addr_byte=0x07: RnW=0, addr=0x07; data_byte=0xFF)
initial begin
    addr = 8'd3;
    mosi = 0;
    rst_n = 0;
    sck = 0;
    ssel = 1;
    #10 rst_n = 1;

    // --- Transaction 1: READ addr=0x01 (addr_byte=0x81) ---
    #10 ssel = 0;
    #10 sck = 1;
    mosi = 1; // bit7: RnW=1 (Read)
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0; // bit6
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0; // bit5
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0; // bit4
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0; // bit3
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0; // bit2
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0; // bit1
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1; // bit0 (LSB) → addr=0x01
    #10 sck = 0;
    // data phase: 8 clocks; MISO shifts out Register1 (reset value 0x0B)
    #10 sck = 1;
    #10 sck = 0;
    #10 sck = 1;
    #10 sck = 0;
    #10 sck = 1;
    #10 sck = 0;
    #10 sck = 1;
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

    // --- Transaction 2: WRITE 0xFF to addr=0x07 (addr_byte=0x07) ---
    #10 ssel = 0;
    #10 sck = 1;
    mosi = 0; // bit7: RnW=0 (Write)
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0; // bit6
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0; // bit5
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0; // bit4
    #10 sck = 0;
    #10 sck = 1;
    mosi = 0; // bit3
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1; // bit2
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1; // bit1
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1; // bit0 (LSB) → addr=0x07
    #10 sck = 0;
    // data byte: 0xFF
    #10 sck = 1;
    mosi = 1; // bit7 (MSB)
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1; // bit6
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1; // bit5
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1; // bit4
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1; // bit3
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1; // bit2
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1; // bit1
    #10 sck = 0;
    #10 sck = 1;
    mosi = 1; // bit0 (LSB) → data=0xFF
    #10 sck = 0;
end

initial begin
    #750;
    $display("FINISH %t: addr=%h data=%h debug=%h miso=%b ssel=%b", $time, addr, data, debug, miso, ssel);
    $finish;
end

initial begin
    $dumpfile("tb_spi_slave_compare.vcd");
    $dumpvars(0,tb_spi_slave_compare);
end

endmodule
