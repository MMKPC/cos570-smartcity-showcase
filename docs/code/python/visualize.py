"""Visualization outputs. Task 5. matplotlib charts and a traffic-density
vs energy-use heatmap, the example the assignment names directly."""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


def wait_time_comparison_chart(default_score, optimized_score, out_path):
    labels = ["Default timing", "Optimized timing"]
    waits = [default_score["avg_wait_s"], optimized_score["avg_wait_s"]]

    fig, ax = plt.subplots(figsize=(5, 4))
    bars = ax.bar(labels, waits, color=["#8891a0", "#2e7d53"])
    ax.set_ylabel("Average wait time (s)")
    ax.set_title("Traffic light timing: default vs optimized")
    ax.set_ylim(0, max(waits) * 1.35)  # headroom so value labels never crowd the title
    for bar, val in zip(bars, waits):
        ax.text(bar.get_x() + bar.get_width() / 2, val + max(waits) * 0.04, f"{val:.1f}s", ha="center")
    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)


def traffic_vs_energy_heatmap(per_intersection_wait, per_zone_hour, out_path):
    fig, axes = plt.subplots(1, 2, figsize=(10, 4))

    axes[0].bar(per_intersection_wait["intersection"], per_intersection_wait["mean"], color="#3a6ea5")
    axes[0].set_title("Traffic density (avg wait) by intersection")
    axes[0].set_ylabel("Average wait (s)")
    axes[0].tick_params(axis="x", rotation=30)

    data = per_zone_hour.values
    im = axes[1].imshow(data, aspect="auto", cmap="inferno")
    axes[1].set_yticks(range(len(per_zone_hour.index)))
    axes[1].set_yticklabels(per_zone_hour.index)
    axes[1].set_xlabel("Hour of day")
    axes[1].set_title("Energy use by zone (kW)")
    fig.colorbar(im, ax=axes[1], label="kW")

    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)


def optimization_landscape_chart(sweep_df, best_row, out_path):
    """The actual surface the decision tree was trained on: average wait
    time across every (min_green, max_green) combination that was swept,
    with the chosen optimum marked. This is what "trained a model to
    optimize" actually looks like, not just a before/after bar."""
    pivot = sweep_df.pivot(index="min_green", columns="max_green", values="avg_wait_s")

    fig, ax = plt.subplots(figsize=(6, 4.5))
    im = ax.imshow(pivot.values, cmap="viridis_r", aspect="auto")
    ax.set_xticks(range(len(pivot.columns)))
    ax.set_xticklabels(pivot.columns)
    ax.set_yticks(range(len(pivot.index)))
    ax.set_yticklabels(pivot.index)
    ax.set_xlabel("max_green (s)")
    ax.set_ylabel("min_green (s)")
    ax.set_title("Optimization landscape: avg wait time (s) by light timing")
    fig.colorbar(im, ax=ax, label="avg wait (s)")

    best_x = list(pivot.columns).index(best_row["max_green"])
    best_y = list(pivot.index).index(best_row["min_green"])
    ax.scatter([best_x], [best_y], marker="*", s=300, c="#ff4444", edgecolors="white",
               linewidths=1.2, label="Optimizer's choice")
    ax.legend(loc="upper right")

    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)


def sweep_results_table_markdown(sweep_df, out_path):
    """The sweep results as an actual table, for direct inclusion in the
    written report (Figures/Equations/Tables requirement). Written by hand
    instead of df.to_markdown() to avoid an extra tabulate dependency."""
    df = sweep_df.copy()
    df["avg_wait_s"] = df["avg_wait_s"].round(2)
    df["idle_energy_kwh"] = df["idle_energy_kwh"].round(2)

    cols = list(df.columns)
    lines = ["| " + " | ".join(cols) + " |", "|" + "|".join(["---"] * len(cols)) + "|"]
    for _, row in df.iterrows():
        lines.append("| " + " | ".join(str(row[c]) for c in cols) + " |")

    with open(out_path, "w") as f:
        f.write("\n".join(lines))
