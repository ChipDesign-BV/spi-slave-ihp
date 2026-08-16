# Timing constraints for spi_slave on the thick-oxide (3.3 V) cell library.
#
# The period is kept at the 10 ns of the thin-oxide build so the two
# implementations are directly comparable; the thick-oxide cells are slower
# per stage, and whether 100 MHz still closes is a result of the run, not an
# assumption. Input/output delays are the same placeholders as the
# thin-oxide constraint.

create_clock -name clk -period 10.0 [get_ports Clk]

set_input_delay -clock clk 2.0 [get_ports {SCK MOSI SSEL Add2_in}]
set_output_delay -clock clk 2.0 [get_ports {MISO Data2_out}]
