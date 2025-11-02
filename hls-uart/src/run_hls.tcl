# Vitis HLS TCL Script for UART IP Core
# This script automates the HLS synthesis process

# Project settings
set project_name "uart_hls"
set solution_name "solution1"
set top_function "uart_hls"

# Target device - modify according to your PYNQ board
# PYNQ-Z1/Z2: xc7z020clg400-1
# Ultra96: xczu3eg-sbva484-1-e
set target_device "xc7z020clg400-1"

# Clock period in ns (10ns = 100MHz)
set clock_period 10

# Create new project
open_project -reset $project_name

# Add source files
add_files uart_hls.cpp
add_files uart_hls.h

# Add testbench files
add_files -tb uart_hls_tb.cpp

# Set top function
set_top $top_function

# Create solution
open_solution -reset $solution_name

# Set target device
set_part $target_device

# Create clock constraint
create_clock -period $clock_period -name default

# Set C simulation options
csim_design -clean

# Run C simulation
puts "Running C Simulation..."
csim_design

# Run synthesis
puts "Running C Synthesis..."
csynth_design

# Run cosimulation (optional - can be slow)
# Uncomment to enable
# puts "Running C/RTL Cosimulation..."
# cosim_design -trace_level all

# Export RTL as IP
puts "Exporting IP..."
export_design -format ip_catalog \
              -description "UART HLS IP Core with AXI4-Lite control and AXI4-Stream data" \
              -vendor "xilinx.com" \
              -library "hls" \
              -version "1.0" \
              -display_name "UART HLS"

puts "HLS flow completed successfully!"
puts "IP exported to: [pwd]/$project_name/$solution_name/impl/ip"

# Exit
exit
