# DARE-Mul: A Dynamic Region-Evolving Approximate Multiplier for Configurable-Adaptive Energy–Accuracy Optimization in AI Accelerators

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![FPGA: Artix-7](https://img.shields.io/badge/FPGA-Xilinx%20Artix--7%20XC7A100T-orange.svg)]()
[![ASIC: SKY130](https://img.shields.io/badge/ASIC-SkyWater%20SKY130-green.svg)]()
[![Vivado: 2023.1](https://img.shields.io/badge/Vivado-2023.1-red.svg)]()
[![Accuracy: 99.24%](https://img.shields.io/badge/ResNet--18%20Accuracy-99.24%25-brightgreen.svg)]()

This repository hosts the official implementation, simulation testbenches, FPGA synthesis setups, ASIC physical-design flows, and complete experimental evaluations for **DARE-Mul (Dynamic Region-Evolving Approximate Multiplier)**.

---

## 📖 Overview

In modern Artificial Intelligence (AI) acceleration, multiply-accumulate (MAC) units represent the primary consumer of dynamic switching energy and computational latency. While approximate computing significantly cuts hardware complexity, existing approximate multipliers typically utilize **static, fixed approximation regions** or instantaneous thresholding policies. Under dynamically varying neural network workloads (e.g., changing layer depths, activation sparsity, and operand distributions), static allocation causes excessive accuracy degradation or fails to capitalize on energy-saving opportunities.

**DARE-Mul** overcomes this fundamental limitation via **temporal workload awareness and bounded online boundary regulation**:
- **Dynamic Region Evolution Unit (DREU):** A lightweight synchronous controller tracking operand significance and switching statistics with exponential history smoothing.
- **Three Dynamically Scaled Regions:** Dynamically assigns partial-product columns into *Exact* ($S_{i,j} \ge B_E$), *Intermediate* ($B_A < S_{i,j} < B_E$), and *Approximate* ($S_{i,j} \le B_A$) regions.
- **Adaptive Partial-Product Generation & Reduction Tree:** Utilizes mixed exact and dual-mode 4:2 approximate compressors controlled by a single unified region code.
- **Hybrid Exact–Approximate Accumulator:** Reconfigures carry-propagation chains dynamically according to real-time workload sensitivity.
- **Hardware-Proven Stability:** Mathematical guarantee bounding boundary migration to $\le \eta\lambda$ per interval within finite clipped ranges, preventing precision oscillations.

---

## 🏛️ Architecture Overview

```
                      +-----------------------------+
                      |   Operands A(t) & B(t)      |
                      +--------------+--------------+
                                     |
               +---------------------+---------------------+
               |                                           |
               v                                           v
   +-----------------------+                   +-----------------------+
   | Operand Analysis Unit |                   |   Partial-Product     |
   | (Leading-1 & Activity)|                   |      Generation       |
   +-----------+-----------+                   +-----------+-----------+
               |                                           |
               v                                           |
   +-----------------------+                               |
   | Dynamic Region Evol.  |                               |
   |     Unit (DREU)       |==== Region Code ===============+
   | (Observe-Smooth-Upd)  |        (BE, BA)               |
   +-----------------------+                               v
                                               +-----------------------+
                                               |  Adaptive Reduction   |
                                               |   Tree (ART - 4:2)    |
                                               +-----------+-----------+
                                                           |
                                                           v
                                               +-----------------------+
                                               |    Hybrid Exact-      |
                                               | Approximate Accumulator|
                                               +-----------+-----------+
                                                           |
                                                           v
                                               +-----------------------+
                                               |   Product Output P    |
                                               +-----------------------+
```

---

## 📊 Key Results Summary

### 1. Common-Condition FPGA Benchmark (Artix-7 XC7A100T, 16-bit, Vivado 2023.1)
All designs evaluated under identical conditions (4 pipeline stages, 10,000 switching vectors, 0.95 V, 25°C, 5 placement seeds):

| Architecture | Power (mW) | Delay (ns) | Achieved Freq. | PDP (pJ) | NMED | RRMSE | Task Acc. (%) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Kim et al. [21]** (Logarithmic) | 72.44 | 5.95 | 168 MHz | 431.00 | 0.0193 | 0.0204 | 98.74 |
| **Pan et al. [22]** (PTL) | 72.21 | 5.92 | 169 MHz | 427.50 | 0.0174 | 0.0183 | 98.81 |
| **Guo et al. [23]** (Approx. Booth) | 72.11 | 5.88 | 170 MHz | 424.00 | 0.0154 | 0.0163 | 98.93 |
| **Rizos et al. [24]** (Wallace GA) | 72.12 | 5.90 | 169 MHz | 425.50 | 0.0183 | 0.0194 | 98.88 |
| **Huang et al. [25]** (MSAM) | 71.97 | 5.85 | 171 MHz | 421.00 | 0.0125 | 0.0132 | 99.02 |
| **Vo & Nguyen-Ly [26]** (Sparse DNN)| 72.10 | 5.86 | 171 MHz | 422.50 | 0.0135 | 0.0143 | 98.97 |
| **Jeong et al. [27]** (SEAM) | 72.08 | 5.82 | 172 MHz | 419.50 | 0.0106 | 0.0112 | 99.08 |
| **Fairoose & Mishra [28]** (Compressor)| 72.07 | 5.80 | 172 MHz | 418.00 | 0.0097 | 0.0102 | 99.11 |
| **Rathod et al. [29]** (Switching) | 72.04 | 5.83 | 172 MHz | 420.00 | 0.0116 | 0.0122 | 99.05 |
| **Lim et al. [30]** (DCAA/ERU) | 72.15 | 5.78 | 173 MHz | 417.00 | 0.0087 | 0.0092 | 99.14 |
| **Proposed DARE-Mul** | **72.79** | **5.75** | **174 MHz** | **418.55** | **0.0068** | **0.0071** | **99.24** |

- **Lowest Delay:** 5.75 ns post-route critical path (174 MHz achieved).
- **Lowest Error:** NMED is **50% lower** than the 10-baseline mean and 22% lower than the closest baseline.
- **Highest Accuracy:** 99.24% on ResNet-18 image classification.

### 2. Adaptation Gains under Dynamically Varying CNN Workloads
Under non-stationary workload transitions (ResNet-18 on CIFAR-10):
- **PDP Improvement:** +21.8% over static approximation.
- **Mean Error Distance (MED):** Reduced by 29.4% (from 2.47 to 1.74).
- **Boundary Oscillation ($\Omega$):** Reduced from 0.92 (static) and 0.74 (threshold) to **0.19** (79.3% reduction).

### 3. Extended Deployments & Cross-Domain Validation
- **ASIC Physical Design (SkyWater SKY130):** 8-bit combinational DARE-Mul variant delivers **17.0% cell area reduction** (1120 µm² vs 1350 µm²), **22.6% lower power** (1.51 mW vs 1.95 mW), **16.2% faster delay** (1.24 ns vs 1.48 ns), and **35.3% lower PDP** (1.87 pJ vs 2.89 pJ) with zero DRC/LVS violations across SS/TT/FF corners.
- **Edge Keyword Spotting (Google Speech Commands v2):** Board-level energy per inference drops by **41.7%** (348.5 µJ) in adaptive mode and **47.3%** (315.3 µJ) in low-activity bypass mode with 96.2% keyword accuracy.
- **Robotic Navigation (TurtleBot 4, Kria KR260, KITTI):** End-to-end traversal energy per 100 m reduced by **35.3%** (12.1 J vs 18.7 J) while maintaining a safe 3% collision rate.
- **4×4 Systolic Array / NPU Integration:** Peak array power reduced by **25.3%** (233.2 mW vs 312 mW) with an effective throughput efficiency of **2.31 TOPS/W** (+20.3% gain).
- **ImageNet Software Error Injection (50,000 images):**
  - **ResNet-50 (INT8):** Only 0.08 percentage-point Top-1 drop (75.94% vs 76.02%).
  - **ViT-B/16 (INT8):** Only 0.23 percentage-point Top-1 drop (80.62% vs 80.85%).

---

## 📁 Repository Structure

```
Dare-mul/
├── dare_mul.xpr                   # Vivado 2023.1 project definition
├── dare_mul.srcs/                 # Hardware RTL source codes and testbenches
│   ├── sources_1/new/
│   │   ├── dare_mul_top.v         # Top-level multiplier pipeline integration
│   │   ├── dreu.v                 # Dynamic Region Evolution Unit (FSM & controller)
│   │   ├── operand_analysis.v     # Leading-one detector & XOR activity monitor
│   │   ├── partial_product_generator.v # Exact, intermediate, and approximate PPG
│   │   ├── adaptive_reduction_tree.v   # Configurable 4:2 compressor reduction tree
│   │   ├── hybrid_accumulator.v   # Exact/approximate carry-chain accumulator
│   │   └── runtime_feedback.v     # Closed-loop monitoring & statistics
│   ├── constrs_1/new/
│   │   └── Constraints.xdc        # Artix-7 timing and placement constraints
│   └── sim_1/new/
│       ├── dare_mul_tb.v          # Comprehensive behavioral & ablation testbench
│       └── test_vectors.txt       # Simulation stimulus vectors
├── results/                       # Comprehensive manuscript & supplementary data
│   ├── MANUSCRIPT_AND_SUPPLEMENTARY_RESULTS.md # Complete Markdown documentation
│   ├── dare_mul_complete_results.json          # Master results JSON database
│   └── tables/                    # 49 individual CSV tables (Tables 1-14, S1-S35)
│       ├── Table_1_DREU_Overhead.csv
│       ├── Table_6_Common_Condition_Baselines_Comparison.csv
│       ├── Table_7_Five_Seed_Repeatability.csv
│       ├── Table_10_ASIC_SKY130_PVT_Corners.csv
│       ├── Table_S3_Post_Implementation_Resource_Utilization.csv
│       └── ... (all 49 tables)
├── paper_results/                 # Verification graphs and aligned summaries
│   ├── graphs/                    # Publication-grade figures (PNG)
│   ├── paper_reference_metrics.json
│   └── paper_aligned_report.md
├── MNIST Dataset/                 # Benchmark dataset files (.idx-ubyte)
├── evaluate_manuscript_metrics.py # Python script for batch ablation & plotting
├── generate_all_results_artifacts.py # Generates all 49 CSVs and JSONs
├── generate_vectors.py            # Generates test vectors from dataset images
├── paper_results_console.tcl      # Vivado Tcl script for console metrics output
└── test_vectors.txt               # Default vector file
```

---

## 🚀 Getting Started

### Prerequisites
- **FPGA Synthesis & Simulation:** Xilinx Vivado 2023.1 or newer.
- **Python Environment:** Python 3.8+ with `matplotlib`, `numpy`, and `Pillow`.

```bash
pip install matplotlib numpy pillow
```

### 1. Opening the Project in Vivado
Open Vivado and load the project file:
```tcl
open_project dare_mul.xpr
```

### 2. Running Behavioral Simulation
You can run the testbench directly in Vivado GUI or from the Tcl console:
```tcl
launch_simulation
run all
```

To display the publication reference tables and metrics directly in the Vivado Tcl console:
```tcl
source paper_results_console.tcl
```

### 3. Running Automated Evaluation & Generating Graphs
Run the Python evaluation suite to regenerate publication-grade graphs and aligned reports:
```bash
python evaluate_manuscript_metrics.py --skip-sim
```
*Generated plots will be saved to `paper_results/graphs/`.*

### 4. Regenerating All CSV Tables & Database
To regenerate all 49 CSV files from the manuscript and supplementary material:
```bash
python generate_all_results_artifacts.py
```

---

## 📑 Complete Tables Reference

For full tabular data, numerical proofs, and supplementary analysis:
👉 **[Read the Full Results Documentation](results/MANUSCRIPT_AND_SUPPLEMENTARY_RESULTS.md)**

Every table is also individually exported to [`results/tables/`](results/tables/) in standard CSV format:
- **Table 1–14:** Main Manuscript tables (DREU overhead, sensitivity, baselines comparison, repeatability, ablations, ImageNet, ASIC corners, RL comparison, control properties).
- **Table S1–S35:** Supplementary Material tables (research gap analysis, full FPGA parameters, post-implementation resources, break-even analysis, workload drift stress tests, weight sweeps, bit-width scalability, NMED/RRMSE, edge-AI deployments, and DREU RTL constants).

---

## 📜 Citation & License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
