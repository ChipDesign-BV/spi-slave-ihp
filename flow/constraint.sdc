# Simple timing constraints for SPI_Slave
# Adjust the period and delays for your target IHP timing requirements.

create_clock -name clk -period 10.0 [get_ports Clk]

# Input/output delays are placeholders; adjust per board/IO timing.
set_input_delay -clock clk 2.0 [get_ports {SCK MOSI SSEL Add2_in}]
set_output_delay -clock clk 2.0 [get_ports {MISO Data2_out}]
