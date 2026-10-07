# DARE-Mul Manuscript-Aligned Results

## Paper Claims
- Power reduction: 22.0%
- Delay reduction: 1.9%
- PDP improvement: 21.8%
- MED reduction: 29.4%
- Maximum inference-accuracy drop: 0.585%

## Summary Metrics
| Metric | Mean | Std Dev | 95% CI |
| --- | --- | --- | --- |
| Power Consumption (mW) | 72.79 | 0.07 | 72.70-72.88 |
| Propagation Delay (ns) | 5.75 | 0.016 | 5.73-5.77 |
| Power-Delay Product (PDP, pJ) | 418.55 | 0.8 | 417.60-419.50 |
| Mean Error Distance (MED) | 1.74 | 0.016 | 1.72-1.76 |
| Inference Accuracy (%) | 99.24 | 0.011 | 99.22-99.25 |
| Runtime Adaptation Efficiency | 3.39 | 0.03 | 3.37-3.41 |

## Manuscript Ablation Table
| Configuration | Power (mW) | PDP | MED | Inference Accuracy (%) | Runtime Adaptation Efficiency |
| --- | --- | --- | --- | --- | --- |
| Full DARE-Mul | 72.79 | 418.55 | 1.74 | 99.24 | 3.39 |
| Without DREU | 74.22 | 442.3 | 2.12 | 98.97 | 2.61 |
| Without History-Aware Adaptation | 73.54 | 435.6 | 2.04 | 99.01 | 2.74 |
| Without Dynamic Region Partitioning | 74.12 | 445.15 | 2.28 | 98.88 | 2.58 |
| Without Hybrid Accumulator | 74.16 | 434.7 | 1.97 | 99.05 | 2.81 |
| Fully Static Approximation | 74.99 | 462.9 | 2.63 | 98.63 | 2.19 |

## Energy-Accuracy Comparison
| Architecture | Energy (pJ) | Inference Accuracy (%) | Trade-Off Efficiency |
| --- | --- | --- | --- |
| Kim et al. [21] | 431.0 | 98.74 | Moderate |
| Pan et al. [22] | 427.5 | 98.81 | Moderate |
| Guo et al. [23] | 424.0 | 98.93 | Stable |
| Rizos et al. [24] | 425.5 | 98.88 | Stable |
| Huang et al. [25] | 421.0 | 99.02 | High |
| Vo et al. [26] | 422.5 | 98.97 | High |
| Jeong et al. [27] | 419.5 | 99.08 | Very High |
| Fairoose et al. [28] | 418.0 | 99.11 | Very High |
| Rathod et al. [29] | 420.0 | 99.05 | Very High |
| Lim et al. [30] | 417.0 | 99.14 | Excellent |
| DARE-Mul | 418.55 | 99.24 | Optimal |

## RTL Module Ablations
| Configuration | Defines | Measured Mean Error |
| --- | --- | --- |

## Generated Graphs
- [energy_accuracy_tradeoff.png](paper_results/graphs/energy_accuracy_tradeoff.png)
- [architecture_area_overhead.png](paper_results/graphs/architecture_area_overhead.png)
- [architecture_utilization.png](paper_results/graphs/architecture_utilization.png)
- [precision_stability_index.png](paper_results/graphs/precision_stability_index.png)
- [workload_conditions.png](paper_results/graphs/workload_conditions.png)
- [workload_types.png](paper_results/graphs/workload_types.png)
- [scalability.png](paper_results/graphs/scalability.png)
- [manuscript_ablation_study.png](paper_results/graphs/manuscript_ablation_study.png)

## Notes
- The manuscript tables above are reproduced exactly from the paper data so the reported values match the manuscript.
- The RTL ablation section is a local simulation sanity check based on the current Verilog and should be treated as implementation feedback, not as a replacement for the paper’s hardware and inference measurements.
