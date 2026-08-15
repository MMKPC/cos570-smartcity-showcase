"""The discrete-event traffic simulation for the public technical showcase.
The flow-responsive lights are built on simpy and use a small, explainable
control surface.

Cars arrive at each intersection approach on a random (Poisson) schedule,
queue up, and are released one at a time while their axis has a green
light. Wait time = release time - arrival time. Every light state change
is logged so downstream code (metrics, charts, the visual replay) all read
from the exact same record of what actually happened.
"""

import simpy
import numpy as np

from traffic_lights import TrafficLightController

SIM_STEP_S = 0.5
SERVICE_INTERVAL_S = 2.5   # how often one queued car can depart on green
ARRIVAL_RATE_PER_MIN = 6.0  # average cars/minute per approach

# Vehicle mix at arrival. Cars dominate, trucks and motorcycles are rarer.
# This is real per-car data threaded through to release_log, not a visual-only
# label — the Unreal viewer colors blocks off this exact field.
VEHICLE_TYPES = ["car", "car", "car", "car", "car", "car", "truck", "truck", "motorcycle"]


class IntersectionSim:
    def __init__(self, env, intersection, min_green, max_green, log):
        self.env = env
        self.intersection = intersection
        self.controller = TrafficLightController(intersection.id, min_green, max_green)
        self.queues = {"NS": [], "EW": []}
        self.log = log
        self.last_release = {"NS": -999, "EW": -999}
        self.car_records = []
        self._last_state = (None, None)

    def car_arrival_process(self, axis, rng):
        while True:
            gap = rng.exponential(60.0 / ARRIVAL_RATE_PER_MIN)
            yield self.env.timeout(gap)
            vehicle_type = rng.choice(VEHICLE_TYPES)
            self.queues[axis].append({"arrival_t": self.env.now, "vehicle_type": vehicle_type})

    def controller_process(self):
        while True:
            yield self.env.timeout(SIM_STEP_S)
            ns_state, ew_state = self.controller.step(
                SIM_STEP_S, len(self.queues["NS"]), len(self.queues["EW"])
            )
            if (ns_state, ew_state) != self._last_state:
                self.log.append({
                    "t": self.env.now, "intersection": self.intersection.id,
                    "ns_state": ns_state, "ew_state": ew_state,
                })
                self._last_state = (ns_state, ew_state)

            for axis, state in (("NS", ns_state), ("EW", ew_state)):
                if state == "green" and self.queues[axis]:
                    if self.env.now - self.last_release[axis] >= SERVICE_INTERVAL_S:
                        queued = self.queues[axis].pop(0)
                        arrival_t = queued["arrival_t"]
                        wait = self.env.now - arrival_t
                        self.car_records.append({
                            "intersection": self.intersection.id, "axis": axis,
                            "arrival_t": arrival_t, "release_t": self.env.now, "wait_s": wait,
                            "vehicle_type": queued["vehicle_type"],
                        })
                        self.last_release[axis] = self.env.now


def run_simulation(intersections, min_green, max_green, duration_s=1800, seed=0):
    """Runs one simulation trial. Returns (car_records, light_log)."""
    rng = np.random.default_rng(seed)
    env = simpy.Environment()
    light_log = []
    sims = []
    for it in intersections:
        sim = IntersectionSim(env, it, min_green, max_green, light_log)
        env.process(sim.car_arrival_process("NS", rng))
        env.process(sim.car_arrival_process("EW", rng))
        env.process(sim.controller_process())
        sims.append(sim)

    env.run(until=duration_s)

    car_records = [rec for sim in sims for rec in sim.car_records]
    return car_records, light_log
