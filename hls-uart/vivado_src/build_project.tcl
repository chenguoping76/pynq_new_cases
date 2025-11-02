# ==================================================================================
# Vivado Build Script for HLS-UART Project
# ==================================================================================
# Description: Automates synthesis, implementation, and bitstream generation
# Usage: vivado -mode batch -source build_project.tcl
# ==================================================================================

set project_name "hls_uart_dma"
set project_dir "./vivado_project"

# Check if project exists
if {![file exists "$project_dir/$project_name.xpr"]} {
    puts "ERROR: Project not found at $project_dir/$project_name.xpr"
    puts "Please run create_uart_project.tcl first"
    exit 1
}

# Open project
puts "Opening project: $project_name"
open_project $project_dir/$project_name.xpr

# ==================================================================================
# Synthesis
# ==================================================================================
puts ""
puts "=========================================="
puts "Starting Synthesis..."
puts "=========================================="

# Reset synthesis run if it exists
reset_run synth_1

# Launch synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check synthesis status
set synth_status [get_property STATUS [get_runs synth_1]]
set synth_progress [get_property PROGRESS [get_runs synth_1]]

puts "Synthesis Status: $synth_status"
puts "Synthesis Progress: $synth_progress"

if {$synth_status != "synth_design Complete!"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

# Open synthesized design and report utilization
open_run synth_1
report_utilization -file $project_dir/post_synth_utilization.rpt
report_timing_summary -file $project_dir/post_synth_timing.rpt

puts ""
puts "Synthesis completed successfully!"
puts "Reports generated:"
puts "  - $project_dir/post_synth_utilization.rpt"
puts "  - $project_dir/post_synth_timing.rpt"

# ==================================================================================
# Implementation
# ==================================================================================
puts ""
puts "=========================================="
puts "Starting Implementation..."
puts "=========================================="

# Launch implementation
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Check implementation status
set impl_status [get_property STATUS [get_runs impl_1]]
set impl_progress [get_property PROGRESS [get_runs impl_1]]

puts "Implementation Status: $impl_status"
puts "Implementation Progress: $impl_progress"

if {$impl_status != "route_design Complete!"} {
    puts "ERROR: Implementation failed!"
    exit 1
}

# Open implemented design and report
open_run impl_1
report_utilization -file $project_dir/post_impl_utilization.rpt
report_timing_summary -file $project_dir/post_impl_timing.rpt
report_power -file $project_dir/post_impl_power.rpt
report_drc -file $project_dir/post_impl_drc.rpt

puts ""
puts "Implementation completed successfully!"
puts "Reports generated:"
puts "  - $project_dir/post_impl_utilization.rpt"
puts "  - $project_dir/post_impl_timing.rpt"
puts "  - $project_dir/post_impl_power.rpt"
puts "  - $project_dir/post_impl_drc.rpt"

# ==================================================================================
# Bitstream Generation
# ==================================================================================
puts ""
puts "=========================================="
puts "Generating Bitstream..."
puts "=========================================="

# Launch bitstream generation
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Check bitstream generation status
set bit_status [get_property STATUS [get_runs impl_1]]

if {$bit_status != "write_bitstream Complete!"} {
    puts "ERROR: Bitstream generation failed!"
    exit 1
}

puts ""
puts "Bitstream generated successfully!"

# ==================================================================================
# Export Hardware Platform
# ==================================================================================
puts ""
puts "=========================================="
puts "Exporting Hardware Platform..."
puts "=========================================="

# Export hardware (for PYNQ/Vitis)
set xsa_file "$project_dir/uart_system_wrapper.xsa"
write_hw_platform -fixed -include_bit -force -file $xsa_file

puts "Hardware platform exported to: $xsa_file"

# ==================================================================================
# Copy output files to convenient location
# ==================================================================================
puts ""
puts "=========================================="
puts "Copying Output Files..."
puts "=========================================="

set output_dir "$project_dir/output"
file mkdir $output_dir

# Copy bitstream
set bit_file [glob -nocomplain $project_dir/$project_name.runs/impl_1/*.bit]
if {[llength $bit_file] > 0} {
    file copy -force [lindex $bit_file 0] $output_dir/uart_system.bit
    puts "Bitstream: $output_dir/uart_system.bit"
}

# Copy hardware handoff file
if {[file exists $xsa_file]} {
    file copy -force $xsa_file $output_dir/
    puts "XSA file: $output_dir/uart_system_wrapper.xsa"
}

# Copy constraint file
set xdc_file [glob -nocomplain $project_dir/$project_name.srcs/constrs_1/new/*.xdc]
if {[llength $xdc_file] > 0} {
    file copy -force [lindex $xdc_file 0] $output_dir/
    puts "Constraints: $output_dir/[file tail [lindex $xdc_file 0]]"
}

# ==================================================================================
# Generate Resource Utilization Report
# ==================================================================================
puts ""
puts "=========================================="
puts "Resource Utilization Summary"
puts "=========================================="

open_run impl_1

# Get utilization data
set slice_luts [get_property USED [get_resources -filter {TYPE==SLICE_LUTX}]]
set slice_regs [get_property USED [get_resources -filter {TYPE==SLICE_REGISTERS}]]
set bram_tile [llength [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ BMEM.*.RAMB*}]]
set dsp [llength [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ MISC.*.DSP*}]]

puts ""
puts "Resource Type       Used      Available   Utilization"
puts "---------------------------------------------------"
puts [format "Slice LUTs      %8d    53200      %5.2f%%" $slice_luts [expr {$slice_luts*100.0/53200}]]
puts [format "Slice Registers %8d   106400      %5.2f%%" $slice_regs [expr {$slice_regs*100.0/106400}]]
puts [format "Block RAM Tile  %8d      140      %5.2f%%" $bram_tile [expr {$bram_tile*100.0/140}]]
puts [format "DSPs            %8d      220      %5.2f%%" $dsp [expr {$dsp*100.0/220}]]

# ==================================================================================
# Timing Report Summary
# ==================================================================================
puts ""
puts "=========================================="
puts "Timing Summary"
puts "=========================================="

# Get timing information
set wns [get_property STATS.WNS [get_runs impl_1]]
set tns [get_property STATS.TNS [get_runs impl_1]]
set whs [get_property STATS.WHS [get_runs impl_1]]
set ths [get_property STATS.THS [get_runs impl_1]]

puts [format "Worst Negative Slack (WNS): %s ns" $wns]
puts [format "Total Negative Slack (TNS): %s ns" $tns]
puts [format "Worst Hold Slack (WHS):     %s ns" $whs]
puts [format "Total Hold Slack (THS):     %s ns" $ths]

if {$wns >= 0} {
    puts ""
    puts "✓ Timing constraints are MET"
} else {
    puts ""
    puts "✗ WARNING: Timing constraints are NOT MET"
    puts "Please review timing report: $project_dir/post_impl_timing.rpt"
}

# ==================================================================================
# Final Summary
# ==================================================================================
puts ""
puts "=========================================="
puts "Build Complete!"
puts "=========================================="
puts ""
puts "Output Files Location: $output_dir/"
puts ""
puts "Files generated:"
puts "  1. uart_system.bit - FPGA bitstream"
puts "  2. uart_system_wrapper.xsa - Hardware platform (for PYNQ)"
puts "  3. uart_pins.xdc - Pin constraints"
puts ""
puts "Reports Location: $project_dir/"
puts "  - post_synth_utilization.rpt"
puts "  - post_synth_timing.rpt"
puts "  - post_impl_utilization.rpt"
puts "  - post_impl_timing.rpt"
puts "  - post_impl_power.rpt"
puts "  - post_impl_drc.rpt"
puts ""
puts "Next Steps:"
puts "  1. Download bitstream to FPGA:"
puts "     - Open Hardware Manager in Vivado"
puts "     - Program device with $output_dir/uart_system.bit"
puts ""
puts "  2. For PYNQ development:"
puts "     - Copy uart_system_wrapper.xsa to PYNQ board"
puts "     - Use with Python overlay driver"
puts ""
puts "=========================================="

# Close project
close_project

exit 0
