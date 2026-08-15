"""Energy grid management. Task 3.

Each zone's load varies by time of day (a simple daily curve, higher during
waking hours, lower overnight), plus random usage noise. A simple automated
rule sheds a fraction of load when a zone's demand crosses a threshold,
modeling basic automated distribution rather than a flat, unmanaged draw.
"""

import numpy as np

PEAK_HOURS = (7, 21)          # 7am-9pm is the "awake" window
NIGHT_MULTIPLIER = 0.45
DAY_MULTIPLIER = 1.15
SHED_THRESHOLD_KW = 160.0
SHED_FRACTION = 0.15


def time_of_day_multiplier(hour_of_day):
    if PEAK_HOURS[0] <= hour_of_day < PEAK_HOURS[1]:
        return DAY_MULTIPLIER
    return NIGHT_MULTIPLIER


def zone_load(zone, hour_of_day, rng):
    """Instantaneous load for one zone at a given hour, with automated
    shedding applied if demand crosses the threshold."""
    multiplier = time_of_day_multiplier(hour_of_day)
    noise = rng.normal(1.0, 0.08)
    raw_load = zone.base_load_kw * multiplier * max(noise, 0.5)

    shed = 0.0
    if raw_load > SHED_THRESHOLD_KW:
        shed = raw_load * SHED_FRACTION
    actual_load = raw_load - shed

    return {"zone_id": zone.id, "hour": hour_of_day, "raw_load_kw": raw_load,
            "shed_kw": shed, "actual_load_kw": actual_load}


def simulate_day(energy_zones, seed=0):
    rng = np.random.default_rng(seed)
    records = []
    for hour in range(24):
        for zone in energy_zones:
            records.append(zone_load(zone, hour, rng))
    return records
