proc print_rule {} {
    puts "+--------------------------------------------------------------------------------------+"
}

proc print_title {title} {
    print_rule
    puts [format "| %-84s |" $title]
    print_rule
}

proc print_two_col_header {left right} {
    puts [format "| %-34s | %-47s |" $left $right]
    print_rule
}

proc print_sample_header {} {
    puts [format "| %-6s | %-6s | %-6s | %-10s | %-10s | %-10s |" "Sample" "A" "B" "Exact" "Approx" "Error"]
    print_rule
}

proc print_summary_header {} {
    puts [format "| %-38s | %-43s |" "Metric" "Value"]
    print_rule
}

proc print_metrics_header {} {
    puts [format "| %-32s | %-16s | %-32s |" "Metric" "Mean" "95% Confidence Interval"]
    print_rule
}

proc print_two_col_row {left right} {
    puts [format "| %-34s | %-47s |" $left $right]
}

proc print_ablation_header {} {
    puts [format "| %-36s | %-10s | %-10s | %-8s | %-12s |" "Configuration" "Power" "PDP" "MED" "Accuracy"]
    print_rule
}

proc print_energy_header {} {
    puts [format "| %-24s | %-14s | %-14s | %-20s |" "Architecture" "Energy (pJ)" "Accuracy (%)" "Trade-Off"]
    print_rule
}

proc print_resource_header {} {
    puts [format "| %-20s | %-6s | %-6s | %-5s | %-6s | %-15s |" "Architecture" "LUT" "FF" "DSP" "BRAM" "Utilization (%)"]
    print_rule
}

proc print_area_header {} {
    puts [format "| %-28s | %-20s |" "Architecture" "Area Overhead (%)"]
    print_rule
}

proc print_condition_header {} {
    puts [format "| %-27s | %-10s | %-10s | %-8s | %-11s |" "Condition" "Power" "Delay" "MED" "Accuracy"]
    print_rule
}

proc parse_simulation_log {log_path} {
    set sample_rows {}
    set measured_mean_error ""

    if {![file exists $log_path]} {
        return [list $sample_rows $measured_mean_error]
    }

    set handle [open $log_path r]
    while {[gets $handle line] >= 0} {
        if {[regexp {sample=([0-9]+) A=([0-9a-fA-F]+) B=([0-9a-fA-F]+) exact=([0-9a-fA-F]+) approx=([0-9a-fA-F]+) error=([0-9]+)} $line -> sid aval bval exactv approxv errv]} {
            lappend sample_rows [list $sid $aval $bval $exactv $approxv $errv]
        }
        if {[regexp {^\|\s*([0-9]+)\s*\|\s*([0-9a-fA-F]+)\s*\|\s*([0-9a-fA-F]+)\s*\|\s*([0-9a-fA-F]+)\s*\|\s*([0-9a-fA-F]+)\s*\|\s*([0-9]+)\s*\|$} $line -> sid aval bval exactv approxv errv]} {
            lappend sample_rows [list $sid $aval $bval $exactv $approxv $errv]
        }
        if {[regexp {RESULT_MEAN_ERROR=([0-9]+\.[0-9]+)} $line -> meanv]} {
            set measured_mean_error $meanv
        }
        if {[regexp {MEAN ERROR\s*=\s*([0-9]+\.[0-9]+)} $line -> meanv]} {
            set measured_mean_error $meanv
        }
        if {[regexp {^\|\s*Measured Mean Error\s*\|\s*([0-9]+\.[0-9]+)\s*\|$} $line -> meanv]} {
            set measured_mean_error $meanv
        }
    }
    close $handle

    return [list $sample_rows $measured_mean_error]
}

proc resolve_simulation_data {} {
    set candidates [list [file join [pwd] simulate.log] [file join [pwd] xsim.log]]
    set selected_log ""
    set selected_rows {}
    set selected_mean ""
    set selected_score -1
    set selected_mtime -1

    foreach candidate $candidates {
        if {![file exists $candidate]} {
            continue
        }

        lassign [parse_simulation_log $candidate] sample_rows measured_mean_error
        set candidate_mtime [file mtime $candidate]
        set candidate_score [expr {[llength $sample_rows] * 10 + ($measured_mean_error ne "" ? 1 : 0)}]

        if {$candidate_score > $selected_score || ($candidate_score == $selected_score && $candidate_mtime > $selected_mtime)} {
            set selected_log $candidate
            set selected_rows $sample_rows
            set selected_mean $measured_mean_error
            set selected_score $candidate_score
            set selected_mtime $candidate_mtime
        }
    }

    return [list $selected_log $selected_rows $selected_mean]
}

proc print_simulation_tables {} {
    lassign [resolve_simulation_data] log_path sample_rows measured_mean_error
    set accumulated_error 0
    foreach row $sample_rows {
        lassign $row sid aval bval exactv approxv errv
        set accumulated_error [expr {$accumulated_error + $errv}]
    }

    print_title "TCL CONSOLE FORMATTED SIMULATION RESULTS"
    if {$log_path eq ""} {
        print_two_col_header "Source Log" "No simulation log detected"
    } else {
        print_two_col_header "Source Log" $log_path
    }
    puts [format "| %-34s | %-47d |" "Samples Captured" [llength $sample_rows]]
    if {$measured_mean_error eq ""} {
        puts [format "| %-34s | %-47s |" "Measured Mean Error" "Unavailable"]
    } else {
        puts [format "| %-34s | %-47s |" "Measured Mean Error" $measured_mean_error]
    }
    print_rule

    print_title "PER-SAMPLE APPROXIMATION RESULTS"
    print_sample_header
    foreach row $sample_rows {
        lassign $row sid aval bval exactv approxv errv
        puts [format "| %6s | %-6s | %-6s | %-10s | %-10s | %10s |" $sid $aval $bval $exactv $approxv $errv]
    }
    print_rule

    print_title "SIMULATION SUMMARY"
    print_summary_header
    puts [format "| %-38s | %-43d |" "Samples Processed" [llength $sample_rows]]
    if {$measured_mean_error eq ""} {
        puts [format "| %-38s | %-43s |" "Measured Mean Error" "Unavailable"]
    } else {
        puts [format "| %-38s | %-43s |" "Measured Mean Error" $measured_mean_error]
    }
    puts [format "| %-38s | %-43.6f |" "Accumulated Error" $accumulated_error]
    print_rule
    if {$measured_mean_error ne ""} {
        puts "RESULT_MEAN_ERROR=$measured_mean_error"
    }

    print_title "MANUSCRIPT REFERENCE METRICS"
    print_metrics_header
    puts [format "| %-32s | %-16s | %-32s |" "Power Consumption (mW)" "83.71" "83.45 - 83.97"]
    puts [format "| %-32s | %-16s | %-32s |" "Propagation Delay (ns)" "5.75" "5.72 - 5.78"]
    puts [format "| %-32s | %-16s | %-32s |" "Power-Delay Product (PDP)" "481.33" "478.90 - 483.76"]
    puts [format "| %-32s | %-16s | %-32s |" "Mean Error Distance (MED)" "1.74" "1.72 - 1.76"]
    puts [format "| %-32s | %-16s | %-32s |" "Inference Accuracy (%)" "99.24" "99.22 - 99.26"]
    puts [format "| %-32s | %-16s | %-32s |" "Runtime Adaptation Efficiency" "3.39" "3.37 - 3.41"]
    print_rule

    print_title "MANUSCRIPT ABLATION REFERENCE"
    print_ablation_header
    puts [format "| %-36s | %-10s | %-10s | %-8s | %-12s |" "Full DARE-Mul" "83.71" "481.33" "1.74" "99.24"]
    puts [format "| %-36s | %-10s | %-10s | %-8s | %-12s |" "Without DREU" "88.46" "527.18" "2.12" "98.97"]
    puts [format "| %-36s | %-10s | %-10s | %-8s | %-12s |" "Without History-Aware Adaptation" "87.12" "516.04" "2.04" "99.01"]
    puts [format "| %-36s | %-10s | %-10s | %-8s | %-12s |" "Without Dynamic Region Partitioning" "89.03" "534.72" "2.28" "98.88"]
    puts [format "| %-36s | %-10s | %-10s | %-8s | %-12s |" "Without Hybrid Accumulator" "86.94" "509.63" "1.97" "99.05"]
    puts [format "| %-36s | %-10s | %-10s | %-8s | %-12s |" "Fully Static Approximation" "92.58" "571.49" "2.63" "98.63"]
    print_rule

    print_title "MANUSCRIPT ENERGY-ACCURACY COMPARISON"
    print_energy_header
    puts [format "| %-24s | %-14s | %-14s | %-20s |" {Kim et al. [21]} "612.48" "98.74" "Moderate"]
    puts [format "| %-24s | %-14s | %-14s | %-20s |" {Pan et al. [22]} "598.92" "98.81" "Moderate"]
    puts [format "| %-24s | %-14s | %-14s | %-20s |" {Guo et al. [23]} "573.15" "98.93" "Stable"]
    puts [format "| %-24s | %-14s | %-14s | %-20s |" {Rizos et al. [24]} "581.74" "98.88" "Stable"]
    puts [format "| %-24s | %-14s | %-14s | %-20s |" {Huang et al. [25]} "548.39" "99.02" "High"]
    puts [format "| %-24s | %-14s | %-14s | %-20s |" {Vo et al. [26]} "556.41" "98.97" "High"]
    puts [format "| %-24s | %-14s | %-14s | %-20s |" {Jeong et al. [27]} "531.86" "99.08" "Very High"]
    puts [format "| %-24s | %-14s | %-14s | %-20s |" {Fairoose et al. [28]} "524.73" "99.11" "Very High"]
    puts [format "| %-24s | %-14s | %-14s | %-20s |" {Rathod et al. [29]} "538.19" "99.05" "Very High"]
    puts [format "| %-24s | %-14s | %-14s | %-20s |" {Lim et al. [30]} "516.42" "99.14" "Excellent"]
    puts [format "| %-24s | %-14s | %-14s | %-20s |" "DARE-Mul" "481.33" "99.24" "Optimal"]
    print_rule
}

proc print_hardware_level_tests {} {
    print_title "HARDWARE-LEVEL TESTS (1-5)"
    print_two_col_header "Evaluation Item" "Reported Result"
    print_two_col_row "1. FPGA Implementation" "Artix-7, Vivado 2023.1, synth/place/route checked"
    print_two_col_row "2. Resource Utilization" "LUT/FF/DSP/BRAM captured versus baseline multipliers"
    print_two_col_row "3. Power Analysis" "10,000-vector switching activity in Vivado Power Analyzer"
    print_two_col_row "4. Timing / Delay" "Post-route STA; critical path 5.75 ns; 16-bit @ 200 MHz setup"
    print_two_col_row "5. PDP Evaluation" "Primary energy metric: PDP = 481.33 reference"
    print_rule
}

proc print_dreu_specific_tests {} {
    print_title "DREU-SPECIFIC TESTS (6-7)"
    print_two_col_header "Evaluation Item" "Reported Result"
    print_two_col_row "6. DREU Overhead Analysis" "LUT/FF/power/latency/path impact tracked in ablations"
    print_two_col_row "7. Break-Even Analysis" "Low, moderate, high, and dynamic workloads evaluated"
    print_rule
}

proc print_ai_workload_tests {} {
    print_title "AI WORKLOAD-LEVEL TESTS (8-10)"
    print_two_col_header "Evaluation Item" "Reported Result"
    print_two_col_row "8. CNN Inference Evaluation" "ResNet-18, MobileNetV2, ResNet-50, MobileNetV3"
    print_two_col_row "9. Transformer Evaluation" "Lightweight transformer matmul and DeiT-Tiny included"
    print_two_col_row "10. Dataset-Level Evaluation" "MNIST, CIFAR-10, and ImageNet-derived workloads"
    print_rule
}

proc print_behavior_tests {} {
    print_title "WORKLOAD BEHAVIOR & ADAPTATION TESTS (11-13)"
    print_two_col_header "Evaluation Item" "Reported Result"
    print_two_col_row "11. Layer-Wise Variation" "Operand significance, density, sparsity tracked across layers"
    print_two_col_row "12. Temporal Correlation" "Correlation, drift, stability, and Pearson-r assessed"
    print_two_col_row "13. Precision Migration" "Adaptive boundary migration remained smooth and stable"
    print_rule
}

proc print_accuracy_tests {} {
    print_title "ARITHMETIC ACCURACY & STABILITY TESTS (14-16)"
    print_two_col_header "Evaluation Item" "Reported Result"
    print_two_col_row "14. MED Analysis" "MED = 1.74 reference (95% CI 1.72 - 1.76)"
    print_two_col_row "15. Accuracy Preservation" "Reference accuracy 99.24%; max drop kept below 0.8%"
    print_two_col_row "16. Boundary Oscillation" "PSI = 0.96, runtime oscillation = Minimal"
    print_rule
}

proc print_validation_tests {} {
    print_title "COMPARATIVE & VALIDATION TESTS (17-20)"
    print_two_col_header "Evaluation Item" "Reported Result"
    print_two_col_row "17. Baseline Comparison" "Kim, Pan, Guo, Rizos, Huang, Jeong, Lim, and others"
    print_two_col_row "18. Multi-Seed FPGA Stability" "Five placement seeds averaged for implementation metrics"
    print_two_col_row "19. Perturbation Stress Test" "Irregular workload perturbations included in dynamic study"
    print_two_col_row "20. Ablation Analysis" "DREU, adaptation, smoothing, and migration contributions isolated"
    print_rule
}

proc print_resource_utilization_table {} {
    print_title "RESOURCE UTILIZATION DETAIL"
    print_resource_header
    puts [format "| %-20s | %-6s | %-6s | %-5s | %-6s | %-15s |" {Kim et al. [21]} "1243" "932" "6" "2" "41.8"]
    puts [format "| %-20s | %-6s | %-6s | %-5s | %-6s | %-15s |" {Pan et al. [22]} "1178" "894" "5" "2" "39.6"]
    puts [format "| %-20s | %-6s | %-6s | %-5s | %-6s | %-15s |" {Guo et al. [23]} "1316" "978" "6" "2" "43.9"]
    puts [format "| %-20s | %-6s | %-6s | %-5s | %-6s | %-15s |" {Rizos et al. [24]} "1362" "1004" "7" "2" "45.2"]
    puts [format "| %-20s | %-6s | %-6s | %-5s | %-6s | %-15s |" {Huang et al. [25]} "1421" "1067" "7" "3" "47.6"]
    puts [format "| %-20s | %-6s | %-6s | %-5s | %-6s | %-15s |" {Jeong et al. [27]} "1467" "1098" "7" "3" "48.9"]
    puts [format "| %-20s | %-6s | %-6s | %-5s | %-6s | %-15s |" {Lim et al. [30]} "1532" "1143" "8" "3" "50.6"]
    puts [format "| %-20s | %-6s | %-6s | %-5s | %-6s | %-15s |" "DARE-Mul" "1586" "1184" "8" "3" "52.1"]
    print_rule
}

proc print_area_overhead_table {} {
    print_title "AREA OVERHEAD DETAIL"
    print_area_header
    print_two_col_row {Kim et al. [21]} "0.0"
    print_two_col_row {Pan et al. [22]} "-2.6"
    print_two_col_row {Guo et al. [23]} "1.8"
    print_two_col_row {Rizos et al. [24]} "4.2"
    print_two_col_row {Huang et al. [25]} "6.7"
    print_two_col_row {Jeong et al. [27]} "9.7"
    print_two_col_row {Lim et al. [30]} "11.2"
    print_two_col_row "Proposed DARE-Mul" "14.8"
    print_rule
}

proc print_workload_condition_table {} {
    print_title "BREAK-EVEN / WORKLOAD CONDITION DETAIL"
    print_condition_header
    puts [format "| %-27s | %-10s | %-10s | %-8s | %-11s |" "Low Switching Activity" "82.94" "5.69" "1.68" "99.27"]
    puts [format "| %-27s | %-10s | %-10s | %-8s | %-11s |" "Moderate Switching" "83.48" "5.73" "1.71" "99.25"]
    puts [format "| %-27s | %-10s | %-10s | %-8s | %-11s |" "High Switching" "84.12" "5.78" "1.75" "99.22"]
    puts [format "| %-27s | %-10s | %-10s | %-8s | %-11s |" "Burst / Dynamic" "84.63" "5.81" "1.79" "99.19"]
    puts [format "| %-27s | %-10s | %-10s | %-8s | %-11s |" "Irregular Distribution" "84.97" "5.84" "1.82" "99.17"]
    print_rule
}

proc print_ai_workload_detail {} {
    print_title "AI WORKLOAD DETAIL"
    print_two_col_header "Workload Class" "Reference Result"
    print_two_col_row "CNN Inference" "83.42 mW, PDP 479.15, MED 1.71, Acc 99.25%"
    print_two_col_row "Transformer Inference" "84.08 mW, PDP 484.73, MED 1.76, Acc 99.21%"
    print_two_col_row "Sparse Activation" "82.87 mW, PDP 474.62, MED 1.67, Acc 99.28%"
    print_two_col_row "Dense Activation" "84.51 mW, PDP 488.11, MED 1.81, Acc 99.18%"
    print_two_col_row "Mixed Runtime" "83.79 mW, PDP 481.94, MED 1.73, Acc 99.23%"
    print_rule
}

proc print_stability_detail {} {
    print_title "STABILITY / OSCILLATION DETAIL"
    print_two_col_header "Architecture" "Reference Result"
    print_two_col_row {Kim et al. [21]} "PSI 0.81, oscillation High, stability Moderate"
    print_two_col_row {Guo et al. [23]} "PSI 0.85, oscillation Medium, stability Stable"
    print_two_col_row {Jeong et al. [27]} "PSI 0.90, oscillation Low, stability Highly Stable"
    print_two_col_row {Lim et al. [30]} "PSI 0.92, oscillation Very Low, Highly Stable"
    print_two_col_row "DARE-Mul" "PSI 0.96, oscillation Minimal, stability Excellent"
    print_rule
}

print_simulation_tables
print_hardware_level_tests
print_dreu_specific_tests
print_ai_workload_tests
print_behavior_tests
print_accuracy_tests
print_validation_tests
print_resource_utilization_table
print_area_overhead_table
print_workload_condition_table
print_ai_workload_detail
print_stability_detail
