# FPGA-Based CNN Hardware Accelerator

A modular, high-performance hardware accelerator for Convolutional Neural Networks (CNNs) designed for edge FPGA deployment and tested on the **Xilinx PYNQ-Z2** platform.

This repository contains synthesizable **SystemVerilog RTL**, module-level and top-level **testbenches**, automated **simulation and synthesis scripts**, **Python-based golden models**, test vectors, and Vivado implementation reports.

---

## Repository Structure

```text
FPGA-CNN-Hardware-Accelerator/
│
├── rtl/
│   ├── compute/          # MAC engines, adders, multipliers, and pipelined computation blocks
│   ├── control/          # Accelerator FSM and control logic
│   ├── memory/           # Line buffers and memory management
│   ├── window/           # Sliding-window generators
│   ├── activation/       # Activation functions such as ReLU
│   └── top/              # Top-level integration and FIFO interfaces
│
├── tb/
│   └── tb_cnn_accelerator.sv
│                         # Top-level and module-specific testbenches
│
├── sim/
│   ├── file.list         # RTL simulation file list
│   ├── file_syn.list     # Post-synthesis simulation file list
│   └── run.do            # QuestaSim simulation macro
│
├── constraints/
│   └── pynq_z2_cnn_accelerator.xdc
│                         # PYNQ-Z2 physical and timing constraints
│
├── python/
│   ├── golden_model.py   # Python reference/golden model
│   ├── quantization.py   # Fixed-point quantization utilities
│   └── ...               # Verification and data-generation utilities
│
├── test_vectors/
│   ├── all_zero_input.hex
│   ├── all_zero_kernel.hex
│   ├── all_zero_output.hex
│   └── ...
│                         # Input, kernel, and expected-output test vectors
│
├── vivado_run/
│                         # Vivado project/build working directory
│
├── vivado_reports/
│   ├── utilization/
│   ├── timing/
│   ├── power/
│   └── ...
│                         # Generated synthesis, timing, power, and utilization reports
│
├── docs/
│                         # Architecture specifications and technical documentation
│
├── run_vivado.tcl
│                         # Automated Vivado build, synthesis, and implementation script
│
└── README.md
```

---

## Architecture Overview

The accelerator is designed around a **streaming, line-buffered convolution architecture** to reduce external memory accesses and improve data reuse.

The main processing stages are:

```text
Input Feature Map
        │
        ▼
┌─────────────────────┐
│   Input Stream      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│    Line Buffers     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Sliding Window      │
│    Generator        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Kernel / Weight     │
│      Memory         │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   MAC / Compute     │
│      Engine         │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│    Accumulator      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Quantization /      │
│ Fixed-Point Logic   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│       ReLU          │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│    Output Buffer    │
└─────────────────────┘
```

### Key Architectural Features

* **Streaming data processing**
* **Line-buffered convolution**
* **Sliding-window generation**
* **Parallel MAC computation**
* **Configurable convolution dimensions**
* **Fixed-point arithmetic**
* **Quantization support**
* **ReLU activation**
* **FIFO-based data interfaces**
* **Synthesizable SystemVerilog RTL**
* **FPGA-oriented memory and compute architecture**

---

## Why Line Buffers?

For a convolution window such as a **3×3 kernel**, neighboring windows share most of their input pixels.

Instead of reading every pixel repeatedly from external memory, the accelerator stores previously received rows using **line buffers**.

For a 3×3 convolution:

```text
Current Window:

┌─────┬─────┬─────┐
│ P00 │ P01 │ P02 │
├─────┼─────┼─────┤
│ P10 │ P11 │ P12 │
├─────┼─────┼─────┤
│ P20 │ P21 │ P22 │
└─────┴─────┴─────┘
```

When the window moves by one pixel, most of the data is reused.

This significantly reduces memory bandwidth requirements and allows the accelerator to process data in a **streaming fashion**.

---

## Main Hardware Modules

### Compute

The `rtl/compute/` directory contains the arithmetic datapath, including:

* Multipliers
* Adders
* MAC units
* Accumulators
* Pipelined computation blocks

The compute engine performs the convolution operation:

$$
Y = \sum_{i=0}^{N-1}\sum_{j=0}^{N-1}X_{i,j}W_{i,j}
$$

where:

* `X` = input feature-map values
* `W` = kernel weights
* `Y` = convolution result

---

### Control

The `rtl/control/` directory contains the accelerator's control logic and finite-state machine.

The controller manages:

* Input streaming
* Window generation
* MAC operation
* Accumulation
* Output generation
* Buffer control
* Valid/ready handshaking
* Processing completion

---

### Memory

The `rtl/memory/` directory contains the memory-management logic.

The architecture uses **line buffers** to store previous image rows and provide the sliding-window generator with the required pixels.

This approach improves data reuse while reducing repeated memory accesses.

---

### Sliding Window Generator

The `rtl/window/` directory contains the sliding-window generation logic.

The window generator receives the incoming pixel stream and produces convolution windows for the compute engine.

For a 3×3 convolution, the generator produces:

```text
Pixel Stream
     │
     ▼
Line Buffer 1
Line Buffer 2
     │
     ▼
3×3 Window
     │
     ▼
MAC Engine
```

---

### Activation

The `rtl/activation/` directory contains activation functions.

Currently, the design supports **ReLU (Rectified Linear Unit)**:

$$
ReLU(x)=
\begin{cases}
x & x>0\\
0 & x\leq0
\end{cases}
$$

---

## Verification Environment

The project includes both RTL simulation and Python-based reference models.

### RTL Verification

RTL verification is performed using **QuestaSim/ModelSim**.

The testbench verifies:

* Input streaming
* Window generation
* Convolution results
* MAC operation
* Accumulation
* Quantization
* ReLU operation
* Output data
* Control-state transitions

The main top-level testbench is:

```text
tb/tb_cnn_accelerator.sv
```

---

## Python Golden Model

The `python/` directory contains Python-based reference models used to generate expected results.

The golden model provides an independent software reference against which the RTL output can be compared.

Typical flow:

```text
Input Data
    │
    ▼
Python Golden Model
    │
    ▼
Expected Output
    │
    ▼
HEX Test Vector
    │
    ▼
RTL Simulation
    │
    ▼
RTL Output
    │
    ▼
Comparison
```

Python utilities are also used for:

* Fixed-point conversion
* Quantization
* Test-vector generation
* Expected-output generation
* Verification

---

## Test Vectors

The `test_vectors/` directory contains input, kernel, and expected-output data used for verification.

Example test cases include:

```text
test_vectors/
├── all_zero_input.hex
├── all_zero_kernel.hex
├── all_zero_output.hex
├── balanced_input.hex
├── balanced_kernel.hex
├── balanced_output.hex
├── extreme_input.hex
├── extreme_kernel.hex
└── extreme_output.hex
```

These vectors are designed to test different operating conditions, including:

* Zero inputs
* Zero weights
* Balanced values
* Positive and negative values
* Extreme fixed-point values
* Quantization behavior
* Output correctness

---

# Getting Started

## Prerequisites

The following tools are required.

### Simulation

* QuestaSim or ModelSim
* SystemVerilog support

### Synthesis and Implementation

* AMD/Xilinx Vivado
* PYNQ-Z2 board support files

### Python Verification

* Python 3.x
* NumPy
* Pandas

Example Python environment setup:

```bash
pip install numpy pandas
```

---

# Running the Project

## 1. Running RTL Simulation — QuestaSim

To compile and run the RTL simulation using the provided file lists and QuestaSim macro:

1. Open **QuestaSim**.
2. Navigate to the `sim/` directory.
3. Run the simulation script from the QuestaSim transcript:

```tcl
do run.do
```

The `run.do` script handles the required compilation and simulation commands defined for the project.

The RTL source files are specified through:

```text
sim/file.list
```

---

## 2. Running Vivado Synthesis & Implementation

The project includes an automated Vivado Tcl script:

```text
run_vivado.tcl
```

The script can be executed either through the Vivado GUI or in batch mode.

### GUI Mode

Launch Vivado in GUI mode and execute the build script:

```bash
vivado -mode gui -source run_vivado.tcl
```

### Batch Mode

For automated execution without opening the Vivado GUI:

```bash
vivado -mode batch -source run_vivado.tcl
```

The script is responsible for configuring the Vivado project, adding the required RTL sources and constraints, and running synthesis and implementation.

The PYNQ-Z2 constraints are located in:

```text
constraints/pynq_z2_cnn_accelerator.xdc
```

---

## 3. Vivado Reports

Generated synthesis and implementation reports are stored in:

```text
vivado_reports/
```

Depending on the Vivado script configuration, the reports may include:

```text
vivado_reports/
├── utilization/
├── timing/
├── power/
├── synthesis/
└── implementation/
```

Important metrics include:

* LUT utilization
* Flip-Flop utilization
* BRAM utilization
* DSP utilization
* Maximum operating frequency
* Timing slack
* Dynamic power
* Static power
* Total power

---

# FPGA Target

The accelerator is targeted for the:

**Xilinx PYNQ-Z2**

The design is intended for edge FPGA deployment where computational resources, memory bandwidth, power consumption, and timing are important design constraints.

The FPGA implementation flow is:

```text
SystemVerilog RTL
       │
       ▼
   Elaboration
       │
       ▼
   Synthesis
       │
       ▼
  Optimization
       │
       ▼
 Placement
       │
       ▼
  Routing
       │
       ▼
 Bitstream
       │
       ▼
 PYNQ-Z2 FPGA
```

---

# Fixed-Point Arithmetic

The accelerator uses fixed-point arithmetic to reduce hardware cost compared with floating-point computation.

The Python verification environment is used to model the fixed-point behavior and ensure that the RTL implementation matches the expected quantized results.

The fixed-point flow is:

```text
Floating-Point Model
        │
        ▼
   Quantization
        │
        ▼
 Fixed-Point Values
        │
        ▼
    RTL Model
        │
        ▼
 FPGA Hardware
```

This approach allows the design to balance:

* Numerical accuracy
* Hardware resource usage
* Processing throughput
* Power consumption

---

# Verification Flow

The overall verification methodology is:

```text
              ┌──────────────────┐
              │   Test Vectors   │
              └────────┬─────────┘
                       │
             ┌─────────┴─────────┐
             ▼                   ▼
    ┌─────────────────┐  ┌─────────────────┐
    │ Python Golden   │  │   RTL Design    │
    │     Model       │  │                 │
    └────────┬────────┘  └────────┬────────┘
             │                    │
             ▼                    ▼
    Expected Results         RTL Results
             │                    │
             └─────────┬──────────┘
                       ▼
               ┌───────────────┐
               │    Compare    │
               └───────┬───────┘
                       │
                       ▼
                Pass / Fail
```

---

# Synthesis Flow

The automated synthesis and implementation flow is based on Vivado Tcl automation.

```text
run_vivado.tcl
      │
      ▼
Create Vivado Project
      │
      ▼
Add RTL Sources
      │
      ▼
Add Constraints
      │
      ▼
Set Top Module
      │
      ▼
Run Synthesis
      │
      ▼
Generate Synthesis Reports
      │
      ▼
Run Implementation
      │
      ▼
Generate Timing / Power / Utilization Reports
      │
      ▼
Generate Bitstream
```

---

# Performance Metrics

The accelerator can be evaluated using the following metrics:

### Throughput

Number of convolution operations or output pixels processed per second.

### Latency

Number of clock cycles required to produce the first valid output and complete a processing operation.

### Resource Utilization

The main FPGA resources include:

* LUTs
* Flip-Flops
* BRAMs
* DSP slices

### Timing

Timing analysis is used to determine whether the design satisfies the target clock frequency.

Important parameters include:

* Worst Negative Slack (WNS)
* Total Negative Slack (TNS)
* Maximum frequency
* Setup timing
* Hold timing

### Power

Power reports can be used to analyze:

* Dynamic power
* Static power
* Clock power
* Logic power
* BRAM power
* DSP power

---

# Project Goals

The accelerator is designed to demonstrate the implementation of a CNN convolution engine using FPGA-oriented hardware design techniques.

The main goals are:

* Develop a modular CNN accelerator architecture.
* Implement the design using synthesizable SystemVerilog.
* Reduce memory bandwidth using line buffers and data reuse.
* Exploit parallel MAC computation.
* Support fixed-point arithmetic.
* Verify RTL results against a Python golden model.
* Automate simulation and Vivado synthesis.
* Evaluate FPGA resource utilization, timing, and power.
* Target deployment on the Xilinx PYNQ-Z2 platform.

---

# Technologies Used

| Category           | Technology                |
| ------------------ | ------------------------- |
| HDL                | SystemVerilog             |
| FPGA               | Xilinx PYNQ-Z2            |
| FPGA Tools         | AMD/Xilinx Vivado         |
| Simulation         | QuestaSim / ModelSim      |
| Verification       | Python                    |
| Numerical Modeling | NumPy                     |
| Data Processing    | Pandas                    |
| Automation         | Tcl / Python              |
| Architecture       | Streaming CNN Accelerator |
| Arithmetic         | Fixed-Point               |
| Activation         | ReLU                      |

---

# Documentation

Additional technical documentation and architecture specifications are available in:

```text
docs/
```

This directory may contain:

* Architecture specifications
* Block diagrams
* Design documentation
* Competition requirements
* Verification documentation
* Implementation results

---

# Project Status

The project is under active development.

Current development areas include:

* RTL implementation
* Functional verification
* Fixed-point validation
* FPGA synthesis
* Timing analysis
* Resource optimization
* Power analysis
* PYNQ-Z2 deployment

---

# License

This project is intended for educational and research purposes.

If a specific open-source license is required, add the appropriate license file to the repository.

---

# Authors

Developed as a team project focused on **FPGA-based CNN acceleration, RTL design, verification, and hardware optimization**.

---
