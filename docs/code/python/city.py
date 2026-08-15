"""City layout: intersections and energy zones. Task 1."""

from dataclasses import dataclass, field


@dataclass
class Intersection:
    id: str
    x: float
    z: float


@dataclass
class EnergyZone:
    id: str
    x: float
    z: float
    base_load_kw: float


def build_city():
    """4 intersections in a 2x2 grid, 4 energy zones, one per quadrant,
    positioned at each quadrant's center so the energy grid is actually
    part of the map, not a free-floating list disconnected from it."""
    intersections = [
        Intersection("I-NW", -20, -20),
        Intersection("I-NE", 20, -20),
        Intersection("I-SW", -20, 20),
        Intersection("I-SE", 20, 20),
    ]
    energy_zones = [
        EnergyZone("Z-NW", x=-10, z=-10, base_load_kw=120),
        EnergyZone("Z-NE", x=10, z=-10, base_load_kw=95),
        EnergyZone("Z-SW", x=-10, z=10, base_load_kw=140),
        EnergyZone("Z-SE", x=10, z=10, base_load_kw=110),
    ]
    return intersections, energy_zones
