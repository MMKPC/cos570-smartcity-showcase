"""AI Optimization. Task 4, and the one that actually matters most.

"Energy wastage" here is modeled as vehicle idling waste: every second a
car sits waiting at a red light is a second of wasted fuel/energy. That
gives traffic-light timing a genuine, defensible link to energy, not just
wait time, without conflating it with the separate building energy-grid
model in energy.py, which is a different system (Task 3).

Approach: sweep light-timing parameters, run the real simulation for each,
record actual wait time and idle energy, then train a small decision tree
regressor on the results, both to predict performance at untested settings
(the "predictive model" learning outcome) and to pick the best setting
found. Simple and explainable on purpose, this is a class project, not a
production traffic system.
"""

import numpy as np
import pandas as pd
from sklearn.tree import DecisionTreeRegressor

from city import build_city
from city_sim import run_simulation

IDLE_ENERGY_KWH_PER_VEHICLE_SEC = 0.02  # illustrative assumption, stated explicitly
SWEEP_DURATION_S = 900  # 15 simulated minutes per trial, enough cars to average over

DEFAULT_MIN_GREEN = 5.0
DEFAULT_MAX_GREEN = 25.0


def score_run(car_records):
    if not car_records:
        return {"avg_wait_s": 0.0, "idle_energy_kwh": 0.0, "throughput": 0}
    waits = [r["wait_s"] for r in car_records]
    avg_wait = float(np.mean(waits))
    idle_energy = float(sum(waits) * IDLE_ENERGY_KWH_PER_VEHICLE_SEC)
    return {"avg_wait_s": avg_wait, "idle_energy_kwh": idle_energy, "throughput": len(car_records)}


def sweep(min_green_options, max_green_options, seed=1):
    intersections, _ = build_city()
    rows = []
    for min_g in min_green_options:
        for max_g in max_green_options:
            if max_g <= min_g:
                continue
            car_records, _ = run_simulation(intersections, min_g, max_g, SWEEP_DURATION_S, seed)
            scored = score_run(car_records)
            rows.append({"min_green": min_g, "max_green": max_g, **scored})
    return pd.DataFrame(rows)


def train_and_optimize(df):
    """Trains a decision tree on the swept results and picks the best
    (min_green, max_green) by actual measured wait time, the model's job is
    prediction quality, not standing in for ground truth we already have."""
    X = df[["min_green", "max_green"]].values
    y = df["avg_wait_s"].values

    model = DecisionTreeRegressor(max_depth=4, random_state=0)
    model.fit(X, y)
    predicted = model.predict(X)
    residual = y - predicted
    fit_r2 = 1 - (residual ** 2).sum() / ((y - y.mean()) ** 2).sum()

    best_row = df.loc[df["avg_wait_s"].idxmin()]
    return model, fit_r2, best_row


def compare_to_default(best_row, seed=2):
    intersections, _ = build_city()
    default_records, _ = run_simulation(
        intersections, DEFAULT_MIN_GREEN, DEFAULT_MAX_GREEN, SWEEP_DURATION_S, seed
    )
    optimized_records, _ = run_simulation(
        intersections, best_row["min_green"], best_row["max_green"], SWEEP_DURATION_S, seed
    )
    return score_run(default_records), score_run(optimized_records)


if __name__ == "__main__":
    df = sweep(min_green_options=[3, 5, 7, 10], max_green_options=[15, 20, 25, 30])
    print(df.to_string(index=False))

    model, fit_r2, best_row = train_and_optimize(df)
    print(f"\nDecision tree fit R^2 on sweep data: {fit_r2:.3f}")
    print(f"Best setting found: min_green={best_row['min_green']}, max_green={best_row['max_green']}, "
          f"avg_wait_s={best_row['avg_wait_s']:.2f}")

    default_score, optimized_score = compare_to_default(best_row)
    print(f"\nDefault (min=5, max=25):   avg_wait={default_score['avg_wait_s']:.2f}s, "
          f"idle_energy={default_score['idle_energy_kwh']:.2f}kWh, throughput={default_score['throughput']}")
    print(f"Optimized (min={best_row['min_green']}, max={best_row['max_green']}): "
          f"avg_wait={optimized_score['avg_wait_s']:.2f}s, "
          f"idle_energy={optimized_score['idle_energy_kwh']:.2f}kWh, throughput={optimized_score['throughput']}")

    improvement = (default_score["avg_wait_s"] - optimized_score["avg_wait_s"]) / default_score["avg_wait_s"] * 100
    print(f"\nWait time improvement: {improvement:.1f}%")
