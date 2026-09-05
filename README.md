# Parameterized Systolic Array Matrix Multiplier in Verilog

A scalable, parameterizable **N × N** 2D systolic array matrix multiplier implemented in Verilog. The design features integrated boundary skew buffers for autonomous parallel ingestion of matrix operands, fully verified with a self-checking testbench against a golden software reference, and implemented on Xilinx Artix-7 silicon via AMD Vivado.

## Architectural Overview

Standard General Matrix Multiply (GEMM) computations executed on traditional CPUs or von Neumann architectures suffer from memory bandwidth bottlenecks due to repeated reads and writes from external memory.

This systolic array accelerates matrix multiplication (C = A × B) by streaming operands through an N × N grid of tightly coupled Processing Elements (PEs). By using strictly localized point-to-point data forwarding, data reuse is maximized, high-fanout global routing nets are avoided, and high operating clock frequencies (F_max) are maintained.

```
       b[0]         b[1]         b[2]
        |            |            |
     [Delay 0]    [Delay 1]    [Delay 2]
        |            |            |
        v            v            v
a[0] -> [Delay 0] -> [PE 0,0] ---> [PE 0,1] ---> [PE 0,2]
        |               |            |            |
a[1] -> [Delay 1] -> [PE 1,0] ---> [PE 1,1] ---> [PE 1,2]
        |               |            |            |
a[2] -> [Delay 2] -> [PE 2,0] ---> [PE 2,1] ---> [PE 2,2]
```

## Key Architectural Advantages

- **Integrated Hardware Skew Buffers** — Most conventional systolic arrays offload data staggering to software or require external pre-skewed testbench drivers. This design embeds dynamic shift-register delay pipelines (`delay_ele`) directly at the array boundaries, allowing the module to ingest standard un-skewed row and column streams concurrently in a single clock domain.
- **Fully Parameterized (`generate` Constructs)** — Easily reconfigure array dimensions (N), input bit-width (`DATA_WIDTH`), and accumulator bit-width (`R_WIDTH`) directly from top-level parameters without rewriting any interconnect logic.
- **Pipelined Point-to-Point Routing** — Inputs propagate horizontally (a) and vertically (b) through register stages, keeping critical path delays short and independent of array size.

## Module Description

| Module | Description |
|---|---|
| `pe.v` (Processing Element) | Contains a combinational multiplier and an accumulator register. On each rising clock edge, it latches incoming values, computes `acc_result <= acc_result + (a_in * b_in)`, and pipelines `a_in` to the right (`a_out`) and `b_in` downwards (`b_out`). |
| `delay_ele.v` (Boundary Skew Buffer) | A parameterized shift register that introduces an exact *k*-cycle pipeline delay (*k* ∈ [0, N-1]). Handles boundary conditions gracefully with zero delay overhead when `DEPTH == 0`. |
| `arrayy.v` (Top-Level Array) | Instantiates the boundary skew buffers and generates the N × N PE grid. Interconnects are organized using multidimensional wire grids of dimension `[0:N-1][0:N]` horizontally and `[0:N][0:N-1]` vertically. |
| `tb_arrayy.v` (Automated Self-Checking Testbench) | Executes a concurrent golden-model matrix multiplication, streams input matrices into the DUT on negative clock edges to avoid hold-time issues, and validates all N × N results with automated assertions. |

## Hardware Implementation & Timing Results

The design was synthesized and implemented in AMD Vivado using Out-of-Context (OOC) mode targeting an Artix-7 FPGA (`xc7a100tcsg324-1`) at a reference target clock period of 10.0 ns (100 MHz).

### Implementation Metrics Summary

| Metric | 3×3 Array (3-bit) | 7×7 Array (3-bit, 49 PEs) |
|---|---|---|
| Slice LUTs | 98 | ~530 |
| Slice Registers (FFs) | 108 | ~686 |
| Worst Negative Slack (WNS) | +6.333 ns | +1.593 ns |
| Worst Hold Slack (WHS) | +0.157 ns | +0.167 ns |
| Minimum Period (T_min) | 3.667 ns | 8.407 ns |
| Max Frequency (F_max) | 272.7 MHz | 118.95 MHz |
| Peak Throughput | 4.91 GMAC/s | 11.65 GMAC/s |

**Throughput Formula:**

```
Throughput = N² × 2 Operations/Cycle × F_max
```

## Directory Structure

```
├── rtl/
│   ├── pe.v            # Processing element with MAC unit
│   ├── delay_ele.v     # Configurable boundary shift-register pipeline
│   └── arrayy.v        # Parameterized NxN top-level systolic array
├── sim/
│   ├── tb_arrayy.v     # Self-checking testbench with golden model
│   └── tb_arrayy.vcd   # Generated waveform dump file
├── constrs/
│   └── timing.xdc      # Clock and timing constraint definitions
├── docs/
│   ├── timing_summary.png
│   └── utilization_report.png
└── README.md
```

## How to Run Simulation

### Using Icarus Verilog & GTKWave (Command Line)

```bash
# Compile design and testbench
iverilog -g2012 -o systolic_sim rtl/pe.v rtl/delay_ele.v rtl/arrayy.v sim/tb_arrayy.v

# Run the simulation
vvp systolic_sim

# View waveforms
gtkwave tb_arrayy.vcd
```

### Using Vivado GUI

1. Create a new RTL Project in Vivado.
2. Add all `.v` files in `rtl/` under **Design Sources**.
3. Add `sim/tb_arrayy.v` under **Simulation Sources**.
4. In Flow Navigator, click **Run Simulation → Run Behavioral Simulation**.
5. Check the Tcl Console for output verification:
   ```
   >>> TEST PASSED: ALL 9 OUTPUTS MATCH GOLDEN MODEL <<<
   ```

## How to Synthesize in Vivado (Out-of-Context)

To synthesize the module without mapping boundary I/O to physical package pins:

1. Open Vivado and load the source files.
2. Set `arrayy` as the top module.
3. Add `constrs/timing.xdc`:
   ```tcl
   create_clock -period 10.000 -name clk [get_ports clk]
   ```
4. In the Tcl Console, execute:
   ```tcl
   synth_design -top arrayy -part xc7a100tcsg324-1 -mode out_of_context
   opt_design
   place_design
   route_design
   report_utilization -file utilization_report.txt
   report_timing_summary -file timing_summary.txt
   ```
