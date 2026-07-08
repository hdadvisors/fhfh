# Session 1 (Scaffold) — FHFH Housing Needs Assessment

Detailed execution plan for PLAN.md §9 **Session 1 — Scaffold**. PLAN.md (repo root) remains the
source of truth; this document is the step-by-step build reference for the session. Intended to be
executed in its own session (see the handoff prompt used to launch it).

## Context

PLAN.md (repo root, `R:\hda\fhfh\PLAN.md`) is the source of truth for building the FHFH
(Fauquier Habitat for Humanity) technical report — a Quarto **book** → website, modeled on the
faar template at `R:\hda\faar`. This is Session 1 of 12: **structure only — no data pulls, no
figures, no chapter content.** The goal is a clean-rendering skeleton site, a reproducible renv
environment, adapted helper files, and project docs, all committed and pushed.

The repo is already git-initialized and pushed to `hdadvisors/fhfh` (first checklist item is
pre-done). This plan executes every remaining PLAN.md §9 Session 1 item.

### Two decisions confirmed with Jonathan

1. **Repo stays PRIVATE → skip Pages.** The hdadvisors org is on GitHub **Free**, which only serves
   Pages from *public* repos (faar is public → live). fhfh is private and stays private. So do
   **not** flip visibility and **not** enable Pages. Scaffold, renv-install, render clean, and
   commit/push everything (including `docs/`), then log Pages as blocked in §11 with exact enable
   steps. The "live on Pages" part of the DoD is explicitly deferred.
2. **R via full path this session; standardize on R 4.5.1.** R is installed (4.4.2/4.4.3/4.5.0/4.5.1)
   but not on PATH. Prepend `C:\Program Files\R\R-4.5.1\bin` to PATH inside each R/Quarto command
   (no restart). CLAUDE.md documents the path + recommends adding it to PATH permanently.

### Environment status (verified 2026-07-08, read-only)

| Check | Status |
|---|---|
| R ≥ 4.4 | ✅ 4.5.1 runs via full path (not on PATH — handled per decision 2) |
| Quarto CLI | ✅ 1.9.36 |
| gh auth | ✅ `knopfjt`, scopes `gist, read:org, repo, workflow` |
| CENSUS_API_KEY / FRED_API_KEY | ✅ both present in `C:\Users\JTK\Documents\.Renviron` (names only; values never read) |
| faar template | ✅ readable at `R:\hda\faar` |
| fhfh remote | ✅ `origin → https://github.com/hdadvisors/fhfh.git` (private, default branch `main`) |
| hdadvisors/hdatools | ✅ public → `renv::install("hdadvisors/hdatools")` needs no PAT |
| GitHub Pages | ⛔ blocked (private repo + free org) → deferred |

---

## Shell conventions for this session

- **R:** every R invocation runs from the project root (`R:\hda\fhfh`) via Bash with PATH prepended:
  `export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"; Rscript <script>`
  Per PLAN §3 & user rule: **never inline R** — write a temp script, run via `Rscript`. Temp/ad-hoc
  scripts go in the scratchpad, **not** the repo, so they aren't committed.
- **Render:** `export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"; quarto render` (PATH prepend lets
  Quarto's knitr engine find R).
- **hdatools install:** set `export GITHUB_PAT="$(gh auth token)"` in the install command's env to
  avoid anonymous GitHub rate limits (never echo the token).

---

## Execution plan

### Phase 1 — Interactive prerequisites (gate; before scaffolding)

1. **Walk Jonathan through the one-time skill installs**, one at a time, waiting for confirmation
   after each (these are slash commands he types — the agent cannot run them; PLAN §3):
   - `/plugin marketplace add posit-dev/skills`
   - `/plugin install quarto@posit-dev-skills`
2. Environment checks already done (table above). No blocking failures given the two decisions.
   Re-confirm API keys are visible **to R** during Phase 2 via a temp Rscript (step 2.5).

### Phase 2 — Scaffold (PLAN.md §9 Session 1 checklist)

Ordered so renv exists before any R script runs, and GEOIDs resolve before the render:

**2.1 Create Quarto skeleton + project files** (all static, no R needed):
`_quarto.yml`, `index.qmd`, `exec-sum.qmd`, 8 chapter stubs, `data-notes.qmd`, `conclusions.qmd`,
`_common.R` (with placeholder town GEOIDs), `r/affordcalc.R`, `CLAUDE.md`, `README.md`, `.nojekyll`;
rewrite `.gitignore`; create `.renvignore`. (Full specs in **File manifest** below.)

**2.2 Initialize renv + install the toolchain + snapshot** (one temp script, long-running — run in
background / 10-min timeout). Uses Posit PPM for Windows binaries:
```r
# scratchpad/renv_setup.R
options(repos = c(CRAN = "https://packagemanager.posit.co/cran/latest"))
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
renv::init(project = "R:/hda/fhfh", bare = TRUE, restart = FALSE)
renv::install(c(
  "tidyverse", "tidycensus", "tigris", "sf", "janitor", "kableExtra",
  "formattable", "ggtext", "scales", "fredr", "lehdr", "readxl", "FinCal",
  "hdadvisors/hdatools"
), project = "R:/hda/fhfh")
renv::snapshot(project = "R:/hda/fhfh", type = "all")   # type="all": lock the full installed
                                                         # library (r/ deps aren't referenced yet)
```
- dplyr ≥ 1.2 pin: verify `renv.lock` shows dplyr ≥ 1.2.0 after snapshot; if PPM's latest is older,
  `renv::install("dplyr")` explicitly and re-snapshot. (Latest dplyr as of mid-2026 is ≥ 1.2.)
- `type = "all"` is used because in Session 1 only `_common.R` (6 core pkgs) and `affordcalc.R`
  (tidyverse, FinCal) reference packages; tidycensus/tigris/sf/etc. aren't used until Sessions 2–7.

**2.3 Resolve Warrenton & Bealeton GEOIDs via tigris** (temp script; approved package download):
```r
# scratchpad/geoids.R
library(tigris); library(dplyr)
options(tigris_use_cache = TRUE)
pl <- places(state = "VA", cb = FALSE, year = 2023)
pl |> filter(NAMELSAD %in% c("Warrenton town", "Bealeton CDP")) |>
  select(GEOID, NAMELSAD) |> arrange(NAMELSAD) |> print(n = Inf)
```
Capture the two 7-digit GEOIDs (state `51` + 5-digit place). **Do not hardcode from memory** (PLAN §4).

**2.4 Patch resolved GEOIDs** into `_common.R` (`towns <- c(warrenton = "…", bealeton = "…")`) and
into PLAN.md §4 (replace the "resolve via tigris" placeholders with the actual GEOIDs).

**2.5 Verify API keys are visible to R** (temp script prints only TRUE/FALSE — never values):
```r
# scratchpad/keycheck.R
cat("CENSUS_API_KEY:", nzchar(Sys.getenv("CENSUS_API_KEY")), "\n")
cat("FRED_API_KEY:",   nzchar(Sys.getenv("FRED_API_KEY")),   "\n")
```
Expect `TRUE`/`TRUE` (R reads `~/Documents/.Renviron` at startup). If FALSE, stop and report.

**2.6 Render** `export PATH=…; quarto render` from project root → must complete clean, producing
`docs/` + `_freeze/`. Fix any issue (most likely: a package missing from the lock, or a stub syntax
error) and re-render until clean.

**2.7 Update PLAN.md** (§4 GEOIDs already done in 2.4): tick §9 Session 1 checkboxes (annotate the
git-init item as pre-done and the Pages item as deferred), flip the §11 status-table row 1 to
`complete / <execution date> / Sonnet 4.6`, and add a dated §11 log entry (files created, GEOIDs
resolved, Pages deferred with reason, any deviations).

**2.8 Delete `STARTUP.md`** (last — confirmed disposable; its content, the two Google-Doc IDs and
faar path, is already captured in PLAN.md §1).

**2.9 Commit + push** — stage all new/changed files (incl. `docs/`, `_freeze/`, `renv.lock`,
`renv/activate.R`+`settings.json`, the `.gitignore` rewrite, PLAN.md edits, STARTUP.md deletion).
One concise commit, **no Claude/Anthropic co-author**, then `git push origin main`.

---

## File manifest

### `_quarto.yml` (adapt faar: book, freeze auto, output-dir docs; §2 chapter spine, flat)
```yaml
project:
  type: book
  execute-dir: project
  output-dir: docs

execute:
  freeze: auto

book:
  title: "Fauquier Housing Needs Assessment"
  subtitle: "Fauquier County, the Town of Warrenton, and Bealeton"
  repo-url: https://github.com/hdadvisors/fhfh
  output-file: "fhfh-housing-needs-assessment"
  author:
    - name: HDAdvisors
      url: https://hdadvisors.net/
  date: today
  date-format: long
  chapters:
    - index.qmd
    - exec-sum.qmd
    - inventory.qmd
    - demographics.qmd
    - market-ownership.qmd
    - market-rental.qmd
    - gaps.qmd
    - populations.qmd
    - projections.qmd
    - conclusions.qmd
  appendices:
    - data-notes.qmd

format:
  html:
    theme:
      - lumen
    grid:
      sidebar-width: 275px
    fontsize: "100%"
    toc-title: "On this page"
    number-depth: 2
    reference-location: margin
    footnotes-hover: false
    crossrefs-hover: false
    html-table-processing: none

# PDF route (format: typst vs. manual assembly) deferred to Session 12 — PLAN.md §9.
```

### Chapter stubs — anchors (`# Title {#sec-slug}`) + 1-line purpose + setup chunk
| File | Heading + anchor | Built in |
|---|---|---|
| `inventory.qmd` | `# Current Inventory & Recent Production Trends {#sec-inventory}` | S8 |
| `demographics.qmd` | `# Demographic Shifts & Socioeconomic Factors {#sec-demographics}` | S8 |
| `market-ownership.qmd` | `# Ownership Market Dynamics {#sec-market-ownership}` | S9 |
| `market-rental.qmd` | `# Rental Market Dynamics {#sec-market-rental}` | S9 |
| `gaps.qmd` | `# Affordability Gaps {#sec-gaps}` | S10 |
| `populations.qmd` | `# Vulnerable Populations {#sec-populations}` | S10 |
| `projections.qmd` | `# Projected Housing Needs {#sec-projections}` | S11 |
| `conclusions.qmd` | `# Conclusions {#sec-conclusions}` | S11 |
| `data-notes.qmd` | `# Data notes {#sec-data-notes}` (appendix) | S11 |

Each stub template (note: outer fence shown with four backticks so the inner R chunk is literal):

````markdown
# Current Inventory & Recent Production Trends {#sec-inventory}

<!-- Purpose: current housing stock + recent production trends for the study area (PLAN.md §7 Ch 1). -->

```{r}
#| label: setup
#| include: false
source("_common.R")
```

*Figures, tables, and findings are built in Session 8 (PLAN.md §7, §9).*
````
- `exec-sum.qmd`: `# Executive summary {#sec-exec-sum .unnumbered}` + one-line "built in Session 12"
  note; no setup chunk.
- `index.qmd`: `engine: knitr` frontmatter, `# About this study {.unnumbered}`, a short factual
  study-framing paragraph + objectives bullets from PLAN §1/scope (client FHFH, funder PATH
  Foundation, consultant HDA, study area = county + Warrenton + Bealeton; scope coverage). **No**
  PDF-download block (deferred). This is structural framing, not chapter/data content.
- Including `source("_common.R")` in every chapter stub is a deliberate render smoke-test: it proves
  `_common.R` and the full core package stack load cleanly everywhere.

### `_common.R` (adapt faar; add caption variants + geography constants)
Keep faar's knitr opts, 6 core libraries, `hda_pal`, `cb_pal`, `fct_wrap`, and the HTML/non-HTML
block verbatim. Changes:
- `acs_cap()` default `year = "2020-2024"` (anchor vintage, PLAN §4).
- Add `chas_cap()`, `mls_cap()`, `qcew_cap()` (PLAN §3).
- Add geography constants (PLAN §4):
```r
fauquier   <- "51061"                                  # primary unit
towns      <- c(warrenton = "<GEOID>", bealeton = "<GEOID>")   # resolved via tigris (step 2.3)
benchmarks <- c(culpeper = "51047", prince_william = "51153", loudoun = "51107")
virginia   <- "51"
town_zips  <- list(warrenton = c("20186", "20187"), bealeton = "22712")  # list, not vector*
```
  *PLAN §4 wrote `town_zips` as a `c(...)` with a nested vector, which flattens; a named **list** is
  the correct structure. Minor deviation, logged in §11.
- Do **not** add `sf`/`tidycensus`/etc. to `_common.R` — those load per-chapter/per-script (faar
  pattern), keeping render robust.

### `r/affordcalc.R` (copy-adapt faar → clean, source-safe function library)
Remove faar's demo frames (`localities_df`, `price_df`) and bottom-of-file executions so the file is
**safe to `source()` with no side effects**. Keep the three function **names**; parameterize the
mortgage assumptions (faar values as defaults, flagged for Session 6 to feed current PMMS rate +
Fauquier tax/insurance per §8); fix `renter_income` to numeric (faar returned a `format()`ed
string). Header comment per §3 script anatomy; noted as a function library (exempt from the
`write_rds()`/validation-block convention). `calc_affordable_sales` takes a `dwn_opts` vector rather
than three positional args (cleaner; Session 6 consumes it fresh).

### `.gitignore` (rewrite — data/ ignored; docs/, r/, _freeze/ tracked)
```
# R
.Rhistory
.Rapp.history
.RData
.RDataTmp
.Ruserdata
.Renviron

# RStudio
.Rproj.user/

# Quarto
/.quarto/

# Data — outputs (.rds) and raw drops (licensed MLS/CoStar; large). Never committed.
/data/

# OS
.DS_Store
Thumbs.db
```
Critical vs. the existing template: **remove `docs/`** (must be committed for Pages) and add
`/data/` + `/.quarto/`. Do **not** ignore `r/`, `docs/`, `_freeze/`, or `renv/` (renv self-manages
`renv/.gitignore`).

### `.renvignore` (adapt faar)
```
/data/
/docs/
/.quarto/
/_freeze/
```
Deliberately **omit `/r/`** (faar ignored it): in fhfh, `r/` is committed pipeline code and the sole
home of the API packages, so renv should track its deps for future `renv::status()`/snapshots.
Deviation logged in §11.

### `.nojekyll` — empty file (GitHub Pages: serve `_`-prefixed assets).

### `CLAUDE.md` (condensed §§2–4 + run commands + repo map; quick-start first)
Quick-start block first: render command, run-an-R-script command (with the **R-not-on-PATH** caveat
+ exact path `C:\Program Files\R\R-4.5.1\bin`, and the "add to PATH permanently" recommendation),
`renv::restore()`. Then: data-flow rule (r/ → data/*.rds → chapters `read_rds()` only; chapters
never call APIs); code style (native pipe, dplyr ≥1.2 idioms, `janitor::clean_names`, purrr over
loops, script anatomy, no inline `install.packages`, idempotent); Windows R rule (never inline;
temp script + Rscript); geography constants live in `_common.R`; API keys in `~/Documents/.Renviron`
(never print/commit); publishing status (docs/ committed; **Pages NOT enabled** — private repo +
free org; see §11 for enable steps); session hygiene (read CLAUDE.md + §9 block; end with checkbox
ticks + §11 log + commit, no co-author); repo map (the §2 tree).

### `README.md` (quick-start first)
What it is (HDA housing needs assessment for FHFH; Quarto book → website, PDF later) → Quick start
(prereqs R 4.5.1 + Quarto + renv; `renv::restore()`; `quarto render`; open `docs/index.html`) →
repo structure → data note (data/ gitignored, licensed sources) → links (PLAN.md, faar template).

---

## PLAN.md edits (step 2.7)

- **§4** geography table: replace the "resolve via tigris in Session 1" placeholders for Warrenton
  town and Bealeton CDP with the resolved GEOIDs.
- **§9 Session 1** checkboxes: tick all; annotate `git init/repo/first commit` as pre-done and
  `Render, publish… confirm URL` as **render done / Pages deferred (private repo + free org)**.
- **§11 status table** row 1 → `complete | <execution date> | Sonnet 4.6`.
- **§11 log** new dated entry: skeleton built, packages installed & snapshotted (type=all), GEOIDs
  resolved (record them), Pages deferred with reason + exact enable steps, deviations (`town_zips`
  list; `.renvignore` keeps `/r/`; `affordcalc.R` cleaned/parameterized).

---

## Verification (Definition of Done)

- [ ] `quarto render` completes **clean** (no errors); `docs/index.html` + all 11 pages generated;
      sidebar shows the §2 chapter spine; `_freeze/` populated.
- [ ] Spot-check rendered `docs/`: each chapter page has its `{#sec-}` anchor; `_common.R` sourced
      without error (proves renv env + hdatools load).
- [ ] `renv.lock` present, R pinned to 4.5.1, dplyr ≥ 1.2.0, hdatools from GitHub, all 13 listed
      packages locked.
- [ ] API key check prints `TRUE`/`TRUE`.
- [ ] Warrenton + Bealeton GEOIDs resolved via tigris and recorded in `_common.R` **and** PLAN §4.
- [ ] `STARTUP.md` deleted.
- [ ] PLAN §9 checkboxes ticked; §11 log entry + status row updated.
- [ ] Everything committed and pushed to `origin main` (concise message, no co-author).
- [⛔ deferred] Site live on Pages — blocked (private repo + free org). Enable later via either
  Settings → Pages → Deploy from branch → `main` `/docs`, or
  `gh api -X POST repos/hdadvisors/fhfh/pages -f "source[branch]=main" -f "source[path]=/docs"`
  **after** making the repo public or upgrading the org to Team/Enterprise. URL will be
  `https://hdadvisors.github.io/fhfh/`.

## Out of scope (Session 1)
No data pulls (beyond the one-time tigris GEOID resolution, which PLAN §4 & the task explicitly
require), no figures, no chapter content. Where PLAN.md and faar conflict, PLAN.md wins.
