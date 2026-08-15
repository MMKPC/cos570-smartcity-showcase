"""Performance analysis. Task 6. pandas aggregation over logged sim output,
the actual required metrics: wait time, throughput, energy efficiency."""

import pandas as pd


def traffic_metrics(car_records):
    df = pd.DataFrame(car_records)
    if df.empty:
        return {"avg_wait_s": 0.0, "p95_wait_s": 0.0, "throughput_per_min": 0.0}, df

    duration_s = df["release_t"].max() - df["arrival_t"].min()
    duration_min = max(duration_s / 60.0, 0.01)

    summary = {
        "avg_wait_s": float(df["wait_s"].mean()),
        "p95_wait_s": float(df["wait_s"].quantile(0.95)),
        "throughput_per_min": float(len(df) / duration_min),
    }
    per_intersection = df.groupby("intersection")["wait_s"].agg(["mean", "count"]).reset_index()
    return summary, per_intersection


def energy_metrics(energy_records):
    df = pd.DataFrame(energy_records)
    raw_total = float(df["raw_load_kw"].sum())
    actual_total = float(df["actual_load_kw"].sum())
    # delivered/demanded ratio: how much of raw demand was actually served
    # without being shed. Not "efficiency" in the thermodynamic sense --
    # nothing is being converted or lost, it's a deliberate shedding choice.
    delivered_ratio_pct = (actual_total / raw_total * 100.0) if raw_total > 0 else 100.0

    # Each record is one zone's load held constant for one simulated hour
    # (see simulate_day: one record per zone per hour), so a kW value IS
    # kWh for that hour already -- no /60 conversion. That conversion would
    # only be correct if records were per-minute, which they are not.
    summary = {
        "avg_load_kw": float(df["actual_load_kw"].mean()),
        "total_shed_kwh": float(df["shed_kw"].sum()),
        "peak_load_kw": float(df["actual_load_kw"].max()),
        "delivered_ratio_pct": delivered_ratio_pct,
    }
    per_zone_hour = df.pivot_table(index="zone_id", columns="hour", values="actual_load_kw")
    return summary, per_zone_hour
