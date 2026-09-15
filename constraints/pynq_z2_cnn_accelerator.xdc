############################################################
# CNN Accelerator - Vivado Constraints
# Target: Xilinx Zynq-7000 XC7Z020CLG400-1
############################################################

############################################################
# Clock
############################################################

create_clock -name clk -period  6.250 [get_ports clk]

############################################################
# Reset
############################################################

# Asynchronous active-low reset
# No timing constraint required for rst_n.
# Functional reset behavior is handled in RTL.