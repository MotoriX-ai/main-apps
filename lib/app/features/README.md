# Feature structure

Each feature owns its code and is split by responsibility. Only add a layer
when the feature has real code for it; do not keep empty folders with
placeholder files.

- `models`: feature-specific data and domain types.
- `presentations`: screens, widgets, and UI state.
- `services`: repositories, API clients, persistence, and platform services.

Code shared by multiple features belongs in `app/core`.
