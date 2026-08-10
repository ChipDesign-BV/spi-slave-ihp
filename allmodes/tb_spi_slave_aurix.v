// Koen Van Caekenberghe (koen.vancaekenberghe@chipdesign.be), ChipDesign B.V., 08.2026
// Host verification test bench — Infineon AURIX QSPI master model
//
// Models an AURIX (TC2xx/TC3xx) QSPI module driving one SLSO chip-select:
//   - 100 MHz DUT system clock (10 ns period, as constrained in flow/constraint.sdc)
//   - 12.5 MHz SCLK (80 ns period) — the SCK <= Clk/8 limit of this slave
//   - SLSO lead delay (tLEAD) of one SCLK period before the first clock edge
//     and trail delay (tTRAIL) of one SCLK period after the last one
//   - Inter-word idle of one SCLK period between the command and data bytes
//     (QSPI idle delay between data words, SLSO kept asserted)
//   - MSB first, clock polarity/phase per SPI mode (ECON/iLLD mode settings)
//
// Per mode, after a DUT reset — full register-map verification:
//   1. WRITE a distinct value {mode,3'b101,i} to every register i = 0..7
//   2. READ every register back over SPI and compare
//   3. Read every register through the parallel port and compare
//   4. READ out-of-range address 0x7F -> expect 0xFF
//   5. Check debug = 0x1F (all five FSM states visited)
//
// Compile for RTL:
//   iverilog -g2012 -o tb_aurix_rtl.out tb_spi_slave_aurix.v && vvp tb_aurix_rtl.out
// Compile for synthesised netlist:
//   iverilog -g2012 -DSYNTH -o tb_aurix_syn.out flow/spi_slave_synth.v tb_spi_slave_aurix.v
//   vvp tb_aurix_syn.out

`timescale 1ns/1ns

`ifndef SYNTH
`include "spi_slave.v"
`endif

module tb_spi_slave_aurix();

// DUT system clock: 100 MHz
reg clk;
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// QSPI timing: 12.5 MHz SCLK, tLEAD = tTRAIL = inter-word idle = 1 SCLK period
localparam SCK_HALF = 40;
localparam T_LEAD   = 80;
localparam T_TRAIL  = 80;
localparam T_IDLE   = 80;

reg [7:0] addr;
wire [7:0] data;
wire [7:0] debug;
wire miso;
reg mosi;
reg rst_n;
reg sck;
reg ssel;
reg cpol, cpha;

reg [7:0] rx0, rx1;   // received bytes of the current frame
integer errors;
integer mode;
integer i;
reg [7:0] wr_val;

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
    integer k;
    begin
        for (k = 7; k >= 0; k = k - 1) begin
            if (cpha == 0) begin
                mosi = tx[k];
                #(SCK_HALF) sck = ~cpol;   // leading edge: both sides sample
                rx[k] = miso;
                #(SCK_HALF) sck = cpol;    // trailing edge: shift
            end
            else begin
                sck = ~cpol;               // leading edge: both sides shift
                mosi = tx[k];
                #(SCK_HALF) sck = cpol;    // trailing edge: both sides sample
                rx[k] = miso;
                #(SCK_HALF);
            end
        end
    end
endtask

// QSPI frame: SLSO low with lead delay, command byte, inter-word idle,
// data byte, trail delay, SLSO high.
task qspi_frame;
    input  [7:0] tx0;
    input  [7:0] tx1;
    begin
        ssel = 0;
        #(T_LEAD);
        spi_clock_byte(tx0, rx0);
        #(T_IDLE);
        spi_clock_byte(tx1, rx1);
        #(T_TRAIL);
        ssel = 1;
        #(2*SCK_HALF);   // pause until next frame
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
        addr  = 8'd0;
        mosi  = 0;
        ssel  = 1;
        rst_n = 0;
        sck   = m[1];
        #100 rst_n = 1;
        #100;

        // 1. WRITE all 8 registers
        for (i = 0; i < 8; i = i + 1) begin
            wr_val = {m, 3'b101, i[2:0]};
            qspi_frame({1'b0, i[6:0]}, wr_val);
        end

        // 2. READ all 8 registers back over SPI
        for (i = 0; i < 8; i = i + 1) begin
            wr_val = {m, 3'b101, i[2:0]};
            qspi_frame({1'b1, i[6:0]}, 8'h00);
            check_byte("SPI read-back", rx1, wr_val);
        end

        // 3. Read all 8 registers through the parallel port
        for (i = 0; i < 8; i = i + 1) begin
            wr_val = {m, 3'b101, i[2:0]};
            addr = i[7:0];
            #50;
            check_byte("parallel read", data, wr_val);
        end

        // 4. READ out-of-range address 0x7F
        qspi_frame(8'hFF, 8'h00);
        check_byte("out-of-range read", rx1, 8'hFF);

        // 5. All FSM states visited
        check_byte("debug", debug, 8'h1F);

        $display("MODE %0d (CPOL=%0d CPHA=%0d) %0t: 8 regs written+read back, parallel port ok, oor=0x%02X debug=0x%02X",
                 m, m[1], m[0], $time, rx1, debug);
    end
endtask

initial begin
    errors = 0;
    for (mode = 0; mode <= 3; mode = mode + 1)
        run_mode(mode[1:0]);

    if (errors == 0)
        $display("PASS: AURIX QSPI master model — all checks passed in all 4 SPI modes");
    else
        $display("FAIL: %0d check(s) failed", errors);
    #100 $finish;
end

initial begin
`ifdef SYNTH
    $dumpfile("tb_spi_slave_aurix_synth.vcd");
`else
    $dumpfile("tb_spi_slave_aurix.vcd");
`endif
    $dumpvars(0, tb_spi_slave_aurix);
end

endmodule
