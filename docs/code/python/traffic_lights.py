"""Flow-responsive rule-based traffic light controller. Task 2.

Unlike a fixed timer, this actually looks at queue length before deciding
whether to switch: it holds a minimum green time, then switches early if
the current direction's queue clears out or the opposing queue backs up
past a threshold, otherwise it holds until a maximum green time is hit.
This is standard traffic-engineering gap-out/max-out logic, not a novel
invention, kept deliberately simple and explainable.
"""

MIN_GREEN_S = 5.0
MAX_GREEN_S = 25.0
YELLOW_S = 2.0
SWITCH_QUEUE_THRESHOLD = 3  # opposing queue this long forces an early switch


class TrafficLightController:
    def __init__(self, intersection_id, min_green=MIN_GREEN_S, max_green=MAX_GREEN_S):
        self.intersection_id = intersection_id
        self.min_green = min_green
        self.max_green = max_green
        self.active_axis = "NS"   # which axis currently has green
        self.state = "green"      # green | yellow
        self.time_in_state = 0.0

    def step(self, dt, queue_ns, queue_ew):
        """Advance the controller by dt seconds given current queue lengths.
        Returns the current (nsState, ewState) as ("green"/"yellow"/"red")."""
        self.time_in_state += dt

        if self.state == "green":
            current_queue = queue_ns if self.active_axis == "NS" else queue_ew
            opposing_queue = queue_ew if self.active_axis == "NS" else queue_ns

            past_min = self.time_in_state >= self.min_green
            should_gap_out = past_min and current_queue == 0
            should_max_out = self.time_in_state >= self.max_green
            should_yield = past_min and opposing_queue >= SWITCH_QUEUE_THRESHOLD

            if should_gap_out or should_max_out or should_yield:
                self.state = "yellow"
                self.time_in_state = 0.0

        elif self.state == "yellow":
            if self.time_in_state >= YELLOW_S:
                self.active_axis = "EW" if self.active_axis == "NS" else "NS"
                self.state = "green"
                self.time_in_state = 0.0

        return self._states()

    def _states(self):
        if self.active_axis == "NS":
            ns = self.state
            ew = "red"
        else:
            ns = "red"
            ew = self.state
        return ns, ew
