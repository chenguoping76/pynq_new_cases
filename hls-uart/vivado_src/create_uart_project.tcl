# ==================================================================================
# Vivado TCL Script for HLS-UART with AXI-DMA on BKB220 Board
# ==================================================================================
# Description: Creates a Vivado project with HLS UART IP and AXI DMA
# Board: BKB220 (Zynq 7020)
# UART Pins: PMOD1_d0 (TX - Y7), PMOD1_d1 (RX - Y9)
# ==================================================================================

# Project settings
set project_name "hls_uart_dma"
set project_dir "./vivado_project"
set bd_name "uart_system"
set hls_ip_repo "./uart_hls/solution1/impl/ip"

# Board and device settings
# downlad https://github.com/chenguoping76/pynq_new_cases/blob/main/ykmmwave-20251104.zip
# extract to /opt/Xilinx/Vivado/2022.2/data/xhub/boards
set board_part "ykmmwave.com:BKB220:part0:3.0"
set device_part "xc7z020clg400-1"

# Create project directory if it doesn't exist
file mkdir $project_dir

# Create project
puts "Creating Vivado project: $project_name"
create_project $project_name $project_dir -part $device_part -force

# Set board part (if board files are installed)
if {[catch {set_property board_part $board_part [current_project]}]} {
    puts "WARNING: Board part not found. Using device part only."
    puts "Install board files from: https://github.com/ykmmwave/BKB220_board_files"
}

# Set project properties
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# Add HLS IP repository (if exists)
if {[file exists $hls_ip_repo]} {
    set_property ip_repo_paths $hls_ip_repo [current_project]
    update_ip_catalog
    puts "Added HLS IP repository: $hls_ip_repo"
} else {
    puts "WARNING: HLS IP repository not found at: $hls_ip_repo"
    puts "Please run HLS synthesis first or update the path."
}

# ==================================================================================
# Create Block Design
# ==================================================================================
puts "Creating block design: $bd_name"
create_bd_design $bd_name

# ==================================================================================
# Add Processing System
# ==================================================================================
puts "Adding Zynq Processing System..."
set zynq_ps [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0]

# Configure PS
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
    $zynq_ps

# Enable HP0 port for DMA
set_property -dict [list \
    CONFIG.PCW_USE_S_AXI_HP0 {1} \
    CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {64} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
    CONFIG.PCW_IRQ_F2P_INTR {1} \
] $zynq_ps

# ==================================================================================
# Add AXI Interconnect
# ==================================================================================
puts "Adding AXI Interconnects..."

# AXI Interconnect for GP0 (Control path)
set axi_interconnect_gp0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_gp0]
set_property -dict [list \
    CONFIG.NUM_MI {3} \
    CONFIG.NUM_SI {1} \
] $axi_interconnect_gp0

# AXI Interconnect for HP0 (Data path from DMA)
set axi_interconnect_hp0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_hp0]
set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {2} \
] $axi_interconnect_hp0

# ==================================================================================
# Add AXI DMA for TX
# ==================================================================================
puts "Adding AXI DMA for TX..."
set axi_dma_tx [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_tx]
set_property -dict [list \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
    CONFIG.c_include_mm2s {1} \
    CONFIG.c_include_s2mm {0} \
    CONFIG.c_m_axi_mm2s_data_width {64} \
    CONFIG.c_m_axis_mm2s_tdata_width {8} \
    CONFIG.c_mm2s_burst_size {16} \
] $axi_dma_tx

# ==================================================================================
# Add AXI DMA for RX
# ==================================================================================
puts "Adding AXI DMA for RX..."
set axi_dma_rx [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_rx]
set_property -dict [list \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_s2mm {1} \
    CONFIG.c_m_axi_s2mm_data_width {64} \
    CONFIG.c_s_axis_s2mm_tdata_width {8} \
    CONFIG.c_s2mm_burst_size {16} \
] $axi_dma_rx

# ==================================================================================
# Add HLS UART IP (if available)
# ==================================================================================
puts "Adding HLS UART IP..."
if {[catch {
    set uart_hls [create_bd_cell -type ip -vlnv xilinx.com:hls:uart_hls:1.0 uart_hls_0]
    puts "HLS UART IP added successfully"
} err]} {
    puts "WARNING: Could not add HLS UART IP. Error: $err"
    puts "Creating placeholder interface..."
    # Create external ports as placeholders
    set uart_txd [create_bd_port -dir O uart_txd]
    set uart_rxd [create_bd_port -dir I uart_rxd]
}

# ==================================================================================
# Add Processor System Reset
# ==================================================================================
puts "Adding Processor System Reset..."
set proc_sys_reset [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_100M]

# ==================================================================================
# Add Concat for Interrupts
# ==================================================================================
puts "Adding interrupt concatenation..."
set concat_irq [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0]
set_property -dict [list CONFIG.NUM_PORTS {2}] $concat_irq

# ==================================================================================
# Make Connections
# ==================================================================================
puts "Connecting blocks..."

# Clock and Reset
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins rst_ps7_100M/slowest_sync_clk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins rst_ps7_100M/ext_reset_in]
connect_bd_net [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK] [get_bd_pins processing_system7_0/FCLK_CLK0]
connect_bd_net [get_bd_pins processing_system7_0/S_AXI_HP0_ACLK] [get_bd_pins processing_system7_0/FCLK_CLK0]

# Connect clocks to interconnects
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_interconnect_gp0/ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_interconnect_gp0/S00_ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_interconnect_gp0/M00_ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_interconnect_gp0/M01_ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_interconnect_gp0/M02_ACLK]

connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_interconnect_hp0/ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_interconnect_hp0/S00_ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_interconnect_hp0/S01_ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_interconnect_hp0/M00_ACLK]

# Connect clocks to DMAs
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_dma_tx/s_axi_lite_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_dma_tx/m_axi_mm2s_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_dma_rx/s_axi_lite_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_dma_rx/m_axi_s2mm_aclk]

# Connect resets to interconnects
connect_bd_net [get_bd_pins rst_ps7_100M/peripheral_aresetn] [get_bd_pins axi_interconnect_gp0/ARESETN]
connect_bd_net [get_bd_pins rst_ps7_100M/peripheral_aresetn] [get_bd_pins axi_interconnect_gp0/S00_ARESETN]
connect_bd_net [get_bd_pins rst_ps7_100M/peripheral_aresetn] [get_bd_pins axi_interconnect_gp0/M00_ARESETN]
connect_bd_net [get_bd_pins rst_ps7_100M/peripheral_aresetn] [get_bd_pins axi_interconnect_gp0/M01_ARESETN]
connect_bd_net [get_bd_pins rst_ps7_100M/peripheral_aresetn] [get_bd_pins axi_interconnect_gp0/M02_ARESETN]

connect_bd_net [get_bd_pins rst_ps7_100M/peripheral_aresetn] [get_bd_pins axi_interconnect_hp0/ARESETN]
connect_bd_net [get_bd_pins rst_ps7_100M/peripheral_aresetn] [get_bd_pins axi_interconnect_hp0/S00_ARESETN]
connect_bd_net [get_bd_pins rst_ps7_100M/peripheral_aresetn] [get_bd_pins axi_interconnect_hp0/S01_ARESETN]
connect_bd_net [get_bd_pins rst_ps7_100M/peripheral_aresetn] [get_bd_pins axi_interconnect_hp0/M00_ARESETN]

# Connect resets to DMAs
connect_bd_net [get_bd_pins rst_ps7_100M/peripheral_aresetn] [get_bd_pins axi_dma_tx/axi_resetn]
connect_bd_net [get_bd_pins rst_ps7_100M/peripheral_aresetn] [get_bd_pins axi_dma_rx/axi_resetn]

# AXI Control connections - PS GP0 to Interconnect
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins axi_interconnect_gp0/S00_AXI]

# AXI Control connections - Interconnect to peripherals
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_gp0/M00_AXI] [get_bd_intf_pins axi_dma_tx/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_gp0/M01_AXI] [get_bd_intf_pins axi_dma_rx/S_AXI_LITE]

# AXI Data connections - DMAs to HP Interconnect
connect_bd_intf_net [get_bd_intf_pins axi_dma_tx/M_AXI_MM2S] [get_bd_intf_pins axi_interconnect_hp0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_dma_rx/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_hp0/S01_AXI]

# HP Interconnect to PS HP0
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_hp0/M00_AXI] [get_bd_intf_pins processing_system7_0/S_AXI_HP0]

# Connect HLS UART IP if it exists
if {[llength [get_bd_cells -quiet uart_hls_0]] > 0} {
    puts "Connecting HLS UART IP..."

    # Clock and reset for UART
    connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins uart_hls_0/ap_clk]
    connect_bd_net [get_bd_pins rst_ps7_100M/peripheral_aresetn] [get_bd_pins uart_hls_0/ap_rst_n]

    # AXI Control connection
    connect_bd_intf_net [get_bd_intf_pins axi_interconnect_gp0/M02_AXI] [get_bd_intf_pins uart_hls_0/s_axi_control]

    # AXI Stream connections
    connect_bd_intf_net [get_bd_intf_pins axi_dma_tx/M_AXIS_MM2S] [get_bd_intf_pins uart_hls_0/tx_stream]
    connect_bd_intf_net [get_bd_intf_pins uart_hls_0/rx_stream] [get_bd_intf_pins axi_dma_rx/S_AXIS_S2MM]

    # Make UART pins external
    set uart_rxd_port [create_bd_port -dir I uart_rxd]
    set uart_txd_port [create_bd_port -dir O uart_txd]
    connect_bd_net [get_bd_pins uart_hls_0/uart_rxd] [get_bd_ports uart_rxd]
    connect_bd_net [get_bd_pins uart_hls_0/uart_txd] [get_bd_ports uart_txd]
}

# Connect interrupts
connect_bd_net [get_bd_pins axi_dma_tx/mm2s_introut] [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins axi_dma_rx/s2mm_introut] [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins processing_system7_0/IRQ_F2P]

# ==================================================================================
# Assign Addresses
# ==================================================================================
puts "Assigning addresses..."
assign_bd_address

# Set address ranges
set_property range 64K [get_bd_addr_segs {processing_system7_0/Data/SEG_axi_dma_tx_Reg}]
set_property range 64K [get_bd_addr_segs {processing_system7_0/Data/SEG_axi_dma_rx_Reg}]

if {[llength [get_bd_cells -quiet uart_hls_0]] > 0} {
    set_property range 64K [get_bd_addr_segs {processing_system7_0/Data/SEG_uart_hls_0_Reg}]
}

# ==================================================================================
# Validate and Save Block Design
# ==================================================================================
puts "Validating block design..."
regenerate_bd_layout
validate_bd_design
save_bd_design

# ==================================================================================
# Create HDL Wrapper
# ==================================================================================
puts "Creating HDL wrapper..."
make_wrapper -files [get_files $project_dir/$project_name.srcs/sources_1/bd/$bd_name/${bd_name}.bd] -top
add_files -norecurse $project_dir/$project_name.gen/sources_1/bd/$bd_name/hdl/${bd_name}_wrapper.v
set_property top ${bd_name}_wrapper [current_fileset]
update_compile_order -fileset sources_1

# ==================================================================================
# Add Constraints File
# ==================================================================================
puts "Creating constraints file..."
set xdc_file "$project_dir/$project_name.srcs/constrs_1/new/uart_pins.xdc"
file mkdir [file dirname $xdc_file]

set xdc_content {# ==================================================================================
# Pin Constraints for HLS-UART on BKB220 Board
# ==================================================================================
# UART connections on PMOD1
# PMOD1_d0 (Y7) -> uart_txd (output)
# PMOD1_d1 (Y9) -> uart_rxd (input)
# ==================================================================================

# UART TX - PMOD1_d0
set_property -dict {PACKAGE_PIN Y7 IOSTANDARD LVCMOS33} [get_ports uart_txd]

# UART RX - PMOD1_d1
set_property -dict {PACKAGE_PIN Y9 IOSTANDARD LVCMOS33} [get_ports uart_rxd]

# Timing constraints
create_clock -period 10.000 -name clk_fpga_0 [get_pins uart_system_i/processing_system7_0/inst/PS7_i/FCLKCLK[0]]
}

set xdc_fh [open $xdc_file w]
puts $xdc_fh $xdc_content
close $xdc_fh

add_files -fileset constrs_1 $xdc_file
set_property used_in_synthesis true [get_files $xdc_file]

# ==================================================================================
# Generate Output Products
# ==================================================================================
puts "Generating output products..."
generate_target all [get_files $project_dir/$project_name.srcs/sources_1/bd/$bd_name/${bd_name}.bd]

# ==================================================================================
# Project Summary
# ==================================================================================
puts ""
puts "=========================================="
puts "Project Creation Complete!"
puts "=========================================="
puts "Project: $project_name"
puts "Location: $project_dir"
puts "Board: BKB220 (Zynq 7020)"
puts ""
puts "UART Pin Assignment:"
puts "  TX (PMOD1_d0): Y7"
puts "  RX (PMOD1_d1): Y9"
puts ""
puts "Memory Map:"
puts "  AXI DMA TX: [get_property OFFSET [get_bd_addr_segs {processing_system7_0/Data/SEG_axi_dma_tx_Reg}]]"
puts "  AXI DMA RX: [get_property OFFSET [get_bd_addr_segs {processing_system7_0/Data/SEG_axi_dma_rx_Reg}]]"
if {[llength [get_bd_cells -quiet uart_hls_0]] > 0} {
    puts "  UART HLS:   [get_property OFFSET [get_bd_addr_segs {processing_system7_0/Data/SEG_uart_hls_0_Reg}]]"
}
puts ""
puts "Next Steps:"
puts "1. Open project: vivado $project_dir/$project_name.xpr"
puts "2. Add HLS IP if not already done: Tools -> Settings -> IP -> Repository"
puts "3. Run Synthesis: launch_runs synth_1"
puts "4. Run Implementation: launch_runs impl_1"
puts "5. Generate Bitstream: launch_runs impl_1 -to_step write_bitstream"
puts "=========================================="
