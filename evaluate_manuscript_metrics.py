from __future__ import annotations

import argparse
import csv
import json
import math
import re
import subprocess
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


PROJECT_ROOT = Path(__file__).resolve().parent
DATA_PATH = PROJECT_ROOT / "paper_reference_metrics.json"
OUTPUT_DIR = PROJECT_ROOT / "paper_results"
GRAPH_DIR = OUTPUT_DIR / "graphs"

XVLOG = Path(r"C:\Xilinx\Vivado\2023.1\bin\xvlog.bat")
XELAB = Path(r"C:\Xilinx\Vivado\2023.1\bin\xelab.bat")

RTL_FILES = [
    PROJECT_ROOT / "dare_mul.srcs" / "sources_1" / "new" / "operand_analysis.v",
    PROJECT_ROOT / "dare_mul.srcs" / "sources_1" / "new" / "dreu.v",
    PROJECT_ROOT / "dare_mul.srcs" / "sources_1" / "new" / "partial_product_generator.v",
    PROJECT_ROOT / "dare_mul.srcs" / "sources_1" / "new" / "adaptive_reduction_tree.v",
    PROJECT_ROOT / "dare_mul.srcs" / "sources_1" / "new" / "hybrid_accumulator.v",
    PROJECT_ROOT / "dare_mul.srcs" / "sources_1" / "new" / "runtime_feedback.v",
    PROJECT_ROOT / "dare_mul.srcs" / "sources_1" / "new" / "dare_mul_top.v",
    PROJECT_ROOT / "dare_mul.srcs" / "sim_1" / "new" / "dare_mul_tb.v",
]

MEAN_ERROR_PATTERN = re.compile(r"(?:RESULT_MEAN_ERROR|MEAN ERROR)\s*=?\s*([0-9]+\.[0-9]+)")


def load_reference_data() -> dict:
    return json.loads(DATA_PATH.read_text(encoding="utf-8"))


def ensure_output_dirs() -> None:
    OUTPUT_DIR.mkdir(exist_ok=True)
    GRAPH_DIR.mkdir(parents=True, exist_ok=True)


def run_command(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=PROJECT_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def parse_mean_error(output: str) -> float | None:
    match = None
    for match in MEAN_ERROR_PATTERN.finditer(output):
        pass
    if match is None:
        return None
    return float(match.group(1))


def slugify(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def run_ablation_variant(name: str, defines: list[str]) -> dict:
    slug = slugify(name)
    xvlog_cmd = [str(XVLOG)]
    for define in defines:
        xvlog_cmd.extend(["-d", define])
    xvlog_cmd.extend(str(path) for path in RTL_FILES)

    xvlog_result = run_command(xvlog_cmd)
    if xvlog_result.returncode != 0:
        raise RuntimeError(f"xvlog failed for {name}:\n{xvlog_result.stdout}\n{xvlog_result.stderr}")

    snapshot_name = f"dare_mul_tb_{slug}"
    xelab_cmd = [
        str(XELAB),
        "--debug",
        "typical",
        "--relax",
        "--mt",
        "2",
        "-R",
        "--snapshot",
        snapshot_name,
        "work.dare_mul_tb",
    ]
    xelab_result = run_command(xelab_cmd)
    if xelab_result.returncode != 0:
        raise RuntimeError(f"xelab failed for {name}:\n{xelab_result.stdout}\n{xelab_result.stderr}")

    mean_error = parse_mean_error(xelab_result.stdout)
    return {
        "configuration": name,
        "defines": defines,
        "measured_mean_error": mean_error,
        "xvlog_stdout": xvlog_result.stdout,
        "xelab_stdout": xelab_result.stdout,
    }


def run_module_ablations(reference_data: dict) -> list[dict]:
    if not XVLOG.exists() or not XELAB.exists():
        return []

    results = []
    for variant in reference_data["module_ablation_variants"]:
        results.append(run_ablation_variant(variant["name"], variant["defines"]))
    return results


def write_json(path: Path, payload: object) -> None:
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def write_csv(path: Path, rows: list[dict], fieldnames: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def markdown_table(rows: list[dict], columns: list[tuple[str, str]]) -> str:
    headers = [label for _, label in columns]
    keys = [key for key, _ in columns]
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---"] * len(headers)) + " |",
    ]
    for row in rows:
        values = [str(row.get(key, "")) for key in keys]
        lines.append("| " + " | ".join(values) + " |")
    return "\n".join(lines)


def plot_energy_accuracy(reference_data: dict) -> Path:
    data = reference_data["energy_accuracy_tradeoff"]
    fig, ax = plt.subplots(figsize=(10, 6))
    for row in data:
        color = "#b5483a" if row["architecture"] == "DARE-Mul" else "#4f6d7a"
        size = 120 if row["architecture"] == "DARE-Mul" else 70
        ax.scatter(row["energy_pj"], row["inference_accuracy_pct"], s=size, color=color)
        ax.annotate(row["architecture"], (row["energy_pj"], row["inference_accuracy_pct"]), fontsize=8, xytext=(5, 5), textcoords="offset points")
    ax.set_title("Manuscript Energy-Accuracy Trade-Off")
    ax.set_xlabel("Energy Consumption (pJ)")
    ax.set_ylabel("Inference Accuracy (%)")
    ax.grid(alpha=0.3)
    path = GRAPH_DIR / "energy_accuracy_tradeoff.png"
    fig.tight_layout()
    fig.savefig(path, dpi=200)
    plt.close(fig)
    return path


def plot_architecture_utilization(reference_data: dict) -> Path:
    data = reference_data["architecture_utilization"]
    names = [row["architecture"] for row in data]
    values = [row["overall_utilization_pct"] for row in data]
    fig, ax = plt.subplots(figsize=(12, 6))
    colors = ["#b5483a" if name == "DARE-Mul" else "#708d81" for name in names]
    ax.bar(names, values, color=colors)
    ax.set_title("Overall FPGA Utilization Across Architectures")
    ax.set_ylabel("Overall Utilization (%)")
    ax.tick_params(axis="x", rotation=45, labelsize=8)
    ax.grid(axis="y", alpha=0.3)
    path = GRAPH_DIR / "architecture_utilization.png"
    fig.tight_layout()
    fig.savefig(path, dpi=200)
    plt.close(fig)
    return path


def plot_stability(reference_data: dict) -> Path:
    data = reference_data["stability"]
    names = [row["architecture"] for row in data]
    values = [row["psi"] for row in data]
    fig, ax = plt.subplots(figsize=(12, 6))
    colors = ["#b5483a" if name == "DARE-Mul" else "#2f6690" for name in names]
    ax.bar(names, values, color=colors)
    ax.set_title("Precision Stability Index")
    ax.set_ylabel("PSI")
    ax.set_ylim(0.75, 1.0)
    ax.tick_params(axis="x", rotation=45, labelsize=8)
    ax.grid(axis="y", alpha=0.3)
    path = GRAPH_DIR / "precision_stability_index.png"
    fig.tight_layout()
    fig.savefig(path, dpi=200)
    plt.close(fig)
    return path


def plot_workload_conditions(reference_data: dict) -> Path:
    data = reference_data["workload_conditions"]
    labels = [row["condition"] for row in data]
    power = [row["power_mw"] for row in data]
    delay = [row["delay_ns"] for row in data]
    med = [row["med"] for row in data]
    accuracy = [row["inference_accuracy_pct"] for row in data]

    fig, axes = plt.subplots(2, 2, figsize=(12, 8))
    metric_map = [
        (axes[0, 0], power, "Power (mW)", "#7f5539"),
        (axes[0, 1], delay, "Delay (ns)", "#386641"),
        (axes[1, 0], med, "MED", "#6a4c93"),
        (axes[1, 1], accuracy, "Inference Accuracy (%)", "#0f4c5c"),
    ]
    for axis, values, title, color in metric_map:
        axis.plot(labels, values, marker="o", color=color)
        axis.set_title(title)
        axis.tick_params(axis="x", rotation=25)
        axis.grid(alpha=0.3)
    fig.suptitle("Runtime Workload Condition Sensitivity")
    path = GRAPH_DIR / "workload_conditions.png"
    fig.tight_layout()
    fig.savefig(path, dpi=200)
    plt.close(fig)
    return path


def plot_workload_types(reference_data: dict) -> Path:
    data = reference_data["workload_types"]
    labels = [row["workload"] for row in data]
    fig, axes = plt.subplots(2, 2, figsize=(12, 8))
    metric_map = [
        (axes[0, 0], [row["power_mw"] for row in data], "Power (mW)", "#7b2cbf"),
        (axes[0, 1], [row["pdp"] for row in data], "PDP", "#4361ee"),
        (axes[1, 0], [row["med"] for row in data], "MED", "#2d6a4f"),
        (axes[1, 1], [row["inference_accuracy_pct"] for row in data], "Inference Accuracy (%)", "#bc4749"),
    ]
    for axis, values, title, color in metric_map:
        axis.bar(labels, values, color=color)
        axis.set_title(title)
        axis.tick_params(axis="x", rotation=25, labelsize=8)
        axis.grid(axis="y", alpha=0.3)
    fig.suptitle("Workload-Type Evaluation")
    path = GRAPH_DIR / "workload_types.png"
    fig.tight_layout()
    fig.savefig(path, dpi=200)
    plt.close(fig)
    return path


def plot_area_overhead(reference_data: dict) -> Path:
    data = reference_data["architecture_area_overhead"]
    labels = [row["architecture"] for row in data]
    values = [row["area_overhead_pct"] for row in data]
    fig, ax = plt.subplots(figsize=(12, 6))
    colors = ["#b5483a" if label == "Proposed DARE-Mul" else "#588157" for label in labels]
    ax.bar(labels, values, color=colors)
    ax.set_title("Area Overhead Across Architectures")
    ax.set_ylabel("Area Overhead (%)")
    ax.tick_params(axis="x", rotation=45, labelsize=8)
    ax.grid(axis="y", alpha=0.3)
    path = GRAPH_DIR / "architecture_area_overhead.png"
    fig.tight_layout()
    fig.savefig(path, dpi=200)
    plt.close(fig)
    return path


def plot_scalability(reference_data: dict) -> Path:
    data = reference_data["scalability"]
    widths = [row["bit_width"] for row in data]
    fig, axes = plt.subplots(2, 2, figsize=(12, 8))
    metric_map = [
        (axes[0, 0], [row["power_mw"] for row in data], "Power (mW)", "#bc4749"),
        (axes[0, 1], [row["delay_ns"] for row in data], "Delay (ns)", "#386641"),
        (axes[1, 0], [row["pdp"] for row in data], "PDP", "#3a86ff"),
        (axes[1, 1], [row["med"] for row in data], "MED", "#8338ec"),
    ]
    for axis, values, title, color in metric_map:
        axis.plot(widths, values, marker="o", color=color)
        axis.set_title(title)
        axis.set_xlabel("Bit Width")
        axis.grid(alpha=0.3)
    fig.suptitle("Scalability Across Multiplier Bit Widths")
    path = GRAPH_DIR / "scalability.png"
    fig.tight_layout()
    fig.savefig(path, dpi=200)
    plt.close(fig)
    return path


def plot_manuscript_ablations(reference_data: dict) -> Path:
    data = reference_data["manuscript_ablations"]
    labels = [row["configuration"] for row in data]
    power = [row["power_mw"] for row in data]
    pdp = [row["pdp"] for row in data]
    med = [row["med"] for row in data]
    accuracy = [row["inference_accuracy_pct"] for row in data]

    fig, axes = plt.subplots(2, 2, figsize=(13, 8))
    metric_map = [
        (axes[0, 0], power, "Power (mW)", "#9c6644"),
        (axes[0, 1], pdp, "PDP", "#5f0f40"),
        (axes[1, 0], med, "MED", "#3a5a40"),
        (axes[1, 1], accuracy, "Inference Accuracy (%)", "#277da1"),
    ]
    for axis, values, title, color in metric_map:
        axis.bar(labels, values, color=color)
        axis.set_title(title)
        axis.tick_params(axis="x", rotation=25, labelsize=8)
        axis.grid(axis="y", alpha=0.3)
    fig.suptitle("Manuscript Ablation Study")
    path = GRAPH_DIR / "manuscript_ablation_study.png"
    fig.tight_layout()
    fig.savefig(path, dpi=200)
    plt.close(fig)
    return path


def plot_measured_ablation_med(measured_results: list[dict]) -> Path | None:
    valid_rows = [row for row in measured_results if row["measured_mean_error"] is not None]
    if not valid_rows:
        return None

    labels = [row["configuration"] for row in valid_rows]
    values = [row["measured_mean_error"] for row in valid_rows]
    fig, ax = plt.subplots(figsize=(12, 6))
    colors = ["#b5483a" if row["configuration"] == "Full DARE-Mul" else "#4d908e" for row in valid_rows]
    ax.bar(labels, values, color=colors)
    ax.set_title("Measured RTL Mean Error by Ablation Variant")
    ax.set_ylabel("Measured Mean Error")
    ax.tick_params(axis="x", rotation=30, labelsize=8)
    ax.grid(axis="y", alpha=0.3)
    path = GRAPH_DIR / "measured_ablation_mean_error.png"
    fig.tight_layout()
    fig.savefig(path, dpi=200)
    plt.close(fig)
    return path


def build_report(reference_data: dict, measured_results: list[dict], graph_paths: list[Path]) -> str:
    claims = reference_data["paper_claims"]
    measured_rows = []
    for row in measured_results:
        measured_rows.append(
            {
                "configuration": row["configuration"],
                "defines": ", ".join(row["defines"]) if row["defines"] else "default",
                "measured_mean_error": "" if row["measured_mean_error"] is None else f"{row['measured_mean_error']:.4f}",
            }
        )

    sections = [
        "# DARE-Mul Manuscript-Aligned Results",
        "",
        "## Paper Claims",
        f"- Power reduction: {claims.get('power_reduction_pct', '22.0')}%",
        f"- Delay reduction: {claims.get('delay_reduction_pct', '1.9')}%",
        f"- PDP improvement: {claims.get('pdp_improvement_pct', '21.8')}%",
        f"- MED reduction: {claims.get('med_reduction_pct', '29.4')}%",
        f"- Maximum inference-accuracy drop: {claims.get('max_inference_accuracy_drop_pct', '0.585')}%",
        "",
        "## Summary Metrics",
        markdown_table(
            reference_data["summary_metrics"],
            [
                ("metric", "Metric"),
                ("mean", "Mean"),
                ("std_dev", "Std Dev"),
                ("confidence_interval", "95% CI"),
            ],
        ),
        "",
        "## Manuscript Ablation Table",
        markdown_table(
            reference_data["manuscript_ablations"],
            [
                ("configuration", "Configuration"),
                ("power_mw", "Power (mW)"),
                ("pdp", "PDP"),
                ("med", "MED"),
                ("inference_accuracy_pct", "Inference Accuracy (%)"),
                ("runtime_adaptation_efficiency", "Runtime Adaptation Efficiency"),
            ],
        ),
        "",
        "## Energy-Accuracy Comparison",
        markdown_table(
            reference_data["energy_accuracy_tradeoff"],
            [
                ("architecture", "Architecture"),
                ("energy_pj", "Energy (pJ)"),
                ("inference_accuracy_pct", "Inference Accuracy (%)"),
                ("tradeoff_efficiency", "Trade-Off Efficiency"),
            ],
        ),
        "",
        "## RTL Module Ablations",
        markdown_table(
            measured_rows,
            [
                ("configuration", "Configuration"),
                ("defines", "Defines"),
                ("measured_mean_error", "Measured Mean Error"),
            ],
        ),
        "",
        "## Generated Graphs",
    ]

    for graph_path in graph_paths:
        sections.append(f"- [{graph_path.name}]({graph_path.relative_to(PROJECT_ROOT).as_posix()})")

    sections.append("")
    sections.append("## Notes")
    sections.append("- The manuscript tables above are reproduced exactly from the paper data so the reported values match the manuscript.")
    sections.append("- The RTL ablation section is a local simulation sanity check based on the current Verilog and should be treated as implementation feedback, not as a replacement for the paper’s hardware and inference measurements.")
    sections.append("")

    return "\n".join(sections)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate manuscript-aligned DARE-Mul metrics, ablations, and graphs.")
    parser.add_argument("--skip-sim", action="store_true", help="Skip Vivado ablation simulations and only emit manuscript-aligned reports.")
    args = parser.parse_args()

    ensure_output_dirs()
    reference_data = load_reference_data()

    measured_results = []
    if not args.skip_sim:
        measured_results = run_module_ablations(reference_data)

    write_json(OUTPUT_DIR / "paper_reference_metrics.json", reference_data)
    if measured_results:
        write_json(OUTPUT_DIR / "module_ablation_measurements.json", measured_results)
        write_csv(
            OUTPUT_DIR / "module_ablation_measurements.csv",
            [
                {
                    "configuration": row["configuration"],
                    "defines": ",".join(row["defines"]),
                    "measured_mean_error": row["measured_mean_error"],
                }
                for row in measured_results
            ],
            ["configuration", "defines", "measured_mean_error"],
        )

    graph_paths = [
        plot_energy_accuracy(reference_data),
        plot_area_overhead(reference_data),
        plot_architecture_utilization(reference_data),
        plot_stability(reference_data),
        plot_workload_conditions(reference_data),
        plot_workload_types(reference_data),
        plot_scalability(reference_data),
        plot_manuscript_ablations(reference_data),
    ]

    measured_graph = plot_measured_ablation_med(measured_results)
    if measured_graph is not None:
        graph_paths.append(measured_graph)

    report_text = build_report(reference_data, measured_results, graph_paths)
    report_path = OUTPUT_DIR / "paper_aligned_report.md"
    report_path.write_text(report_text, encoding="utf-8")

    print(f"Report written to: {report_path}")
    print(f"Graphs written to: {GRAPH_DIR}")
    if measured_results:
        print(f"Measured ablation results captured for {len(measured_results)} variants.")
    else:
        print("No measured ablation results were collected.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
