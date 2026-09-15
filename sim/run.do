# ============================================================================
# IEEE SSCS Egypt 2026 - QuestaSim Automation Script
# Using file.list compilation flow
# ============================================================================

# 1. Refresh working library
if { [file exists work] } {
    vdel -lib work -all
}
vlib work
vmap work work

# 2. Compile system design and testbench using file.list
echo "==> Compiling source files from file.list..."
vlog -sv -f file.list

# 3. Optimize and Elaborate Top-Level Testbench
echo "==> Elaborating Design..."
vsim -voptargs="+acc" work.tb_cnn_accelerator

# 4. Configure Waveform Viewer
echo "==> Adding Waveforms..."
log -r /*

add wave -noupdate -group "Top TB Signals" /tb_cnn_accelerator/*
add wave -noupdate -group "CNN Accelerator DUT" /tb_cnn_accelerator/dut/*
add wave -noupdate -group "Controller" /tb_cnn_accelerator/dut/controller_inst/*
add wave -noupdate -group "Window Gen" /tb_cnn_accelerator/dut/window_gen_inst/*
add wave -noupdate -group "MAC Engine" /tb_cnn_accelerator/dut/mac_engine_inst/*

# 5. Execute Simulation
echo "==> Running Simulation..."
run -all

# 6. Fit Waveforms to Window
wave zoomfull