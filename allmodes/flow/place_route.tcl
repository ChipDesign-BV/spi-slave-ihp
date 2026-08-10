# OpenROAD placement and routing script for spi_slave.
# This script expects the IHP PDK environment to be defined in ihp_pdk.env.

set top spi_slave
set workdir [file join [file dirname [info script]] work]
file mkdir $workdir

set pdk_root $env(IHP_PDK_ROOT)
set cell_lef $env(IHP_CELL_LEF)
set tech_lef $env(IHP_TECH_LEF)
set stdcell_lib $env(IHP_STD_CELL_LIB)
set io_lef [expr {[info exists env(IHP_IO_LEF)] ? $env(IHP_IO_LEF) : ""}]
set io_lib [expr {[info exists env(IHP_IO_LIB)] ? $env(IHP_IO_LIB) : ""}]

if {$pdk_root == "" || $cell_lef == "" || $tech_lef == "" || $stdcell_lib == ""} {
    puts stderr "ERROR: Missing IHP PDK environment variables. Update ihp_pdk.env."
    exit 1
}

puts "Using IHP PDK root: $pdk_root"
puts "Cell LEF: $cell_lef"
puts "Tech LEF: $tech_lef"
puts "Liberty: $stdcell_lib"
if {$io_lef != ""} { puts "IO LEF: $io_lef" }
if {$io_lib != ""} { puts "IO LIB: $io_lib" }

set verilog_file [file normalize [file join [file dirname [info script]] .. spi_slave.v]]
set sdc_file [file normalize [file join [file dirname [info script]] constraints.sdc]]

read_lef $tech_lef
read_lef $cell_lef
if {$io_lef != ""} { read_lef $io_lef }
read_verilog $verilog_file
link_design $top
read_liberty -lib $stdcell_lib
if {$io_lib != ""} { read_liberty -lib $io_lib }
read_sdc $sdc_file
set_top $top
check_design

# Basic floorplan. Adjust the core area and utilization for your IHP process.
floorplan -site core -core_area {0 0 1000 1000} -utilization 0.60
place_design
route_design

set def_file [file join $workdir ${top}.def]
set gds_file [file join $workdir ${top}.gds]
write_def $def_file
write_gds $gds_file
puts "Wrote DEF: $def_file"
puts "Wrote GDS: $gds_file"
