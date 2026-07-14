# Session 11a — Projected Housing Needs (`projections.qmd`; §7 Ch 6 / rendered Chapter 7)

> First of two execution sessions split from PLAN.md §9 Session 11. Companion:
> `session-11b-conclusions-datanotes.md`. Run this one first — S11b depends on its locked numbers.
>
> **Chapter-number crosswalk.** PLAN.md §7 uses conceptual numbering where the ownership/rental split
> shares "Ch 3a/3b". The rendered book auto-numbers each `.qmd` (index + the exec-sum stub are
> unnumbered), so displayed numbers run higher: gaps = Ch 4/rendered 5, populations = Ch 5/rendered 6,
> **projections = Ch 6/rendered 7**, conclusions = Ch 7/rendered 8, data-notes = Appendix A. Deliverables
> are named by filename below; a "Ch N" label is PLAN.md's conceptual number. The `.qmd` files never
> hardcode a number (Quarto numbers from `{#sec-}` headers) — no numbering edit needed in any file.

## Context

Session 11 is the last chapter-build session (Session 12 = assembly/QA). `projections.qmd` is the
analytically heaviest chapter in the book — population→household→production model, 65+ demand, and a
tenure×AMI needs-allocation table — so it is isolated in its own session and not rushed alongside the
close-out prose deliverables (conclusions + appendix, which run in S11b afterward).

## Kickoff

Build `projections.qmd` (PLAN.md §7 "Ch 6"; renders as **Chapter 7** in the book — populations is
Chapter 6). Read CLAUDE.md + PLAN.md §7 (Ch 6 list), §8 (projection/allocation methodology), §3
(narrative + chart rules), and the §11 Session 7 + Session 10 log entries (they carry the decisions
this chapter executes). Structural template: `gaps.qmd` (setup chunk → `read_rds()` only → inline
scalars → alternating figure/bullet blocks → town/interview callouts). **Data-flow rule: `read_rds()`
only — no API calls, no `r/` re-runs unless a Phase-0 note says so and Jonathan approves.**

## Prereq `.rds` (all present)

- `data/wcoop.rds` — every Ch 6 figure's source. Frames: `pop_county` (Fauquier+VA, 2030/40/50),
  `pop_town` (Warrenton only — Bealeton is a CDP, absent), `age_county` (5-yr bands + per-year
  `senior_65plus`/`senior_75plus`), `households` (both methods: `growth_avgsize` **+6,795** /
  `growth_headship` +6,662), `production` (`units_per_year_avgsize` ~269 vs `bps_2020_25_avg` **266**),
  `needs_allocation` (tenure×AMI forward need, gap-joined), `assumptions`.
- `data/gaps.rds`, `data/chas.rds`, `data/bps.rds` — for cross-references only; the gap direction and
  permit pace are already baked into `needs_allocation` and `production`.

## §7 figures/tables to build (5)

1. **`fig-pop-projection`** — WC county population 2030/40/50 columns (`pop_county`), Fauquier→93,171
   by 2050; Warrenton town as a small secondary panel/annotation from `pop_town`.
2. **`fig-hh-projection`** — household projection to 2050 (`households`). **Headline = avg-size method
   (+6,795), already decided by Jonathan 2026-07-10;** show headship (+6,662) as a light
   alternate/sensitivity, not the lead. Frame the "+X households by 2050" takeaway.
3. **`fig-production-need`** — annual production need vs actual pace (`production`): ~269 units/yr
   (avg-size) against the 2020–25 BPS average of 266/yr. **Direction differs from GP** — the honest
   story is "recent production roughly keeps pace with projected need," not GP's "need exceeds pace."
   Lead the takeaway with the actual finding; note GP's 307/yr and the avg-HH-size divergence (2.78 vs
   GP's implied ~2.70) in a bullet + defer full reconciliation to the appendix.
4. **`fig-senior-projection`** — 65+ (and 75+) population projection from `age_county` senior detail
   (65+ → 18,208, 75+ → 9,844 by 2050). This is the chapter that *owns* the 65+ chart; Ch 5
   deliberately cited these as context stats pointing here.
5. **`tbl-needs-allocation`** — tenure×AMI forward-need table (`needs_allocation`, pre-built, sums to
   +6,795). Columns: tenure, AMI band, current HH, share, forward need, existing surplus/deficit,
   gap source. Document the tenure-aware join (Homeowner→ownership_gap, Renter→rental_gap; renter
   ami100+ami120 collapse to ">80% AMI") in the caption + appendix. `kbl()` per §3.

## Phase 0 (shared infra, likely one small item)

- Add caption helper **`wc_cap()`** to `_common.R` (Weldon Cooper source line) — deferred from
  Session 7 explicitly ("`wc_cap`/`pit_cap`/`vdoe_cap` deferred to Sessions 10–11"; `pit_cap`/`vdoe_cap`
  were added in S10, `wc_cap` remains). Update the CLAUDE.md + README helper lists in the same session.
- No API pull or `r/` re-run expected — all frames exist. If one is needed, log it + get Jonathan's OK.

## Per-chapter §9 checklist

- [x] Setup chunk (`_common.R` + `read_rds()` only), 5 §7 figures/tables with takeaway titles, alt
      text, `wc_cap()` captions.
- [x] 2–5 bullet findings per section (§3 rule); at least one town callout (Warrenton — Bealeton
      absent from WC, note why); §6 interview-validation callout (seniors/young-returners claim —
      Ch 5 confirmed the current state, Ch 6 quantifies the forward pressure).
- [x] `quarto render projections.qmd` clean; full-book render clean; `@sec-projections` + internal
      `@fig-*`/`@tbl-*` resolve; spot-check no `?@`.
- [x] `_freeze/projections` + `docs/` rebuilt.

## Definition of done

`projections.qmd` renders in the book (as Chapter 7) with all 5 §7 items present (or §11-logged as
deferred with Jonathan's OK); household headline = avg-size, GP divergence noted; §11 log entry added;
`wc_cap()` documented. **Do not** write prose paragraphs or add figures beyond §7 without a §11 note.

## Carry-forward to S11b

Every "GP reconciliation / method divergence" note surfaced here feeds the appendix — list them at
session close so S11b's data-notes is complete.

## Scope risks & honest flags (S11a)

1. **The household-method "decision" is already made** (avg-size headline, Jonathan 2026-07-10), so
   this session executes rather than decides — but the GP divergence is a *finding to frame well*, not
   a bug to hide. The takeaway must lead with the actual "production keeps pace" story, not GP's
   inverted one.
2. **`fig-hh-projection` shows two methods on one canvas** — risk of a cluttered chart. Lead with
   avg-size; render headship as a faint reference line/annotation, not a co-equal series.
3. **`tbl-needs-allocation` band-scale mismatch is real** — renter ami100+ami120 collapse into ">80%
   AMI" because the rental and ownership gap frames use different band scales. This is baked into
   `needs_allocation` already; the risk is *explaining* it clearly in caption + appendix, not computing it.
