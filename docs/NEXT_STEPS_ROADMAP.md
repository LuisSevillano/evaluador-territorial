# Evaluador Territorial - Next Steps Roadmap

This document is a living roadmap for upcoming improvements.
Use it to capture ideas, align priorities, and track what is next.

## How to use this file

- Add new goals under the most relevant section.
- Keep each objective short and outcome-focused.
- Mark status with one of: `Backlog`, `Planned`, `In Progress`, `Done`, `On Hold`.
- Add owner and target milestone when known.

---

## Current Focus Areas

### 1) Scoring Model Improvements

- [Backlog] Add **relief accessibility** metric (10-15 minute driving context) and test blend with municipality-level relief.
- [Backlog] Recalibrate block weights (`climate`, `access`, `nature`) using sensitivity analysis.
- [Backlog] Add confidence score per municipality based on data completeness and freshness.
- [Backlog] Define and document scoring rationale for end users (transparent methodology page).

### 2) Data Quality and Reliability

- [Backlog] Add automated checks for outliers and impossible values per indicator.
- [Backlog] Add schema contract tests for all feature outputs (RDS + optional Parquet).
- [Backlog] Improve error reporting with structured logs by step and failure cause.
- [Backlog] Add a "data lineage" artifact: source -> transformation -> final field.

### 3) Pipeline Performance and Operations

- [Backlog] Benchmark step durations and produce a timing report after each run.
- [Backlog] Add selective rebuild mode by feature (`--step` or env-based targeting).
- [Backlog] Add cache health checks (detect stale/corrupt cache before compute).
- [Backlog] Create a lightweight local dashboard for pipeline status and last run metadata.

### 4) Frontend Product Experience

- [Backlog] Add indicator explanation tooltips with plain-language interpretation.
- [Backlog] Add compare mode: municipality vs province median vs top percentile.
- [Backlog] Add filtering presets (family-friendly, nature-first, connectivity-first).
- [Backlog] Improve mobile map interactions and loading feedback.

### 5) Accessibility and UX Quality

- [Backlog] Run accessibility audit (keyboard nav, contrast, focus states, ARIA labels).
- [Backlog] Add unit tests for critical UI scoring and formatting components.
- [Backlog] Define visual consistency rules for maps, legends, and score chips.

### 6) Documentation and Governance

- [Backlog] Create a concise public changelog for scoring/model updates.
- [Backlog] Document environment setup and secrets handling policy.
- [Backlog] Add contributor guide for adding new indicators safely.

---

## Candidate Next Objectives (Suggested)

If you want a practical order for the next iterations:

1. Implement relief accessibility metric and validate effect on rankings.
2. Add timing + cache health report to make runs predictable.
3. Add confidence score and expose it in frontend inspector.
4. Add compare mode in frontend (municipality/province/percentiles).

---

## Objective Template

Copy and paste this block when adding a new objective:

```md
### Objective: <Title>
- Status: Backlog
- Owner: <Name>
- Target milestone: <YYYY-MM or sprint>
- Why: <Expected impact>
- Scope: <What is included>
- Acceptance criteria:
  - <Criterion 1>
  - <Criterion 2>
```


- Mejorar los gráficos del inspector