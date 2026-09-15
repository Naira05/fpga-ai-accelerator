# ============================================================================
# IEEE SSCS Egypt 2026 - QuestaSim Automation Script
# Using file.list compilation flow with log file generation
# ============================================================================

# 0. Quit active simulation and close open dataset locks
quit -sim -f
dataset close -all
catch { file delete -force vsim.wlf wlft* modelsim.ini_new simulation.log }

# 1. Open transcript log file (Overwrites previous run logs)
transcript file simulation.log

# 2. Refresh working library
if { [file exists work] } {
    vdel -lib work -all
}
vlib work
vmap work work

# 3. Compile system design and testbench using file.list
echo "==> Compiling source files from file.list..."
vlog -sv -f file.list

# 4. Optimize and Elaborate Top-Level Testbench
echo "==> Elaborating Design..."
vsim -voptargs="+acc" work.tb_cnn_accelerator

# 5. Configure Waveform Viewer
echo "==> Adding Waveforms..."
log -r /*
add wave *

# 6. Execute Simulation
echo "==> Running Simulation..."
run -all

# 7. Fit Waveforms to Window
wave zoomfull

# 8. Close transcript log file
transcript file ""