############################################################
# CNN Accelerator - Vivado Constraints
# Target: Xilinx Zynq-7000 XC7Z020CLG400-1
############################################################

############################################################
# Clock
############################################################

# 100 MHz clock
# Period = 10 ns
create_clock -name clk -period  6.154 [get_ports clk]

############################################################
# Reset
############################################################

# Asynchronous active-low reset
# No timing constraint required for rst_n.
# Functional reset behavior is handled in RTL.