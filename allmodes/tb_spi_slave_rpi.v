// Koen Van Caekenberghe (koen.vancaekenberghe@chipdesign.be), ChipDesign B.V., 08.2026
// Host verification test bench — Raspberry Pi SPI master model
//
// Models the BCM283x/BCM2711 hardware SPI controller as driven by spidev
// (spi.xfer2), which is how a Raspberry Pi talks to this slave:
//   - 100 MHz DUT system clock (10 ns period, as constrained in flow/constraint.sdc)
//   - 10 MHz SCK (100 ns period) — spi.max_speed_hz = 10_000_000
//   - CE0 (SSEL) asserted ~one SCK period before the first clock edge and
//     released ~half a period after the last one (spidev keeps CS asserted
//     for the whole xfer2 buffer)
//   - Bytes are clocked back-to-back with no inter-byte gap, MSB first
//   - All four modes (spi.mode = 0..3)
//
// Per mode, after a DUT reset:
//   Tx1: xfer2([0x81, 0x00])  READ  Register1        -> expect 0x0B
//   Tx2: xfer2([0x03, 0x5A])  WRITE 0x5A → Register3
//   Tx3: xfer2([0x83, 0x00])  READ  Register3 back   -> expect 0x5A
//   Tx4: xfer2([0xF5, 0x00])  READ  address 0x75     -> expect 0xFF (out of range)
//   Then checks the parallel read port and debug = 0x1F.
//
// Compile for RTL:
//   iverilog -g2012 -o tb_rpi_rtl.out tb_spi_slave_rpi.v && vvp tb_rpi_rtl.out
// Compile for synthesised netlist:
//   iverilog -g2012 -DSYNTH -o tb_rpi_syn.out flow/spi_slave_synth.v tb_spi_slave_rpi.v
//   vvp tb_rpi_syn.out

`timescale 1ns/1ns

`ifndef SYNTH
`include "spi_slave.v"
`endif

module tb_spi_slave_rpi();

// DUT system clock: 100 MHz
reg clk;
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// SPI master timing: 10 MHz SCK
localparam SCK_HALF = 50;

reg [7:0] addr;
wire [7:0] data;
wire [7:0] debug;
wire miso;
reg mosi;
reg rst_n;
reg sck;
reg ssel;
reg cpol, cpha;

reg [7:0] rx0, rx1;   // received bytes of the current 2-byte xfer2
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

// One byte on the wire, MSB first, in the currently selected mode.
task spi_clock_byte;
    input  [7:0] tx;
    output [7:0] rx;
    integer i;
    begin
        for (i = 7; i >= 0; i = i - 1) begin
            if (cpha == 0) begin
                mosi = tx[i];
                #(SCK_HALF) sck = ~cpol;   // leading edge: both sides sample
                rx[i] = miso;
                #(SCK_HALF) sck = cpol;    // trailing edge: shift
            end
            else begin
                sck = ~cpol;               // leading edge: both sides shift
                mosi = tx[i];
                #(SCK_HALF) sck = cpol;    // trailing edge: both sides sample
                rx[i] = miso;
                #(SCK_HALF);
            end
        end
    end
endtask

// spidev-style xfer2 of a 2-byte buffer: CS low for the whole buffer,
// bytes back-to-back, CS setup/hold of ~1 SCK period / ~0.5 SCK period.
task xfer2;
    input  [7:0] tx0;
    input  [7:0] tx1;
    begin
        ssel = 0;
        #(2*SCK_HALF);
        spi_clock_byte(tx0, rx0);
        spi_clock_byte(tx1, rx1);
        #(SCK_HALF);
        ssel = 1;
        #(2*SCK_HALF);   // inter-transfer gap
    end
endtask

task check_byte;
    input [8*40:1] label;
    input [7:0] got;
    input [7:0] expect_v;
    begin
        if (got !== expect_v) begin
            $display("FAIL mode %0d %0s: expected 0x%02X, got 0x%02X", mode, label, expect_v, got);
            errors = errors + 1;
        end
    end
endtask

task run_mode;
    input [1:0] m;
    begin
        cpol  = m[1];
        cpha  = m[0];
        addr  = 8'd3;
        mosi  = 0;
        ssel  = 1;
        rst_n = 0;
        sck   = m[1];
        #100 rst_n = 1;
        #100;

        xfer2(8'h81, 8'h00);              // READ Register1
        check_byte("Tx1 READ Reg1", rx1, 8'h0B);

        xfer2(8'h03, 8'h5A);              // WRITE 0x5A -> Register3
        #50;
        check_byte("Tx2 parallel Reg3", data, 8'h5A);

        xfer2(8'h83, 8'h00);              // READ Register3 back
        check_byte("Tx3 READ Reg3", rx1, 8'h5A);

        xfer2(8'hF5, 8'h00);              // READ address 0x75 (out of range)
        check_byte("Tx4 READ 0x75", rx1, 8'hFF);

        check_byte("debug", debug, 8'h1F);
        $display("MODE %0d (CPOL=%0d CPHA=%0d) %0t: rd1=0x%02X wr/rd3=0x%02X oor=0xFF? 0x%02X debug=0x%02X",
                 m, m[1], m[0], $time, 8'h0B, rx1 === 8'hFF ? 8'h5A : rx1, rx1, debug);
    end
endtask

initial begin
    errors = 0;
    for (mode = 0; mode <= 3; mode = mode + 1)
        run_mode(mode[1:0]);

    if (errors == 0)
        $display("PASS: Raspberry Pi master model — all checks passed in all 4 SPI modes");
    else
        $display("FAIL: %0d check(s) failed", errors);
    #100 $finish;
end

initial begin
`ifdef SYNTH
    $dumpfile("tb_spi_slave_rpi_synth.vcd");
`else
    $dumpfile("tb_spi_slave_rpi.vcd");
`endif
    $dumpvars(0, tb_spi_slave_rpi);
end

endmodule
