# Session 10 (Affordability Gaps + Vulnerable Populations chapters) — FHFH Housing Needs Assessment

Builds Ch 4 (`gaps.qmd`) and Ch 5 (`populations.qmd`). **PLAN.md is the source of truth**; this file is modeled on `plans/session-09-market-chapters.md` and follows the S8/S9 chapter-build pattern. Two implementation sittings, one chapter each (see split note).

---

## Context

- **Targets:** 15 §7 deliverables — Ch 4 F1–F9 (nine), Ch 5 F1–F6 (six). Report order: gaps and populations sit **between `market-rental` and `projections`**.
- **Narrative rule (§3, non-negotiable):** takeaway chart titles + 2–5 bullet findings per section (each traceable to a figure/table) + callout boxes only. **No drafted prose paragraphs.** Bullets must be specific enough that a human can expand them without reopening the data.
- **Data-flow rule:** `r/` scripts → `data/*.rds` → chapters `read_rds()` **only**. Chapters never call APIs. (The one exception this session is a Phase-0 upstream re-run of `r/acs_costs.R` — see Phase 0b.)
- **Model:** Opus (judgment-heavy chapter build).
- **Natural split point (mirrors S8/S9):** Part 1 = Phase 0 (caption helpers + `r/acs_costs.R` multi-year burden pull) + `gaps.qmd`; Part 2 = `populations.qmd` + session close.
- **Per-chapter DoD (§9):** chapter renders in the book; all §7 figures present or §11-logged as deferred; town callout(s); §6 interview-validation callout; reliability spot-check on town cells.

### Chapter → dataset map (`read_rds()` inputs)

| Chapter | `.rds` inputs |
|---|---|
| `gaps.qmd` (Ch 4) | `gaps` (afford_by_band, rental_gap, ownership_gap, wages_costs, income_needed, assumptions), `chas` (t7, t8), `acs_costs` (B25070, B25091 + **new** multi-year burden frames), `hud_ami` (ami, mfi, area_name, cap_note) |
| `populations.qmd` (Ch 5) | `acs_specialpop` (b18101, b11003, s1702, b25007, vars), `pit` (trend, location_2025, meta), `vdoe` (fauquier, statewide), `wcoop` (age_county — context stat only), `acs_demographics` (b11007), `acs_stock` (b25024, b25032, b25047, b25051, b25014, vars), `chas` (t7 elderly) |

> **Note — the task brief's Ch 5 map (acs_specialpop/pit/vdoe) is narrower than §7 requires.** §7 Ch 5 Fig 1 needs `wcoop` + `acs_demographics$b11007` + `chas$t7`; Fig 5 needs `acs_stock$b25047/b25051/b25014`; Fig 6 needs `acs_stock$b25024/b25032`. **All verified present read-only (Step 0)** — no upstream re-run needed for Ch 5.

---

## Decisions locked for this session (2026-07-13)

1. **Ch 4 burden-source split (Session 6, locked).** Fig 4 (burden headline) uses **ACS** B25070/B25091 — **renter 40.2% / owner 21.5%** (GP's headline, reproduced exactly; ACS drops ~700 "not computed" renters from the denominator). Fig 5 (by-AMI-band core chart) uses **CHAS T8** — **renter 32.9% / owner 20.1%** (validated exactly at Step 0). Both figures appear; the narrative and a footnote must reconcile them (see F4/F5). Full methodology note is deferred to `data-notes.qmd` (Session 11).
2. **Fig 4 = multi-year burden trend (Jonathan, 2026-07-13).** `acs_costs.rds` currently holds B25070/B25091 for **2024 only**. Phase 0b extends `r/acs_costs.R` to pull them across the same vintages as `trend_rent`/`trend_value` (2013/2017/2021/2024) so Fig 4 shows a real burden trend + 2024 town snapshots. The 2024 values must stay green (renter 40.2%, owner 21.5%).
3. **Ch 4 reuses `gaps.rds` — do not recompute affordability math.** F2/F6/F7 read `gaps$afford_by_band` / `gaps$rental_gap` / `gaps$ownership_gap` directly. Do **not** source `r/affordcalc.R` or `r/gaps.R`. Income-needed ($98,000 rent / $190,586 buy), assumptions (6.49% rate, 10% down, 28% front-end, $697/mo tax+ins, 3-person HH), and the gap frames are fixed from Session 6. §7's "CHAS T14/T15" (F6) and "MLS + affordcalc" (F7) name the *underlying* sources already processed into `gaps.rds`.
4. **Ch 5 senior projection = context stat only (Jonathan, 2026-07-13).** Fig 1 shows current-state seniors (B11007 living alone, B25007 tenure by age, CHAS T7 elderly burden). The WC 2050 growth (65+ = 18,208 / 75+ = 9,844) appears only as a **one-line context stat** in a bullet/callout. The full 65+ projection chart is Ch 6 (Session 11).
5. **PIT caveat (Session 7, locked).** `pit$trend` is the **5-county FHN region**, not Fauquier; only 2025 has a county split (Fauquier = **96 of 191 = 50.3%**); Orange & Rappahannock = 0 in 2025. `vdoe$fauquier` is Fauquier-specific (**191 → 135 → 101 → 100 → 92**, 2020-21…2024-25). Report as **counts, never rates**, with volatility caveats.
6. **Reliability / Bealeton floor.** All place-level (Warrenton/Bealeton) ACS cells get `flag_reliability()` on the **0–100 `cv`** column (High ≤15 / Medium ≤30 / Low >30). Suppress Low (→ `NA`), footnote Medium, prefer counts over rates. **Never `hdatools::add_reliability()`.** CHAS town cells carry `moe` (no `cv`) — compute `cv = (moe/1.645)/estimate*100` before flagging, or footnote.
7. **New caption helpers (Phase 0a):** `ami_cap()`, `pit_cap()`, `vdoe_cap()`. `chas_cap()`, `acs_cap()`, `qcew_cap()`, `mls_cap()`, `pmms_cap()` already exist. `cb_pal` (cost-burden palette) already exists in `_common.R` — reuse for F5.

### Out of scope
No prose paragraphs; no figures beyond the §7 list without a §11 note + Jonathan's OK; no changes to `gaps.rds`/`gaps.R`/`affordcalc.R`; no new API pulls **except** the approved `r/acs_costs.R` multi-year burden extension; no `data-notes.qmd` (Session 11) — but log the ACS-vs-CHAS burden reconciliation as a Session-11 data-notes item; no Ch 6 projection figures (household projection, 65+ projection, needs-allocation, production-need) — those are Session 11.

---

## Shell & code conventions

```bash
export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
Rscript r/acs_costs.R          # Phase 0b re-run; never run R inline (CLAUDE.md Windows rule)
quarto render gaps.qmd         # single chapter
quarto render populations.qmd  # single chapter
quarto render                  # full book
```

- Native pipe `|>`; tidyverse style; `.by=` for one-off grouping. **`case_when()`** everywhere (`recode_values()`/`case_match()` unavailable in dplyr 1.2.1 — see gotchas).
- `theme_hda()` + `hda_pal`; horizontal bars use `theme_hda(flip_gridlines = TRUE)`; `add_zero_line("x"/"y")`.
- **Titles = takeaway sentences** (fig-cap and ggplot `title` are identical). Subtitle = geography/units/years. For 2–3 series prefer color-coded bold words in the subtitle (ggtext `<span style='color:#hex'>` matching `hda_pal` hexes: `#445ca9` blue, `#8baeaa` green, `#e9ab3f` yellow, `#e76f52` coral) with `theme(plot.subtitle = element_markdown())` — over legends.
- Currency `scales::label_dollar()`; percent `label_percent(accuracy = 1)`; note nominal vs. real in subtitle.
- Tables: `kbl() |> kable_styling(c("condensed","striped"), full_width = FALSE)`; `footnote(general = <helper>, general_title = "", footnote_as_chunk = TRUE)`.
- **Every figure:** `#| label: fig-*` (tables `tbl-*`), `#| fig-cap:`, `#| fig-alt:` (long, specific — chart type, geographies, value direction/magnitude, suppression notes). Chapter opens with a 1-line purpose comment restating the narrative rule.
- Temp check scripts go in the **scratchpad, not the repo**.

---

## Step 0 — Prerequisite gate

Resolve before writing chapter bodies (temp scripts in scratchpad). **Verified during planning — carried here so the implementer re-confirms after any `r/` re-run:**

**gaps.qmd**
1. **Inputs load:** `gaps`, `chas`, `acs_costs`, `hud_ami`. ✔
2. **`gaps$afford_by_band`** = 5 bands (ami30/50/80/100/120; income, max_rent, max_price). **`gaps$rental_gap`** = 4 bands (≤30 / 30-50 / 50-80 / >80; renter_hh, units_affordable, units_available, surplus_deficit; ≤30% deficit = **−625**). **`gaps$ownership_gap`** = 5 bands (max_price, price_range_low/high, listings_affordable, households, surplus_deficit; listings_affordable = 0/0/1/7/210 → **8 of 218** affordable below 100% AMI). **`gaps$wages_costs`** = 5 rows (All Jobs $68k, Health Care $60,062, Retail $41,934, Local Gov $58,079, 2-worker $136,000; income_needed_rent **$98,000**, income_needed_buy **$190,586**). **`gaps$income_needed` / `gaps$assumptions`** readable. ✔
3. **`chas$t7` / `chas$t8`** carry `household_income` (≤30% / 30-50% / 50-80% / 80-100% / >100% AMI), `cost_burden` (Not / Cost-burdened / Severely; T8 also "No or negative income"), `tenure` (Homeowner/Renter), `geo_code` (51061 / 5183136 / 5105336), `sumlev` (**050** county / **160** place), `moe`. T7 also `household_type` (elderly family / elderly non-family / small / large / other). Confirm CHAS T8 county renter burden = **32.9%**, owner **20.1%**; T7 detail-sum occupied HH ≈ **25,944**. ✔ (T8 renter 32.9% validated.)
4. **`acs_costs$B25070` (renter GRAPI) / `$B25091` (owner SMOCAPI)** present with towns (51061, 5105336, 5183136, 51) and 0–100 `cv`. **After Phase 0b:** confirm the new multi-year burden frame(s) exist (2013/2017/2021/2024) and 2024 burden = renter **40.2%** / owner **21.5%**. Document the burden numerator (sum of 30%+ categories) and denominator (total *with computed ratio* — excludes the "not computed" variable), which is why ACS > CHAS.
5. **`hud_ami$ami`** = 40 rows (5 levels × 8 hh_size); `$mfi` = **166,100**; `$area_name` = "Washington-Arlington-Alexandria…"; `$cap_note` documents the DC-metro 80% cap + 80→100 kink. ✔

**populations.qmd**
6. **Inputs load:** `acs_specialpop`, `pit`, `vdoe`, `wcoop`, `acs_demographics`, `acs_stock`, `chas`. ✔
7. **`acs_specialpop`** has b18101 / b11003 / s1702 / b25007 (all Fauquier+towns+VA, 0–100 `cv`) and a **`vars`** list with label frames. Confirm B25007_001 = **26,720**, B11003_001 = **19,739**, B18101_001 = **74,325**. Verify the `vars` frames are usable for collapsing (B18101 col4=age / col5="With a disability"; B11003 "Other family" male/female-householder = single-parent; B25007 col3=tenure / col4=age). **If a join to `vars` fails, build the label map inline** (S9 precedent). ✔ (vars present.)
8. **`acs_specialpop$s1702` subject-column dimension** — confirm which `S1702_C0x_0yy` column is **count** (C01) vs **percent below poverty** (C02) and which rows are family types. Use **counts (C01-derived)**, not C02 percent, for town cells (Bealeton floor). *Implementer must nail this mapping before F3.*
9. **`acs_demographics$b11007`** (older-householder / living-alone) present. ✔
10. **`acs_stock`** has `b25024`, `b25032`, `b25047`, `b25051`, `b25014` (all with towns) + `vars`. ✔
11. **`chas$t7`** elderly household types present for the elderly-burden panel. ✔
12. **`pit`** frames (trend 2018–2025 region; location_2025 Fauquier=96/191; meta caveats) and **`vdoe$fauquier`** (191→92) present. ✔ **`wcoop$age_county`** carries 65+/75+ 2050 = 18,208 / 9,844 (context stat only). ✔

---

## Phase 0 — Shared infrastructure (do first, Part 1)

### 0a. `_common.R` additions — new caption helpers

Author three helpers in the existing style (bold `**Source:**` prefix, matching `chas_cap()`/`acs_cap()`):

```r
ami_cap  <- function(year = "FY2026") paste0("**Source:** HUD Section 8 Income Limits, ", year,
                                             "; 100/120% AMI derived from published MFI.")
pit_cap  <- function() paste0("**Source:** Foothills Housing Network Point-in-Time Count ",
                              "(5-county FHN region; single-night counts).")
vdoe_cap <- function() paste0("**Source:** VDOE Project HOPE-Virginia, McKinney-Vento ",
                              "homeless student counts.")
```

Then **update `CLAUDE.md` (caption-helper list) and `README.md`** to list the three new helpers.

### 0b. Upstream data edit (approved) + re-run — `r/acs_costs.R`

Extend `r/acs_costs.R` to pull **B25070 and B25091 across 2013/2017/2021/2024** (mirror the `trend_rent`/`trend_value` vintage set) and persist a burden-trend frame (e.g. `burden_trend`, or add a `year` dimension to the existing B25070/B25091 frames), with computed burden share per year × geo × tenure. Re-run:

```bash
export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
Rscript r/acs_costs.R
```

**Validation must stay green:** 2024 renter burden **40.2%**, owner **21.5%**; existing `trend_rent`/`trend_value` untouched; new burden frame non-empty for all four vintages. Requires `CENSUS_API_KEY` (already in `.Renviron`). This is the **only** `r/` re-run this session.

> **Verify at build:** if any pre-2024 vintage is unavailable at place level, footnote the town series as 2024-only and keep the county trend — log in §11.

---

## Phase 1 — gaps.qmd (Ch 4)

Title: `# Affordability Gaps {#sec-gaps}` (keep the stub's `#sec-gaps` id). Purpose comment restating the narrative rule. Build order: setup → F1…F9.

**Setup chunk** (`#| label: setup`, `#| include: false`): `source("_common.R")`; `read_rds()` gaps/chas/acs_costs/hud_ami; palette anchors (`blue/green/yellow/coral` from `hda_pal`; `cb_pal` already global); `geo_label(GEOID, geo_type)`; a **band-label normalizer** (map CHAS's verbose HAMFI phrasings and the T7/T8 "80-100% AMI"/">100% AMI" strings to short ordered-factor labels `≤30% / 30-50% / 50-80% / 80-100% / >100%`); precompute inline scalars for bullets (burden %s, gap deficits, income-needed, wage levels).

> **F1 — AMI limits are set by the high-cost DC metro area (table).** Source `hud_ami$ami` (level, hh_size, income) pivoted wider (rows = band, cols = 1–8-person); annotate `hud_ami$mfi` ($166,100) and the DC-metro 80% cap / 80→100 kink from `$cap_note`. `caption = ami_cap()`. **Reliability:** n/a (published limits). `#| label: tbl-ami`, `#| fig-alt:` describing the table. *Bullets:* MFI $166,100; 80% capped to the US median (kink is expected, not an error); band incomes at the 4-person column.

> **F2 — What each AMI band can afford (table).** Source `gaps$afford_by_band` (band, income, max_rent, max_price); caption note the assumptions from `gaps$assumptions` (6.49% rate, 10% down, 28% front-end, $697/mo tax+ins, 3-person HH). **Reliability:** n/a. `#| label: tbl-afford-band`. *Bullets:* e.g. a 50% AMI household affords ~$1,869 rent / ~$149k purchase; the gap to the $650k median. **Reuse `gaps.rds` — do not recompute.**

> **F3 — Households by AMI band × tenure, county + towns (stacked bars).** Source `chas$t7` (or t8) — sum `estimate` by `household_income` × `tenure`, `sumlev` 050 (county) + 160 (towns). `caption = chas_cap("T7")`. **Reliability:** CHAS has no `cv` — compute from `moe` and footnote town cells; prefer counts. `#| label: fig-hh-band-tenure`, `#| fig-alt:`. *Takeaway:* where lower-income households concentrate by tenure. *Bullets:* renter skew at low bands; town composition; T7 detail-sum ≈ 25,944.

> **F4 — Cost burden, 2013–2024 trend + 2024 town snapshots (ACS).** Source the **new** `acs_costs` multi-year burden frame (B25070 renter / B25091 owner), county trend line + 2024 town points. **This is the ACS side — renter 40.2% / owner 21.5%.** `caption = paste0(acs_cap("B25070"), " ", acs_cap("B25091"))` + a footnote: *"ACS burden excludes ~700 renters with income not computed; CHAS (@fig-burden-band) reports 32.9% — see Data & Methodology."* **Reliability:** town cells CV-flagged (0–100 `cv`), Low suppressed / Medium footnoted. ggtext subtitle color-coding renter vs owner. `#| label: fig-burden-trend`, `#| fig-alt:`. *Takeaway:* trust the data — reframe from "trend" if the pre-2024 series is thin (log in §11). *Bullets:* renter vs owner burden levels; direction over time; town 2024 snapshot.

> **F5 — Core chart: cost burden by AMI band × tenure, county + town small multiples (CHAS T8).** Source `chas$t8` — burden (Cost-burdened + Severely) by `household_income` × `tenure`, county + towns. Stacked bars using **`cb_pal`** (Severely / Cost-burdened / Not). Facet by tenure; town small multiples. **This is the CHAS side — renter 32.9% / owner 20.1%.** `caption = chas_cap("T8")`. **Reliability:** CHAS town cells footnoted (compute cv from moe). `#| label: fig-burden-band`, `#| fig-alt:`. *Takeaway:* burden is overwhelmingly a low-income problem. *Bullets:* severe burden concentrated at ≤30% AMI; renter vs owner by band; town pattern. **The report's core burden chart.**

> **F6 — Rental gap: shortage concentrated at the lowest incomes (diverging bars).** Source **`gaps$rental_gap`** (4 bands; surplus_deficit) — GP Fig 27 analog, county-specific. Diverging surplus/deficit bars by band. `caption = chas_cap("T14B/T15C")` + affordability-calc note. **Reliability:** n/a (county). `#| label: fig-rental-gap`, `#| fig-alt:`. *Takeaway:* ≤30% AMI is the deepest deficit (−625). *Bullets:* −625 at ≤30%; net deficit across bands; the >80% band collapses ami100+ami120. **Do not recompute — §7's "CHAS T14/T15" is the underlying source already in `gaps.rds`.**

> **F7 — Ownership gap: almost no for-sale inventory affordable below 100% AMI (bars).** Source **`gaps$ownership_gap`** (5 bands; listings_affordable vs households) — GP Fig 28 analog. `caption = mls_cap()` + affordability note. **Reliability:** n/a. `#| label: fig-ownership-gap`, `#| fig-alt:`. *Takeaway:* only 8 of 218 active listings affordable below ~100% AMI. *Bullets:* 0/0/1/7 affordable in the four lowest bands; 210 of 218 require ≥120% AMI.

> **F8 — Wages vs. costs: most local jobs don't pay enough to rent, let alone buy (the signature chart).** Source `gaps$wages_costs` (avg_wage, one_earner, two_earner; income_needed_rent $98,000, income_needed_buy $190,586). Lollipop/bar of sector wages (1- and 2-earner) against two reference lines. `caption = qcew_cap()` + affordability-calc note. **Reliability:** n/a. `#| label: fig-wages-costs`, `#| fig-alt:`. *Takeaway:* fact-sheet replication. *Bullets:* All Jobs $68k < $98k rent; only a 2-earner household ($136k) clears the rent bar but not the $190,586 buy bar; Retail $41,934 far below. **Fact-sheet replication — the report's signature chart; carries the §6 wages interview validation.**

> **F9 — Town callouts + interview validation.** (a) `::: {.callout-note}` Warrenton/Bealeton spotlight(s) with burden + gap headline stats (town cells CV-flagged). (b) Chapter closes with `## What the interviews said vs. what the data shows` → `::: {.callout-important}` titled `## Interview validation`: quote the §6 claim **"Workers can't afford to both work and live here"** in bold, an italic verdict (`*Confirmed.*` / `*Confirmed and nuanced.*`), then reconcile with F8's wage-vs-income-needed numbers and `@fig-wages-costs` / `@fig-ownership-gap` cross-refs.

---

## Phase 2 — populations.qmd (Ch 5)

Title: `# Vulnerable Populations {#sec-populations}` (keep `#sec-populations`). Purpose comment + narrative rule. Build order: setup → F1…F6.

**Setup chunk:** `source("_common.R")`; `read_rds()` acs_specialpop/pit/vdoe/wcoop/acs_demographics/acs_stock/chas; palette anchors; `geo_label()`; a **disability/age collapse helper** (join B18101 to `vars`, sum "With a disability" across sex within age bands under-5/5-17/18-34/35-64/65-74/75+); reuse a `structure_cat()`-style collapse for B25024/B25032; precompute inline scalars (senior counts, disability shares, single-parent count, poverty count, PIT 96/191, VDOE 191→92, manufactured-housing counts).

> **F1 — Senior suite (2–3 figures, current-state).** (a) **Seniors living alone** — `acs_demographics$b11007`; (b) **older-householder tenure** — `acs_specialpop$b25007` collapsed to 65+ owner/renter; (c) **elderly cost burden** — `chas$t7` (`household_type` = elderly family + elderly non-family, `cost_burden`). WC 2050 growth (65+ = 18,208 / 75+ = 9,844) as a **one-line context stat only** (bullet or callout), **not a projection chart** (Ch 6). Captions `acs_cap("B11007")`, `acs_cap("B25007")`, `chas_cap("T7")`. **Reliability:** town cells CV-flagged. Labels `fig-senior-alone`, `fig-senior-tenure`, `fig-senior-burden`; each `#| fig-alt:`. *Bullets:* seniors-alone share; owner-heavy senior tenure; elderly burden rate; +growth context line.

> **F2 — Disability by age (B18101) + housing implications.** Source `acs_specialpop$b18101` via the collapse helper (disability count/share by age band). `caption = acs_cap("B18101")`. **Reliability:** county-solid; town cells flagged. `#| label: fig-disability-age`, `#| fig-alt:`. *Takeaway + bullets:* rising disability prevalence with age; the housing-accessibility implication. B18101_001 = 74,325 (denominator check).

> **F3 — Single-parent families + family poverty.** Source `acs_specialpop$b11003` (single-parent = "Other family" male/female householder with own children) + `acs_specialpop$s1702` (family poverty by type — **counts, C01-derived per Step 0 #8**). Validation: B11003_001 = S1702_C01_001 = 19,739. `caption = paste0(acs_cap("B11003"), " ", acs_cap("S1702"))`. **Reliability:** prefer counts (Bealeton floor); flag town cells. Labels `fig-single-parent`, `fig-family-poverty`. *Takeaway + bullets:* single-parent share; elevated poverty among single-parent families.

> **F4 — Homelessness: PIT + VDOE (line/col, counts).** Source `pit$trend` (region 2018–2025), `pit$location_2025` (Fauquier 96/191), `vdoe$fauquier` (191→92). Two panels or two figures. `caption = pit_cap()` / `vdoe_cap()`. **Reliability:** n/a (administrative counts) but **mandatory `::: {.callout-warning}` (or note) caveat**: PIT trend is the **5-county FHN region**, only 2025 has a Fauquier split (96 of 191); VDOE is Fauquier-specific; **counts, never rates**; single-night / small-n volatility. Labels `fig-pit-trend`, `fig-vdoe-mv`; each `#| fig-alt:`. *Takeaway + bullets:* regional PIT direction; Fauquier = ~half the 2025 region count; McKinney-Vento students down 191→92.

> **F5 — Housing quality: incomplete plumbing/kitchen + overcrowding (Habitat hook).** Source `acs_stock$b25047` (plumbing), `b25051` (kitchen), `b25014` (occupants per room / overcrowding). Small counts — **prefer counts, Bealeton floor**. `caption = paste0(acs_cap("B25047"), " ", acs_cap("B25051"), " ", acs_cap("B25014"))`. **Reliability:** town cells flagged, Low suppressed. `#| label: fig-housing-quality`, `#| fig-alt:`. *Takeaway + bullets:* small but real incomplete-facilities / overcrowding counts — the home-repair-program hook.

> **F6 — Manufactured-housing residents (Bealeton spotlight).** Source `acs_stock$b25024` ("Mobile home") / `b25032` (tenure by units) via the structure collapse. `::: {.callout-note}` Bealeton spotlight. `caption = paste0(acs_cap("B25024"), " ", acs_cap("B25032"))`. **Reliability:** town cells CV-flagged (critical — Bealeton). `#| label: fig-manufactured`, `#| fig-alt:`. *Takeaway + bullets:* manufactured-housing share concentrated in Bealeton; tenure split.

> **Chapter close — interview validation.** `## What the interviews said vs. what the data shows` → `::: {.callout-important}` `## Interview validation`: quote the §6 seniors/aging-in-place claim **"Aging-in-place / downsizing seniors and returning young people have no options"** in bold, italic verdict, reconcile with the **current-state** senior metrics from F1 (`@fig-senior-tenure`, `@fig-senior-burden`) — the projection portion is explicitly Ch 6.

---

## Known gotchas (consolidated)

1. **dplyr 1.2.1** — `recode_values()` / `case_match()` unavailable → use `case_when()` everywhere.
2. **Renamed / exact column names** — reference actual frame columns: CHAS uses `household_income`, `cost_burden`, `tenure`, `geo_code` (51061 / 5183136 / 5105336), `sumlev` (050/160), `moe` (no `cv`); ACS frames use `estimate` / `moe` / `cv`. `gaps$rental_gap$surplus_deficit`, `gaps$ownership_gap$listings_affordable`.
3. **CV scale is 0–100** in the `.rds` frames — `flag_reliability()`; **never `hdatools::add_reliability()`** (expects a 0–1 `*_cv` column, mislabels every town cell "Low").
4. **CHAS carries no `cv` column** — only `moe`. To reliability-flag town cells, compute `cv = (moe/1.645)/estimate*100` first, or footnote CHAS town figures. (CHAS is the accepted small-area standard — footnoting is acceptable where a computed CV is noisy.)
5. **CHAS dictionary / band-label quirks** — `household_income` bands are "≤30% AMI / 30-50% AMI / 50-80% AMI / 80-100% AMI / >100% AMI" in T7/T8, but T15/T18 use verbose HAMFI phrasings ("greater than 30% of HAMFI but less than or equal to 50%…"). Normalize to a short ordered factor via an inline map before joining/plotting. `line_type` is all "Detail"; the data dictionary was a separate download (Session 6) — labels already resolved in the `.rds`.
6. **ACS burden = computed share, and ACS > CHAS by construction** — B25070/B25091 burden = Σ(30%+ categories) ÷ total *with computed ratio* (exclude the "not computed" variable). This ~700-renter denominator difference is why ACS renter burden (40.2%) exceeds CHAS T8 (32.9%). Document in F4's footnote; full note deferred to `data-notes.qmd` (Session 11).
7. **`vars` label frames for collapsing** — `acs_specialpop$vars` holds B18101/B11003/B25007/S1702 dictionaries (present). B18101 collapse = sum col5=="With a disability" across sex within age (col4). If a join to `vars` fails at build, build the age/disability map inline (S9 precedent).
8. **S1702 subject-table columns** — resolve at Step 0 which `S1702_C0x` is count (C01) vs percent-below-poverty (C02); use **counts (C01)** for town cells, not the C02 rate.
9. **PIT is region-wide, not Fauquier** — `pit$trend` = 5-county FHN region; only 2025 has a county split (Fauquier 96/191); Orange & Rappahannock = 0. **Counts, not rates**; caveat callout mandatory. VDOE is Fauquier-specific.
10. **`gaps.rds` is precomputed** — F2/F6/F7 read `afford_by_band`/`rental_gap`/`ownership_gap`; do **not** source `affordcalc.R`/`gaps.R` or recompute. §7's "CHAS T14/T15" and "MLS+affordcalc" name the underlying sources already processed.
11. **Band-count mismatch** — `rental_gap` has 4 bands (>80% collapses ami100+ami120); `afford_by_band`/`ownership_gap` have 5. Don't force a 5-band join on the rental side.
12. **`cb_pal` already defined** in `_common.R` (Severely / Cost-burdened / Not) — reuse for F5; don't redefine.
13. **caption-in-`labs()` gridtext `<a>`-tag error** — if a caption/subtitle string contains a raw `<` or a bare URL, ggtext/gridtext parses it as an unterminated `<a>` tag and errors at render. Keep caption-helper output free of raw `<` and URLs (the new helpers use plain text — safe).
14. **ggplot2 4.0 (S7) `strip.text` element-class clash** — the faceted small multiples (F5, F3, F2) can hit an S7 element-class error if a theme passes `strip.text = element_text(...)` built on an older element class. Use `theme_hda()`'s built-in strip styling; if a custom strip is needed, set it via the theme's own idiom rather than a raw `element_text()` override. (Test F5 first — it's the most faceted.)
15. **Freeze / render mechanics** — `freeze: auto` (re-render needs the chunk to change or freeze cleared); `execute-dir: project` so `read_rds("data/…")` is project-root-relative. Render `quarto render gaps.qmd` / `populations.qmd` per chapter, then `quarto render` for the book; refresh `_freeze/` + `docs/`.
16. **Phase 0b `r/acs_costs.R` re-run** must keep 2024 validations green (renter 40.2%, owner 21.5%), leave `trend_rent`/`trend_value` untouched, and produce a non-empty multi-year burden frame; needs `CENSUS_API_KEY` (in `.Renviron`). No other `r/` re-runs this session.

---

## End-of-session hygiene

### PLAN.md §9 checkboxes (tick for both chapters)
```
[ ] Setup chunk (_common.R, read_rds only), figures/tables per §7 with takeaway titles, alt text, captions
[ ] Bullet findings per section (§3 narrative rule); town callout box(es); §6 interview-validation callout
[ ] quarto render <chapter>.qmd clean; spot-check reliability flags on town figures
```

### PLAN.md §11 log entry
Add a dated Session 10 entry (Opus 4.8): scripts/files touched (`r/acs_costs.R` +multi-year burden; three new `_common.R` caption helpers `ami_cap`/`pit_cap`/`vdoe_cap`; two chapters); validation numbers vs GP (ACS renter **40.2%**/owner **21.5%**; CHAS T8 renter **32.9%**/owner **20.1%**; T7 HH ≈ **25,944**; income-needed **$98,000**/**$190,586**; wages All Jobs $68k / Health Care $60,062 / Retail $41,934 / Local Gov $58,079 / 2-worker $136,000; rental deficit **−625** at ≤30%; ownership **8 of 218**; B25007_001 **26,720** / B11003_001 **19,739** / B18101_001 **74,325**; PIT 2025 **96/191**; VDOE **191→92**); **decisions & deviations** (Fig 4 multi-year burden pull [Jonathan 2026-07-13]; Fig 1 senior projection = context-stat only [Jonathan 2026-07-13]; any takeaway direction flips reframed to actual data); reliability spot-check results (town cells span High/Medium/Low); deferrals; **Open questions for Session 11 data-notes** (ACS-vs-CHAS burden-denominator reconciliation). Flip the §11 status-table row for Session 10 to `complete 2026-07-XX | Opus 4.8`.

### Commit
```bash
git add r/acs_costs.R _common.R gaps.qmd populations.qmd CLAUDE.md README.md \
        docs/ _freeze/ PLAN.md plans/session-10-gaps-populations.md
git commit -m "Session 10: gaps & populations chapters"
```
(If splitting: Part 1 commit **"Session 10 (part 1): gaps infra + affordability chapter"** [Phase 0 + `gaps.qmd`]; Part 2 **"Session 10 (part 2): populations chapter + session close"** [`populations.qmd` + close]. No co-author/contributor lines.)

---

## Verification (Definition of Done)

- [ ] `Rscript r/acs_costs.R` re-runs clean; `acs_costs.rds` now has a multi-year burden frame (2013/2017/2021/2024); 2024 validations green (renter 40.2%, owner 21.5%); `trend_rent`/`trend_value` unchanged.
- [ ] Three new caption helpers (`ami_cap`/`pit_cap`/`vdoe_cap`) in `_common.R`; `CLAUDE.md` + `README.md` updated.
- [ ] `quarto render gaps.qmd` clean — F1–F9 present with takeaway titles, `#| fig-alt:`, caption helpers; F2/F6/F7 reuse `gaps.rds` (no recompute); **Fig 4 (ACS 40.2/21.5) and Fig 5 (CHAS 32.9/20.1) both present with the reconciliation footnote**; F8 signature chart closes into the §6 wages interview callout.
- [ ] `quarto render populations.qmd` clean — F1–F6 present; senior WC growth is a context stat only (no projection chart); PIT/VDOE carry the region-vs-Fauquier + counts-not-rates caveat callout; F6 Bealeton spotlight; chapter closes with the §6 seniors interview callout.
- [ ] Both chapters carry ≥1 Warrenton/Bealeton callout; town ACS/CHAS figures show reliability treatment (Low suppressed, Medium footnoted); spot-check confirms tiers span (not uniformly "Low").
- [ ] `quarto render` (full book) clean; both chapters appear in report order between `market-rental` and `projections`.
- [ ] `@sec-gaps` / `@sec-populations` and all `@fig-*` / `@tbl-*` cross-refs resolve; no broken refs.
- [ ] PLAN.md §9 ticked, §11 logged (incl. both Jonathan decisions + any direction flips), committed.
