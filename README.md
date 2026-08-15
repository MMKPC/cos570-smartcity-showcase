# Smart-City Traffic + Energy Simulation

Private portfolio companion for a traffic, energy, and realtime-systems project.

This showcase presents the technical notes, simulation results, Unreal evidence, Python pipeline, AngelScript integration, and a browser-based replay viewer. The full Unreal project and its source assets are intentionally excluded.

## Open the showcase

The site is published from `docs/` with GitHub Pages. Open `docs/index.html` locally or serve the repository through a static web server.

## What it demonstrates

- A discrete-event traffic simulation across four intersections and energy zones.
- A decision-tree optimizer trained to select traffic-light timing.
- Python metrics, charts, and machine-readable replay data.
- AngelScript data and loop-director examples for Unreal integration.
- A Three.js viewer that replays the logged optimized run without re-simulating it.

## Public boundary

The public repository contains portfolio material only: selected code, charts, screenshots, the demonstration video, written research, and replay data. It does not contain the Unreal project, maps, cooked content, private plugins, credentials, or private AYO infrastructure.

## Studio control

This repository is now a private MMKPC Studios showcase artifact for later integration into MMKProspects.com. The current access policy is in `LICENSE`, credential handling is in `SECURITY.md`, and the release gate is `scripts/validate_studio_manifest.ps1`.

## Local replay

Serve the repository from its root so the viewer can fetch `docs/data/light_schedule.json`:

```powershell
python -m http.server 8580
```

Then open `http://localhost:8580/docs/`.
