// Koen Van Caekenberghe (koen.vancaekenberghe@chipdesign.be), ChipDesign B.V., 08.2026
// Test bench for SPI Slave — all-modes variant
//
// Runs the same three transactions in each of the four SPI modes
// (mode = {CPOL,CPHA} = 0,1,2,3), with a DUT reset between modes:
//   Tx1: READ  Register1 (addr 0x01) — verifies reset value 0x0B on MISO
//   Tx2: WRITE (0xA0|mode) → Register3 (addr 0x03)
//   Tx3: READ  Register3 (addr 0x03) — confirms Tx2 write on MISO
// After each mode the debug port must read 0x1F (all five FSM states visited).
//
// Master model timing (20 ns SCK period, 500 ns system clock = 2 ns period):
//   CPHA=0: MOSI is set up half a period before the leading edge; MISO is
//           sampled at the leading edge (the DUT drove it on the previous
//           trailing edge).
//   CPHA=1: MOSI changes on the leading edge; MISO is sampled at the
//           trailing edge (the DUT drove it on the preceding leading edge).
//
// Compile for RTL:
//   iverilog -g2012 -o tb_rtl.out tb_spi_slave.v && vvp tb_rtl.out
// Compile for synthesised netlist:
//   iverilog -g2012 -DSYNTH -o tb_syn.out flow/spi_slave_synth.v tb_spi_slave.v
//   vvp tb_syn.out

`timescale 1ns/1ns

`ifndef SYNTH
`include "spi_slave.v"
`endif

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
reg cpol, cpha;

reg [7:0] rx_cmd;    // MISO during command byte (ignored)
reg [7:0] miso_rx1;  // MISO byte captured during Tx1 READ
reg [7:0] miso_rx3;  // MISO byte captured during Tx3 READ
integer errors;
integer mode;

spi_slave spi_slave1(
    .Clk(clk),
    .iRST_N(rst_n),
    .CPOL(cpol),
    .CPHA(cpha),
    .SCK(sck),
    .MOSI(mosi),
    .SSEL(ssel),
    .MISO(miso),
    .Add2_in(addr),
    .Data2_out(data),
    .debug(debug)
);

// Transfer one byte MSB-first in the currently selected mode.
// tx goes out on MOSI, the byte seen on MISO is returned in rx.
task spi_xfer_byte;
    input  [7:0] tx;
    output [7:0] rx;
    integer i;
    begin
        for (i = 7; i >= 0; i = i - 1) begin
            if (cpha == 0) begin
                mosi = tx[i];
                #10 sck = ~cpol;    // leading edge: both sides sample
                rx[i] = miso;
                #10 sck = cpol;     // trailing edge: slave drives next bit
            end
            else begin
                sck = ~cpol;        // leading edge: both sides drive
                mosi = tx[i];
                #10 sck = cpol;     // trailing edge: both sides sample
                rx[i] = miso;
                #10;
            end
        end
    end
endtask

// Run the Tx1/Tx2/Tx3 sequence in SPI mode m and check the results.
task run_mode;
    input [1:0] m;
    begin
        cpol  = m[1];
        cpha  = m[0];
        addr  = 8'd3;      // parallel port points at Register3 throughout
        mosi  = 0;
        ssel  = 1;
        rst_n = 0;
        sck   = m[1];      // SCK idles at CPOL
        #20 rst_n = 1;
        #20;

        // --- Tx1: READ Register1 (addr_byte=0x81: RnW=1, addr=0x01) ---
        ssel = 0; #10;
        spi_xfer_byte(8'h81, rx_cmd);
        spi_xfer_byte(8'h00, miso_rx1);
        #10 ssel = 1;
        #20;

        // --- Tx2: WRITE (0xA0|mode) → Register3 (addr_byte=0x03) ---
        ssel = 0; #10;
        spi_xfer_byte(8'h03, rx_cmd);
        spi_xfer_byte(8'hA0 | m, rx_cmd);
        #10 ssel = 1;
        #20;

        // --- Tx3: READ Register3 (addr_byte=0x83: RnW=1, addr=0x03) ---
        ssel = 0; #10;
        spi_xfer_byte(8'h83, rx_cmd);
        spi_xfer_byte(8'h00, miso_rx3);
        #10 ssel = 1;
        #20;

        if (miso_rx1 !== 8'h0B) begin
            $display("FAIL mode %0d Tx1 READ Reg1 : expected miso=0x0B, got 0x%02X", m, miso_rx1);
            errors = errors + 1;
        end
        if (data !== (8'hA0 | m)) begin
            $display("FAIL mode %0d parallel Reg3: expected data=0x%02X, got 0x%02X", m, 8'hA0 | m, data);
            errors = errors + 1;
        end
        if (miso_rx3 !== (8'hA0 | m)) begin
            $display("FAIL mode %0d Tx3 READ Reg3: expected miso=0x%02X, got 0x%02X", m, 8'hA0 | m, miso_rx3);
            errors = errors + 1;
        end
        if (debug !== 8'h1F) begin
            $display("FAIL mode %0d debug        : expected 0x1F, got 0x%02X", m, debug);
            errors = errors + 1;
        end
        $display("MODE %0d (CPOL=%0d CPHA=%0d) %0t: miso_rx1=0x%02X data=0x%02X miso_rx3=0x%02X debug=0x%02X",
                 m, m[1], m[0], $time, miso_rx1, data, miso_rx3, debug);
    end
endtask

initial begin
    errors = 0;
    for (mode = 0; mode <= 3; mode = mode + 1)
        run_mode(mode[1:0]);

    if (errors == 0)
        $display("PASS: all checks passed in all 4 SPI modes");
    else
        $display("FAIL: %0d check(s) failed", errors);
    #20 $finish;
end

initial begin
`ifdef SYNTH
    $dumpfile("tb_spi_slave_synth.vcd");
`else
    $dumpfile("tb_spi_slave.vcd");
`endif
    $dumpvars(0, tb_spi_slave);
end

endmodule
