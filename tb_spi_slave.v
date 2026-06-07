// Koen Van Caekenberghe (koen.vancaekenberghe@chipdesign.be), ChipDesign B.V., 06.2026
// Test bench for SPI Slave
//
// Transactions:
//   Tx1: READ  Register1 (addr 0x01) — verifies reset value 0x0B on MISO
//   Tx2: WRITE 0xFF → Register3 (addr 0x03)
//   Tx3: READ  Register3 (addr 0x03) — confirms Tx2 write; expects 0xFF on MISO
//
// MISO timing note: the DUT drives MISO on synchronized falling SCK edges.
// The first MISO bit (MSB) appears on the falling edge that ends the command
// phase, so spi_read_data samples all 8 bits on the 8 rising edges of the
// data phase — no extra clock cycle is required.
//
// Compile: iverilog -g2012 -o tb_rtl.out tb_spi_slave.v && vvp tb_rtl.out

`include "spi_slave.v"
`timescale 1ns/1ns

module tb_spi_slave();

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

reg [7:0] miso_rx1;  // MISO byte captured during Tx1 READ
reg [7:0] miso_rx3;  // MISO byte captured during Tx3 READ

spi_slave spi_slave1(clk, rst_n, sck, mosi, ssel, miso, addr, data, debug);

// Send 8-bit command byte MSB-first; MOSI is set up 10 ns before each rising edge.
task spi_send_cmd;
    input [7:0] cmd;
    integer i;
    begin
        for (i = 7; i >= 0; i = i - 1) begin
            mosi = cmd[i];
            #10 sck = 1;
            #10 sck = 0;
        end
    end
endtask

// Send 8-bit write data byte MSB-first on MOSI.
task spi_write_data;
    input [7:0] tx;
    integer i;
    begin
        for (i = 7; i >= 0; i = i - 1) begin
            mosi = tx[i];
            #10 sck = 1;
            #10 sck = 0;
        end
    end
endtask

// Receive 8-bit read data from MISO, sampling on each rising SCK edge.
// Bit[7] was driven by the DUT on the last falling edge of the command phase,
// so it is already stable at the first rising edge of the data phase.
task spi_read_data;
    output [7:0] rx;
    integer i;
    begin
        for (i = 7; i >= 0; i = i - 1) begin
            #10 sck = 1;
            rx[i] = miso;   // DUT drove this bit on the preceding falling edge
            #10 sck = 0;
        end
    end
endtask

initial begin
    addr  = 8'd3;   // parallel port points at Register3 throughout
    mosi  = 0;
    rst_n = 0;
    sck   = 0;
    ssel  = 1;
    #10 rst_n = 1;

    // --- Tx1: READ Register1 (addr_byte=0x81: RnW=1, addr=0x01) ---
    // Expected MISO: 0x0B (Register1 reset value)
    #10 ssel = 0;
    spi_send_cmd(8'h81);
    spi_read_data(miso_rx1);
    #10 ssel = 1;
    #10;

    // --- Tx2: WRITE 0xFF → Register3 (addr_byte=0x03: RnW=0, addr=0x03) ---
    #10 ssel = 0;
    spi_send_cmd(8'h03);
    spi_write_data(8'hFF);
    #10 ssel = 1;
    #10;

    // --- Tx3: READ Register3 (addr_byte=0x83: RnW=1, addr=0x03) ---
    // Expected MISO: 0xFF — confirms Tx2 write was committed
    #10 ssel = 0;
    spi_send_cmd(8'h83);
    spi_read_data(miso_rx3);
    #10 ssel = 1;
    #10;
end

// Self-checking assertions — evaluated after all transactions complete
initial begin
    #1100;
    if (miso_rx1 !== 8'h0B)
        $display("FAIL Tx1 READ Reg1  : expected miso=0x0B, got 0x%02X", miso_rx1);
    if (data !== 8'hFF)
        $display("FAIL parallel Reg3  : expected data=0xFF, got 0x%02X", data);
    if (miso_rx3 !== 8'hFF)
        $display("FAIL Tx3 READ Reg3  : expected miso=0xFF, got 0x%02X", miso_rx3);
    if (debug !== 8'h1F)
        $display("FAIL debug          : expected 0x1F, got 0x%02X", debug);
    if (miso_rx1 === 8'h0B && data === 8'hFF && miso_rx3 === 8'hFF && debug === 8'h1F)
        $display("PASS %0t: miso_rx1=0x%02X data=0x%02X miso_rx3=0x%02X debug=0x%02X",
                 $time, miso_rx1, data, miso_rx3, debug);
end

initial begin
    #1200 $finish;
end

initial begin
    $dumpfile("tb_spi_slave.vcd");
    $dumpvars(0, tb_spi_slave);
end

endmodule
