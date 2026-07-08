# CLAUDE.md — FHFH Housing Needs Assessment

Conventions for all Claude sessions on this project. See PLAN.md for the full source of truth.

## Quick start

**Render the book:**
```bash
export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
quarto render
```

**Run an R script:**
```bash
export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
Rscript r/script-name.R
```

> R is **not** on the system PATH. Always prepend the path as shown above.
> Recommendation: add `C:\Program Files\R\R-4.5.1\bin` to Windows PATH permanently via
> System → Environment Variables → Path → New.

**Restore the renv environment (first time after cloning):**
```r
renv::restore()
```

## Data flow rule

`r/` scripts → `data/*.rds` → chapters read via `read_rds()` only. **Chapters never call APIs.**

## Code style (PLAN.md §3)

- Native pipe `|>`. Tidyverse style. `janitor::clean_names()` on all imported raw data.
- dplyr ≥ 1.2 idioms: `.by=` over `group_by()` for one-off grouping; `across()`; `join_by()`;
  `recode_values(.unmatched = "error")` for ACS variable→label recoding; `reframe()` for
  multi-row summaries; `replace_values()`/`replace_when()`; `when_any()`/`when_all()`.
- `purrr::map()`/`map_dfr()` over `for` loops.
- Script anatomy: header comment block (what/source/output), `## 1. Setup ----` numbered
  sections, ends with `write_rds()` then a validation block. No inline `install.packages()`.
  Scripts are idempotent — safe to re-run.
- Validation blocks: `stopifnot()`/warning checks against GP-study benchmarks (PLAN.md §3).

## Windows R rule

**Never run R inline.** Write a temp script, run via `Rscript` from the project root. Temp and
ad-hoc scripts (renv setup, key checks, one-off queries) go in the scratchpad, not the repo.

## Geography constants

Defined once in `_common.R` (sourced by every chapter):

```r
fauquier   <- "51061"
towns      <- c(warrenton = "5183136", bealeton = "5105336")  # resolved via tigris Session 1
benchmarks <- c(culpeper = "51047", prince_william = "51153", loudoun = "51107")
virginia   <- "51"
town_zips  <- list(warrenton = c("20186", "20187"), bealeton = "22712")
```

## API keys

`CENSUS_API_KEY` and `FRED_API_KEY` live in `C:\Users\JTK\Documents\.Renviron`. Never print or
commit values. Verify key visibility to R with a TRUE/FALSE check only (see PLAN.md §3).

## Publishing status

`docs/` is committed to `main`. **GitHub Pages is NOT enabled** — the repo is private and the
hdadvisors org is on GitHub Free, which only serves Pages from public repos.

To enable Pages later (once the repo is public or the org upgrades to Team/Enterprise):
```
gh api -X POST repos/hdadvisors/fhfh/pages \
  -f "source[branch]=main" \
  -f "source[path]=/docs"
```
Or: Settings → Pages → Deploy from branch → `main` / `docs`. URL will be
`https://hdadvisors.github.io/fhfh/`.

## Session hygiene

- Start: read CLAUDE.md + your PLAN.md §9 session block. Verify prerequisite raw files exist.
- End: tick §9 checkboxes, add dated §11 log entry, update README/CLAUDE.md if conventions
  changed, commit (concise message, no co-author lines).

## Repo map

```
fhfh/
├── _quarto.yml           book config (freeze: auto, output-dir: docs)
├── _common.R             global opts + palettes + geography constants + caption helpers
├── .Rprofile             activates renv
├── index.qmd             About this study
├── exec-sum.qmd          Executive summary (stub — Session 12)
├── inventory.qmd         Ch 1  Inventory & Production
├── demographics.qmd      Ch 2  Demographics & Socioeconomics
├── market-ownership.qmd  Ch 3a Ownership Market
├── market-rental.qmd     Ch 3b Rental Market
├── gaps.qmd              Ch 4  Affordability Gaps
├── populations.qmd       Ch 5  Vulnerable Populations
├── projections.qmd       Ch 6  Projected Needs
├── conclusions.qmd       Ch 7  Conclusions
├── data-notes.qmd        Appendix: Data & Methodology
├── r/                    collection/prep scripts (committed)
├── data/                 .rds outputs + raw drops (gitignored — licensed sources)
├── docs/                 rendered site (committed; Pages-ready when repo goes public)
└── _freeze/              frozen execution results (committed)
```
