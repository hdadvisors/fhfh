# Fauquier Housing Needs Assessment

Technical report for Fauquier Habitat for Humanity (FHFH), funded by the PATH Foundation.
Produced by HDAdvisors. Delivered as a Quarto book → interactive website. PDF route deferred to
Session 12.

## Quick start

**Prerequisites:** R 4.5.1, Quarto 1.9+, renv.

1. **Restore the R environment:**
   ```r
   renv::restore()
   ```

2. **Render the book:**
   ```bash
   export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
   quarto render
   ```

3. Open `docs/index.html` in a browser.

> R may not be on your system PATH. Prepend `C:\Program Files\R\R-4.5.1\bin` as shown above, or
> add it permanently via System → Environment Variables.

## Repo structure

| Path | Contents |
|---|---|
| `r/` | Data collection and prep scripts (committed) |
| `data/` | `.rds` outputs + raw licensed data drops (gitignored) |
| `docs/` | Rendered website (committed; Pages-ready) |
| `_freeze/` | Frozen execution results (committed) |
| `scope/` | Scope of work PDF |
| `background/` | Reference PDFs (GP regional study, Fauquier fact sheet) |

## Chapter helpers

`_common.R` provides caption helpers — `acs_cap()`, `chas_cap()`, `mls_cap()`, `qcew_cap()`,
`dec_cap()`, `pep_cap()`, `bps_cap()`, `lodes_cap()`, `cpi_cap()`, `costar_cap()`, `fmr_cap()`,
`nhpd_cap()`, `pmms_cap()`, `compplan_cap()`, `ami_cap()`, `pit_cap()`, `vdoe_cap()` — and
`flag_reliability()`, which tiers place-level ACS estimates High/Medium/Low from a 0–100 CV column
(used instead of `hdatools::add_reliability()`, which assumes a 0–1 scale).

## Data note

`data/` is gitignored. Raw files (MLS exports, CoStar) are licensed and cannot be committed.
API-pulled `.rds` outputs are also gitignored to keep the repo lightweight; run the `r/` scripts
to reproduce them locally.

## References

- [PLAN.md](PLAN.md) — build plan, session log, and source of truth
- [CLAUDE.md](CLAUDE.md) — session conventions and run commands
- [LAPTOP-SETUP.md](LAPTOP-SETUP.md) — one-time checklist when starting on a new machine
- Template: `R:\hda\faar` (Fredericksburg Area Housing Gap Analysis)
