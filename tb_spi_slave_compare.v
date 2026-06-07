// Koen Van Caekenberghe (koen.vancaekenberghe@chipdesign.be), ChipDesign B.V., 06.2026
// Comparison test bench — RTL vs synthesised netlist
//
// Transactions:
//   Tx1: READ  Register1 (addr 0x01) — verifies reset value 0x0B on MISO
//   Tx2: WRITE 0xFF → Register7 (addr 0x07)
//   Tx3: READ  Register7 (addr 0x07) — confirms Tx2 write; expects 0xFF on MISO
//
// Compile for RTL:
//   iverilog -g2012 -o tb_rtl.out tb_spi_slave_compare.v && vvp tb_rtl.out
//
// Compile for synthesised netlist (SYNTH guard skips the `include so the
// netlist and its cell library are supplied on the command line instead):
//   iverilog -g2012 -DSYNTH -o tb_synth.out flow/spi_slave_synth.v tb_spi_slave_compare.v
//   vvp tb_synth.out

`timescale 1ns/1ns

`ifndef SYNTH
`include "spi_slave.v"
`endif

module tb_spi_slave_compare();

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
task spi_read_data;
    output [7:0] rx;
    integer i;
    begin
        for (i = 7; i >= 0; i = i - 1) begin
            #10 sck = 1;
            rx[i] = miso;
            #10 sck = 0;
        end
    end
endtask

initial begin
    addr  = 8'd1;   // parallel port initially at Register1 (reset value 0x0B)
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

    // --- Tx2: WRITE 0xFF → Register7 (addr_byte=0x07: RnW=0, addr=0x07) ---
    addr = 8'd7;    // point parallel port at Register7 to observe the write
    #10 ssel = 0;
    spi_send_cmd(8'h07);
    spi_write_data(8'hFF);
    #10 ssel = 1;
    #10;

    // --- Tx3: READ Register7 (addr_byte=0x87: RnW=1, addr=0x07) ---
    // Expected MISO: 0xFF — confirms Tx2 write was committed
    #10 ssel = 0;
    spi_send_cmd(8'h87);
    spi_read_data(miso_rx3);
    #10 ssel = 1;
    #10;
end

// Self-checking assertions — evaluated after all transactions complete
initial begin
    #1100;
    $display("FINISH %0t: miso_rx1=0x%02X data=0x%02X miso_rx3=0x%02X debug=0x%02X",
             $time, miso_rx1, data, miso_rx3, debug);
    if (miso_rx1 !== 8'h0B)
        $display("FAIL Tx1 READ Reg1  : expected miso=0x0B, got 0x%02X", miso_rx1);
    if (data !== 8'hFF)
        $display("FAIL parallel Reg7  : expected data=0xFF, got 0x%02X", data);
    if (miso_rx3 !== 8'hFF)
        $display("FAIL Tx3 READ Reg7  : expected miso=0xFF, got 0x%02X", miso_rx3);
    if (debug !== 8'h1F)
        $display("FAIL debug          : expected 0x1F, got 0x%02X", debug);
    if (miso_rx1 === 8'h0B && data === 8'hFF && miso_rx3 === 8'hFF && debug === 8'h1F)
        $display("PASS: all checks passed");
end

initial begin
    #1200 $finish;
end

initial begin
`ifdef SYNTH
    $dumpfile("tb_spi_slave_synth.vcd");
`else
    $dumpfile("tb_spi_slave_compare.vcd");
`endif
    $dumpvars(0, tb_spi_slave_compare);
end

endmodule
