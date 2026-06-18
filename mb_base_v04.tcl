# ============================================================
# mb_base_v04.tcl
# Bare-metal MicroBlaze service processor
# Vivado baseline intent: 2017.4
#
# Architecture:
#   - Area-optimized MicroBlaze
#   - 64 KB local BRAM, no DDR
#   - Clock Wizard creates 100 MHz MB clock from top-level clk_in
#   - MDM debug
#   - AXI UARTLite console
#   - AXI Timer
#   - AXI GPIO: dual channel, 32 output + 32 input
#   - AXI INTC with concat input vector
#   - External AXI4-Lite master exported to proven RTL AXI slave
#   - Timer PWM output exported
# ============================================================

# ----------------------------
# User parameters
# ----------------------------
set DESIGN_NAME        mb_base
set TARGET_PART        xc7a200tfbg676-2
set CLK_IN_FREQ_MHZ    200
set MB_CLK_FREQ_MHZ    100
set UART_BAUD          115200
set MB_BRAM_SIZE_KB    64

set PL_AXI_BASE_ADDR   0x44A00000
set PL_AXI_RANGE       64K

set UART_BASE_ADDR     0x40600000
set UART_RANGE         64K

set GPIO_BASE_ADDR     0x40000000
set GPIO_RANGE         64K

set TIMER_BASE_ADDR    0x41C00000
set TIMER_RANGE        64K

set INTC_BASE_ADDR     0x41200000
set INTC_RANGE         64K

# ----------------------------
# Helper procs
# ----------------------------
proc safe_set_property {prop_list obj} {
    if {[llength $obj] != 0} {
        catch {set_property -dict $prop_list $obj}
    }
}

proc connect_if_exists {net_or_port pin_name} {
    set p [get_bd_pins -quiet $pin_name]
    if {[llength $p] != 0} {
        connect_bd_net $net_or_port $p
    } else {
        puts "INFO: Skipping missing pin $pin_name"
    }
}

# ----------------------------
# Optional project creation
# ----------------------------
if {[llength [get_projects -quiet]] == 0} {
    create_project mb_base_proj ./mb_base_proj -part $TARGET_PART -force
}

# ----------------------------
# Create block design
# ----------------------------
if {[llength [get_bd_designs -quiet $DESIGN_NAME]] != 0} {
    current_bd_design $DESIGN_NAME
} else {
    create_bd_design $DESIGN_NAME
    current_bd_design $DESIGN_NAME
}

# ============================================================
# External ports / interfaces
# ============================================================

set clk_in [create_bd_port -dir I -type clk clk_in]
set_property CONFIG.FREQ_HZ [expr {$CLK_IN_FREQ_MHZ * 1000000}] $clk_in

set reset [create_bd_port -dir I -type rst reset]
set_property CONFIG.POLARITY ACTIVE_HIGH $reset

# UART interface exported as a recognizable interface name
set MB_UART [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:uart_rtl:1.0 MB_UART]

# External AXI4-Lite master to PL RTL
set MB_AXI_REG [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 MB_AXI_REG]
set_property -dict [list \
    CONFIG.PROTOCOL {AXI4LITE} \
    CONFIG.ADDR_WIDTH {32} \
    CONFIG.DATA_WIDTH {32} \
    CONFIG.NUM_READ_OUTSTANDING {2} \
    CONFIG.NUM_WRITE_OUTSTANDING {2} \
] $MB_AXI_REG

# Export MB AXI clock/reset for your external SV AXI slave
set MB_AXI_ACLK [create_bd_port -dir O -type clk MB_AXI_ACLK]
set_property -dict [list \
    CONFIG.ASSOCIATED_BUSIF {MB_AXI_REG} \
    CONFIG.ASSOCIATED_RESET {MB_AXI_ARESETN0} \
    CONFIG.FREQ_HZ [expr {$MB_CLK_FREQ_MHZ * 1000000}] \
] $MB_AXI_ACLK

set MB_AXI_ARESETN0 [create_bd_port -dir O -from 0 -to 0 -type rst MB_AXI_ARESETN0]
#set_property CONFIG.POLARITY ACTIVE_LOW $MB_AXI_ARESETN0

set MB_GPIO_IN  [create_bd_port -dir I -from 31 -to 0 MB_GPIO_IN]
set MB_GPIO_OUT [create_bd_port -dir O -from 31 -to 0 MB_GPIO_OUT]

# PL interrupt input for future/status logic. Width 1 for now.
set PL_INTR [create_bd_port -dir I -from 0 -to 0 PL_INTR]

# Timer PWM output
set MB_PWM [create_bd_port -dir O MB_PWM]

# ============================================================
# IP instances
# ============================================================

set clk_wiz_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:* clk_wiz_0]
safe_set_property [list \
    CONFIG.PRIM_IN_FREQ $CLK_IN_FREQ_MHZ \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $MB_CLK_FREQ_MHZ \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.RESET_TYPE {ACTIVE_HIGH} \
] $clk_wiz_0

set proc_sys_reset_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:* proc_sys_reset_0]

set microblaze_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:* microblaze_0]
safe_set_property [list \
    CONFIG.C_AREA_OPTIMIZED {1} \
    CONFIG.C_D_AXI {1} \
    CONFIG.C_USE_MMU {0} \
    CONFIG.C_USE_ICACHE {0} \
    CONFIG.C_USE_DCACHE {0} \
    CONFIG.C_USE_FPU {0} \
    CONFIG.C_USE_BARREL {0} \
    CONFIG.C_USE_DIV {0} \
    CONFIG.C_USE_HW_MUL {0} \
    CONFIG.C_DEBUG_ENABLED {1} \
    CONFIG.C_USE_INTERRUPT {1} \
] $microblaze_0

set dlmb_bus [ create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_v10:* dlmb_v10_0]
set ilmb_bus [ create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_v10:* ilmb_v10_0]

set ilmb_bram_if_cntlr [create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_bram_if_cntlr:* ilmb_bram_if_cntlr]
set dlmb_bram_if_cntlr [create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_bram_if_cntlr:* dlmb_bram_if_cntlr]
set lmb_bram [create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:* lmb_bram]
safe_set_property [list CONFIG.Memory_Type {True_Dual_Port_RAM}] $lmb_bram
#set_property range 128K [get_bd_addr_segs {microblaze_0_modules/microblaze_0/Data/SEG_dlmb_bram_if_cntlr_Mem}]
#set_property range 128K [get_bd_addr_segs {microblaze_0_modules/microblaze_0/Instruction/SEG_ilmb_bram_if_cntlr_Mem}]
#set_property range $MB_BRAM_SIZE_KB [get_bd_addr_segs {microblaze_0_modules/microblaze_0/Data/SEG_dlmb_bram_if_cntlr_Mem}]
#set_property range $MB_BRAM_SIZE_KB [get_bd_addr_segs {microblaze_0_modules/microblaze_0/Instruction/SEG_ilmb_bram_if_cntlr_Mem}]

$MB_BRAM_SIZE_KB

set axi_interconnect_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:* axi_interconnect_0]
set_property -dict [list \
    CONFIG.NUM_MI {5} \
    CONFIG.NUM_SI {1} \
] $axi_interconnect_0

set axi_uartlite_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:* axi_uartlite_0]
safe_set_property [list \
    CONFIG.C_BAUDRATE $UART_BAUD \
    CONFIG.C_DATA_BITS {8} \
    CONFIG.C_USE_PARITY {0} \
] $axi_uartlite_0

set axi_timer_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_timer:* axi_timer_0]
safe_set_property [list \
    CONFIG.enable_timer2 {1} \
#    CONFIG.C_ONE_TIMER_ONLY {0} \
] $axi_timer_0

set axi_gpio_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:* axi_gpio_0]
safe_set_property [list \
    CONFIG.C_IS_DUAL {1} \
    CONFIG.C_GPIO_WIDTH {32} \
    CONFIG.C_GPIO2_WIDTH {32} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_ALL_INPUTS_2 {1} \
    CONFIG.C_INTERRUPT_PRESENT {1} \
] $axi_gpio_0

set axi_intc_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_intc:* axi_intc_0]
safe_set_property [list \
    CONFIG.C_HAS_FAST {0} \
    CONFIG.C_IRQ_IS_LEVEL {1} \
    CONFIG.C_KIND_OF_INTR {0xFFFFFFF5} \
    CONFIG.C_KIND_OF_EDGE {0x00000004} \
    CONFIG.C_KIND_OF_LVL {0xFFFFFFFF} \
    CONFIG.C_IRQ_CONNECTION {0} \
] $axi_intc_0

set xlconcat_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:* xlconcat_0]
set_property -dict [list CONFIG.NUM_PORTS {4}] $xlconcat_0

set mdm_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:mdm:* mdm_0]
safe_set_property [list CONFIG.C_USE_UART {0}] $mdm_0

# ============================================================
# Clock/reset connections
# ============================================================

connect_bd_net $clk_in [get_bd_pins clk_wiz_0/clk_in1]
connect_bd_net $reset  [get_bd_pins clk_wiz_0/reset]

set mb_clk [get_bd_pins clk_wiz_0/clk_out1]
set mb_rstn [get_bd_pins proc_sys_reset_0/peripheral_aresetn]

connect_bd_net $mb_clk [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins proc_sys_reset_0/dcm_locked]
connect_bd_net $reset [get_bd_pins proc_sys_reset_0/ext_reset_in]

# Export clock/reset for external PL AXI slave
connect_bd_net $mb_clk $MB_AXI_ACLK
connect_bd_net $mb_rstn $MB_AXI_ARESETN0

# MicroBlaze, LMB, interconnect clocks
connect_bd_net $mb_clk [get_bd_pins microblaze_0/Clk]
connect_bd_net $mb_clk [get_bd_pins ilmb_bram_if_cntlr/LMB_Clk]
connect_bd_net $mb_clk [get_bd_pins dlmb_bram_if_cntlr/LMB_Clk]
connect_bd_net $mb_clk [get_bd_pins ilmb_v10_0/LMB_Clk]
connect_bd_net $mb_clk [get_bd_pins dlmb_v10_0/LMB_Clk]
connect_bd_net $mb_clk [get_bd_pins axi_interconnect_0/ACLK]
connect_bd_net $mb_clk [get_bd_pins axi_interconnect_0/S00_ACLK]
connect_bd_net $mb_clk [get_bd_pins axi_interconnect_0/M00_ACLK]
connect_bd_net $mb_clk [get_bd_pins axi_interconnect_0/M01_ACLK]
connect_bd_net $mb_clk [get_bd_pins axi_interconnect_0/M02_ACLK]
connect_bd_net $mb_clk [get_bd_pins axi_interconnect_0/M03_ACLK]
connect_bd_net $mb_clk [get_bd_pins axi_interconnect_0/M04_ACLK]
connect_bd_net $mb_clk [get_bd_pins axi_uartlite_0/s_axi_aclk]
connect_bd_net $mb_clk [get_bd_pins axi_timer_0/s_axi_aclk]
connect_bd_net $mb_clk [get_bd_pins axi_gpio_0/s_axi_aclk]
connect_bd_net $mb_clk [get_bd_pins axi_intc_0/s_axi_aclk]

# Some MDM configs do not have S_AXI clock/reset pins. Connect only if present.
connect_if_exists $mb_clk "mdm_0/S_AXI_ACLK"

# Reset connections
connect_bd_net [get_bd_pins proc_sys_reset_0/mb_reset] [get_bd_pins microblaze_0/Reset]

connect_bd_net [get_bd_pins proc_sys_reset_0/bus_struct_reset] [get_bd_pins ilmb_v10_0/SYS_Rst]
connect_bd_net [get_bd_pins proc_sys_reset_0/bus_struct_reset] [get_bd_pins dlmb_v10_0/SYS_Rst]
connect_bd_net [get_bd_pins proc_sys_reset_0/bus_struct_reset] [get_bd_pins ilmb_bram_if_cntlr/LMB_Rst]
connect_bd_net [get_bd_pins proc_sys_reset_0/bus_struct_reset] [get_bd_pins dlmb_bram_if_cntlr/LMB_Rst]

connect_bd_net $mb_rstn [get_bd_pins axi_interconnect_0/ARESETN]
connect_bd_net $mb_rstn [get_bd_pins axi_interconnect_0/S00_ARESETN]
connect_bd_net $mb_rstn [get_bd_pins axi_interconnect_0/M00_ARESETN]
connect_bd_net $mb_rstn [get_bd_pins axi_interconnect_0/M01_ARESETN]
connect_bd_net $mb_rstn [get_bd_pins axi_interconnect_0/M02_ARESETN]
connect_bd_net $mb_rstn [get_bd_pins axi_interconnect_0/M03_ARESETN]
connect_bd_net $mb_rstn [get_bd_pins axi_interconnect_0/M04_ARESETN]

connect_bd_net $mb_rstn [get_bd_pins axi_uartlite_0/s_axi_aresetn]
connect_bd_net $mb_rstn [get_bd_pins axi_timer_0/s_axi_aresetn]
connect_bd_net $mb_rstn [get_bd_pins axi_gpio_0/s_axi_aresetn]
connect_bd_net $mb_rstn [get_bd_pins axi_intc_0/s_axi_aresetn]
connect_if_exists $mb_rstn "mdm_0/S_AXI_ARESETN"

# ============================================================
# MicroBlaze local memory connections
# ============================================================

connect_bd_intf_net [get_bd_intf_pins ilmb_v10_0/LMB_M] [get_bd_intf_pins microblaze_0/ILMB]
connect_bd_intf_net [get_bd_intf_pins dlmb_v10_0/LMB_M] [get_bd_intf_pins microblaze_0/DLMB]

connect_bd_intf_net [get_bd_intf_pins ilmb_v10_0/LMB_Sl_0] [get_bd_intf_pins ilmb_bram_if_cntlr/SLMB]
connect_bd_intf_net [get_bd_intf_pins dlmb_v10_0/LMB_Sl_0] [get_bd_intf_pins dlmb_bram_if_cntlr/SLMB]
connect_bd_intf_net [get_bd_intf_pins ilmb_bram_if_cntlr/BRAM_PORT] [get_bd_intf_pins lmb_bram/BRAM_PORTA]
connect_bd_intf_net [get_bd_intf_pins dlmb_bram_if_cntlr/BRAM_PORT] [get_bd_intf_pins lmb_bram/BRAM_PORTB]

# ============================================================
# AXI connections
# ============================================================

connect_bd_intf_net [get_bd_intf_pins microblaze_0/M_AXI_DP] [get_bd_intf_pins axi_interconnect_0/S00_AXI]

connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins axi_uartlite_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M01_AXI] [get_bd_intf_pins axi_gpio_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M02_AXI] [get_bd_intf_pins axi_timer_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M03_AXI] [get_bd_intf_pins axi_intc_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M04_AXI] $MB_AXI_REG

# MDM debug interface
connect_bd_intf_net [get_bd_intf_pins mdm_0/MBDEBUG_0] [get_bd_intf_pins microblaze_0/DEBUG]
connect_bd_net [get_bd_pins mdm_0/Debug_SYS_Rst] [get_bd_pins proc_sys_reset_0/mb_debug_sys_rst]

# ============================================================
# UART/GPIO/PWM/interrupt connections
# ============================================================

connect_bd_intf_net [get_bd_intf_pins axi_uartlite_0/UART] $MB_UART

connect_bd_net $MB_GPIO_OUT [get_bd_pins axi_gpio_0/gpio_io_o]
connect_bd_net $MB_GPIO_IN  [get_bd_pins axi_gpio_0/gpio2_io_i]

# AXI Timer PWM output. Pin name in 2017.4 is usually pwm0.
connect_bd_net [get_bd_ports MB_PWM] [get_bd_pins axi_timer_0/pwm0]

# Interrupts into concat -> AXI INTC -> MicroBlaze
# Concat inputs:
#   In0 = PL_INTR[0]
#   In1 = AXI Timer interrupt
#   In2 = UARTLite interrupt
#   In3 = AXI GPIO interrupt, if present
connect_bd_net $PL_INTR [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins axi_timer_0/interrupt] [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins axi_uartlite_0/interrupt] [get_bd_pins xlconcat_0/In2]
connect_bd_net [get_bd_pins axi_gpio_0/ip2intc_irpt] [get_bd_pins xlconcat_0/In3]

connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins axi_intc_0/intr]
connect_bd_intf_net [get_bd_intf_pins microblaze_0/INTERRUPT] [get_bd_intf_pins axi_intc_0/interrupt]

# ============================================================
# Address map
# ============================================================

assign_bd_address

# Force known addresses where segment names resolve.
set uart_seg [get_bd_addr_segs -quiet microblaze_0/Data/SEG_axi_uartlite_0_Reg]
if {[llength $uart_seg] != 0} {
    set_property range $UART_RANGE $uart_seg
    set_property offset $UART_BASE_ADDR $uart_seg
}

set gpio_seg [get_bd_addr_segs -quiet microblaze_0/Data/SEG_axi_gpio_0_Reg]
if {[llength $gpio_seg] != 0} {
    set_property range $GPIO_RANGE $gpio_seg
    set_property offset $GPIO_BASE_ADDR $gpio_seg
}

set timer_seg [get_bd_addr_segs -quiet microblaze_0/Data/SEG_axi_timer_0_Reg]
if {[llength $timer_seg] != 0} {
    set_property range $TIMER_RANGE $timer_seg
    set_property offset $TIMER_BASE_ADDR $timer_seg
}

set intc_seg [get_bd_addr_segs -quiet microblaze_0/Data/SEG_axi_intc_0_Reg]
if {[llength $intc_seg] != 0} {
    set_property range $INTC_RANGE $intc_seg
    set_property offset $INTC_BASE_ADDR $intc_seg
}



#if {[llength $MB_BRAM_SIZE_KB] != 0} {
    #set_property range $INTC_RANGE $intc_seg
    #set_property offset $INTC_BASE_ADDR $intc_seg


#}

# External PL AXI address segment names may vary by Vivado release.
# If Vivado does not auto-create the external segment, assign once in
# Address Editor and export TCL to confirm the exact segment name.

# ============================================================
# Group IP in Block Design
# ============================================================
group_bd_cells microblaze_0_local_memory [get_bd_cells ilmb_bram_if_cntlr] [get_bd_cells dlmb_bram_if_cntlr] [get_bd_cells ilmb_v10_0] [get_bd_cells dlmb_v10_0] [get_bd_cells lmb_bram]
set_property name ILMB [get_bd_intf_pins microblaze_0_local_memory/LMB_M]
set_property name DLMB [get_bd_intf_pins microblaze_0_local_memory/LMB_M1]
set_property name LMB_Clk [get_bd_pins microblaze_0_local_memory/MB_AXI_ACLK]
#group_bd_cells microblaze_0_local_memory [get_bd_cells ilmb_bram_if_cntlr] [get_bd_cells dlmb_bram_if_cntlr] [get_bd_cells lmb_bram]
group_bd_cells microblaze_0_modules [get_bd_cells axi_intc_0] [get_bd_cells mdm_0] [get_bd_cells proc_sys_reset_0] [get_bd_cells microblaze_0] [get_bd_cells clk_wiz_0] [get_bd_cells axi_interconnect_0] [get_bd_cells microblaze_0_local_memory]

# ============================================================
# Validate/save/wrapper
# ============================================================

regenerate_bd_layout
validate_bd_design
save_bd_design

# Wrapper generation path varies depending on project location.
# Keep this non-fatal for script iteration.
close_bd_design [get_bd_designs $DESIGN_NAME]

#catch {
#    make_wrapper -files [get_files ${DESIGN_NAME}.bd] -top
#    add_files -norecurse ${DESIGN_NAME}_wrapper.vhd
#}

puts "----------------------------------------------"
puts "        mb_base v04 block design created.     "
puts "                                              "
puts "             Create Wrapper File              "
puts "----------------------------------------------"

# ============================================================
# Validate/save/wrapper
# ============================================================
#close_bd_design [get_bd_designs mb_base]
#make_wrapper -files [get_files E:/work/ms8607/ms8607.srcs/sources_1/bd/mb_base/mb_base.bd] -top
#add_files -norecurse E:/work/ms8607/ms8607.srcs/sources_1/bd/mb_base/hdl/mb_base_wrapper.vhd

#puts "Generated the wrapper file."


