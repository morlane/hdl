################################################################################
# File    : ac701_test_top.xdc
# Target  : Xilinx AC701 / Artix-7 XC7A200T-2FBG676C
# Top     : ac701_test_top
# Source  : Generated from ac701_test_top.vhd top-level ports
# Notes   : Only constrains currently active top-level ports.
################################################################################

################################################################################
# AC701 200 MHz differential system clock
# U51 SiTime 200 MHz oscillator -> FPGA bank 34 MRCC
################################################################################
set_property PACKAGE_PIN R3 [get_ports SYSCLK_P]
set_property PACKAGE_PIN P3 [get_ports SYSCLK_N]
set_property IOSTANDARD LVDS_25 [get_ports SYSCLK_P]
set_property IOSTANDARD LVDS_25 [get_ports SYSCLK_N]
set_property DIFF_TERM FALSE [get_ports SYSCLK_P]
set_property DIFF_TERM FALSE [get_ports SYSCLK_N]

create_clock -period 5.000 -name SYSCLK [get_ports SYSCLK_P]

################################################################################
# AC701 CPU reset pushbutton SW8
# Board signal CPU_RESET, active-high pushbutton into FPGA
################################################################################
set_property PACKAGE_PIN U4 [get_ports RESET]
set_property IOSTANDARD LVCMOS15 [get_ports RESET]

################################################################################
# AC701 USB-to-UART bridge, Silicon Labs CP2103GM U44 / connector J17
# FPGA UART_RXD is driven by CP2103 TXD.
# FPGA UART_TXD drives CP2103 RXD.
################################################################################
set_property PACKAGE_PIN T19 [get_ports UART_RXD]
set_property IOSTANDARD LVCMOS18 [get_ports UART_RXD]

set_property PACKAGE_PIN U19 [get_ports UART_TXD]
set_property IOSTANDARD LVCMOS18 [get_ports UART_TXD]
set_property SLEW SLOW [get_ports UART_TXD]
set_property DRIVE 8 [get_ports UART_TXD]

################################################################################
# Optional future top-level ports from ac701_test_top.vhd
# Uncomment only after the VHDL top-level ports are enabled.
################################################################################

# GPIO_IN / GPIO_OUT / PWM_OUT / PL_INTR_IN are currently commented out in VHDL.
# Leaving them unconstrained prevents Vivado from seeing ports that do not exist.

# Example AC701 user LED pins, useful later if GPIO_OUT[3:0] is mapped to LEDs:
# set_property PACKAGE_PIN M26      [get_ports {GPIO_OUT[0]}]
# set_property PACKAGE_PIN T24      [get_ports {GPIO_OUT[1]}]
# set_property PACKAGE_PIN T25      [get_ports {GPIO_OUT[2]}]
# set_property PACKAGE_PIN R26      [get_ports {GPIO_OUT[3]}]
# set_property IOSTANDARD LVCMOS33  [get_ports {GPIO_OUT[3:0]}]
# set_property SLEW SLOW            [get_ports {GPIO_OUT[3:0]}]
# set_property DRIVE 8              [get_ports {GPIO_OUT[3:0]}]

# Example AC701 user DIP switch pins, useful later if GPIO_IN[3:0] is mapped to switches:
# set_property PACKAGE_PIN R8       [get_ports {GPIO_IN[0]}]
# set_property PACKAGE_PIN P8       [get_ports {GPIO_IN[1]}]
# set_property PACKAGE_PIN R7       [get_ports {GPIO_IN[2]}]
# set_property PACKAGE_PIN R6       [get_ports {GPIO_IN[3]}]
# set_property IOSTANDARD LVCMOS15  [get_ports {GPIO_IN[3:0]}]

################################################################################
# End
################################################################################

