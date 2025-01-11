# Copyright (C) 2022 Xilinx, Inc
# SPDX-License-Identifier: BSD-3-Clause

##-----------------------PL_KEY----------------------------

set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports push_button[0]]
set_property -dict {PACKAGE_PIN T17 IOSTANDARD LVCMOS33} [get_ports push_button[1]]
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports push_button[2]]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports push_button[3]]

##-----------------------PL_LED----------------------------
set_property -dict {PACKAGE_PIN W13 IOSTANDARD LVCMOS33} [get_ports led[0]]
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports led[1]]
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports led[2]]
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports led[3]]

## using 3 pmod as Arduino GPIO
#set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[0]}]
#set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[1]}]
#set_property -dict {PACKAGE_PIN U13 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[2]}]
#set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[3]}]
#set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[4]}]
#set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[5]}]
#set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[6]}]
#set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[7]}]
#set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[8]}]
#set_property -dict {PACKAGE_PIN V18 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[9]}]
#set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[10]}]
#set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[11]}]
#set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[12]}]
#set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[13]}]
#set_property -dict {PACKAGE_PIN Y11 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[14]}]
#set_property -dict {PACKAGE_PIN Y12 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[15]}]
#set_property -dict {PACKAGE_PIN W11 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[16]}]
#set_property -dict {PACKAGE_PIN V11 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[17]}]
#set_property -dict {PACKAGE_PIN T5 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[18]}]
#set_property -dict {PACKAGE_PIN U10 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[19]}]
#set_property PULLUP true [get_ports {arduino_gpio_tri_io[*]}]

### Arduino SCL
#set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33} [get_ports ar_pg_clk]

##----------------------PMOD1-   using 3 pmod as Arduino GPIO--------------------------

set_property -dict {PACKAGE_PIN Y7 IOSTANDARD LVCMOS33}  [get_ports {arduino_gpio_tri_io[0]}]
set_property -dict {PACKAGE_PIN Y9 IOSTANDARD LVCMOS33}  [get_ports {arduino_gpio_tri_io[1]}]
set_property -dict {PACKAGE_PIN W10 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[2]}]
set_property -dict {PACKAGE_PIN W11 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[3]}]
set_property -dict {PACKAGE_PIN Y6 IOSTANDARD LVCMOS33}  [get_ports {arduino_gpio_tri_io[4]}]
set_property -dict {PACKAGE_PIN Y8 IOSTANDARD LVCMOS33}  [get_ports {arduino_gpio_tri_io[5]}]
set_property -dict {PACKAGE_PIN W9 IOSTANDARD LVCMOS33}  [get_ports {arduino_gpio_tri_io[6]}]
set_property -dict {PACKAGE_PIN Y11 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[7]}]

#----------------------PMOD2---using 3 pmod as Arduino GPIO------------------------

set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[8]}]
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[9]}]
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[10]}]
set_property -dict {PACKAGE_PIN Y14 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[11]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[12]}]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[13]}]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[14]}]
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[15]}]

#----------------------PMOD3----using 3 pmod as Arduino GPIO-----------------------

set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[16]}]
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[17]}]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[18]}]
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {arduino_gpio_tri_io[19]}]
#set_property -dict {PACKAGE_PIN W15 IOSTANDARD LVCMOS33} [get_ports pmod3_d4]
#set_property -dict {PACKAGE_PIN Y17 IOSTANDARD LVCMOS33} [get_ports pmod3_d5]
#set_property -dict {PACKAGE_PIN W20 IOSTANDARD LVCMOS33} [get_ports pmod3_d6]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports ar_pg_clk]


