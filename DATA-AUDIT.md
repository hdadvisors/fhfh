# DATA-AUDIT.md — Cross-chapter findings & resolution plan

External peer-review pass over the drafted chapters (`inventory`, `demographics`,
`market-ownership`, `market-rental`, `gaps`, `populations`, `projections`). Stubs
(`exec-sum`, `conclusions`, `data-notes`) were not reviewed for findings but are
referenced where they are the natural home for a fix.

**How to read this:** each finding has (a) the issue and exact location, (b) why it
matters, (c) a concrete resolution path, and (d) — where relevant — the editorial
decision only the author can make. Findings are grouped Contradictions →
Unsupported assertions → Ambiguities, most-consequential first within each group.

**Verification caveat:** many figures render from inline `` `r …` `` code against
`data/*.rds`. Where a value is pinned by a code comment (e.g. `# 2,450`, `# 96`) or
lives in hardcoded prose / `fig-cap` / `fig-alt`, it is treated as verified. Where a
finding depends on an unseen `.rds` value, that is noted. A first resolution step for
almost every numeric finding is to **re-run the relevant `r/` script and confirm the
inline comment still matches the data** before editing prose.

**Verification status (data checks, 2026-07-15):** the eight numeric findings below
were checked directly against `data/*.rds` via `Rscript` (queries in the session
scratchpad). Results are recorded inline as **✔ Verified** blocks. All eight are
**confirmed**; **C4 was re-diagnosed** (the gap is ACS-5-year vs PEP, not a Weldon
Cooper vintage difference), **C6 gained a material caveat** (the capacity figure is a
2010 baseline), and **U3's number checks out** (so it reduces to a "not shown in the
figure" issue). The remaining findings (U1, U2, A1, A3, A5, A6, A7) are
framing/labeling/appendix matters, not numeric — noted per finding.

> Environment note: R on this machine is at `C:\R\R-4.5.3\bin` (with `C:\R\R-4.6.0`
> also installed). The stale `C:\Program Files\R\R-4.5.1` path in `CLAUDE.md` has been
> corrected as part of this session.

---

## ⚠️ Decision required before any prose edits: which rent anchors the affordability math? (finding C1)

**This is the one fork that changes a headline conclusion — settle it first; every
other fix is mechanical or cosmetic once it is decided.**

The gaps chapter (Ch 4) builds its marquee finding — *"most local jobs don't pay enough
to rent"* — on a **$2,450** median rent (verified: the MLS 2025 closed-lease median).
The rental chapter (Ch 3b) treats the market rent as **$1,613** (ACS median gross rent)
/ **$1,604** (CoStar asking). The all-jobs wage is **$68,000**.

- **Keep $2,450** (rent a household moving *today* pays): the "a single average wage
  can't cover the rent" finding stands. Action: in `gaps.qmd`, add one sentence
  justifying the mover's-rent benchmark and **relabel it "median rent for an available
  unit"** (not "median asking rent," which collides with CoStar's $1,604).
- **Switch to $1,613** (what current renters pay): income needed drops to ~$64,520,
  **below the $68,000 wage — the headline flips.** The story becomes "lower-wage sectors
  and one-earner households fall short," not "most jobs can't afford rent." Action:
  soften the gaps conclusion accordingly.

Either way, reconcile the two "asking rent" figures ($1,604 CoStar vs $2,450 MLS) in
Ch 3b and define the term once in the methodology appendix. Full detail and verification
in **C1** below (and **A1**).

---

## Contradictions

### C1. Two different "median rent" figures drive the affordability findings — $1,610 (Ch 3b) vs $2,450 (Ch 4)

**Location**
- `market-rental.qmd` → *What renters pay*: ACS median gross rent `rent_24 ≈ $1,610`
  (2024); CoStar adjusted asking rent `cs_rent_adj ≈ $1,604`, described as sitting "at
  or just above the ACS median."
- `gaps.qmd` → setup line 48 `med_rent <- gaps$income_needed$med_rent # 2,450`; line 85
  `inc_rent <- gaps$income_needed$renter_income # 98,000`; *What each income band can
  afford* ("below the county's median asking rent of $2,450"); *The bottom line* /
  fig-wages-costs ("$98,000 needed to afford the median rent").

**Why it matters** — This is the highest-consequence finding. `$98,000 = $2,450 × 12 ÷
0.30`, so the entire "a single average wage can't cover the rent" conclusion rests on
the $2,450 MLS closed-lease median. Under the ACS median ($1,610) the income needed is
≈ $64,400, which is *below* the ~$68,000 all-jobs wage — the headline flips. The report
never states which "median rent" is authoritative, and the two chapters disagree on
what an asking rent even is ($1,604 CoStar in Ch 3b vs $2,450 MLS in Ch 4).

> **✔ Verified (data check).** `gaps$income_needed$med_rent = 2,450`, which is exactly
> the **MLS 2025 closed-lease median** (`median(mls$rentals[year==2025]$lease_price)`
> = 2,450, n = 203) — a mover's rent, not an asking rent. Ch 3b's benchmarks:
> **ACS median gross rent 2024 = $1,613** (B25064); **CoStar 2026 Q1 adjusted asking =
> $1,604** (nominal $1,589). `renter_income = 98,000 = 2,450 × 12 ÷ 0.30`. All-jobs
> wage confirmed at exactly **$68,000**. Income needed at the ACS median would be
> $1,613 × 12 ÷ 0.30 = **$64,520 — below $68,000**, so the headline "a single wage
> can't afford rent" *does* flip on the rent choice. Load-bearing issue confirmed.

**Resolution**
1. Confirm what `gaps$income_needed$med_rent` actually is — trace it in the `r/` gap
   script. **Confirmed: it is the MLS 2025 closed-lease median (`mls$rentals`), not an
   asking rent.**
2. Decide on **one** rent benchmark for the affordability threshold and use it in both
   chapters, or state plainly that two concepts coexist:
   - ACS median gross rent ($1,610): what *all current renters* pay (includes long-
     tenured below-market leases) — understates what a mover faces.
   - MLS median new lease ($2,450): what a *household moving today* pays — the right
     benchmark for "can a worker who needs housing now afford to rent," but a thinner,
     noisier sample.
3. Whatever is chosen, reconcile the CoStar ($1,604) vs MLS ($2,450) asking-rent gap in
   Ch 3b — right now the rental chapter implies asking rents are ~$1,600 while Ch 4
   uses $2,450.

**Editorial decision required** — *Which rent anchors the affordability math?* If you
keep $2,450, add a sentence in `gaps.qmd` explaining why the mover's rent (not the ACS
stock rent) is the correct threshold, and relabel it "median rent for an available
unit" — not "median asking rent" (which collides with CoStar). If you switch to the ACS
median, the wages-vs-rent finding must be softened: a single average wage *does* cover
the ACS median rent, and the story becomes "lower-wage sectors and one-earner
households fall short," not "most jobs can't afford rent." This choice reshapes the
chapter's marquee conclusion — resolve it before touching prose.

---

### C2. Inventory: "median year built 1987" and "56% built before 1980" cannot both be true

**Location** — `inventory.qmd` → *Age of the housing stock*: "median year built is
1987, and 56% of all homes were built before 1980." Compare `projections.qmd` →
*scope ladder* (`pre1990_share ≈ 56%`, "about 56% built before 1990").

**Why it matters** — If 56% predate 1980, the median must fall before 1980, not 1987.
The owner-stock detail in the same figure (only ~12% of owned homes pre-1960, ~34%
built 2000+) makes "56% before 1980" impossible for an 80%-owner county. Projections'
independent "56% before 1990" *is* consistent with a 1987 median. This is a
self-contradiction inside one bullet and a mismatch with Ch 6.

> **✔ Verified (data check).** From B25034 (all units, county): **pre-1980 = 35.4%**,
> **pre-1990 = 55.9%**; B25035 median = **1987**. The "56%" unambiguously belongs to
> the **1990** cutoff; the true pre-1980 share is 35.4%. Inventory's bullet is a
> cutoff-label error.

**Resolution**
1. Manual check: compute the pre-1980 and pre-1990 shares directly from B25034 (all
   units) and confirm the B25035 median (1987). **Done — see verified block above
   (35.4% / 55.9% / 1987).**
2. Near-certain fix: the inventory bullet should read "**56% built before 1990**"
   (55.9%), matching the 1987 median and the projections figure. Confirm the exact share (projections uses
   B25034; inventory's 56% may have come from the B25036 occupied-unit era bins, a
   slightly different universe — reconcile which table each uses).

**Editorial decision** — Minor: which table (B25034 all units vs B25036 occupied) is
the canonical "age of stock" source, so inventory and projections quote the same
denominator. Otherwise this is a straightforward typo fix pending the data check.

---

### C3. Populations: school homeless count stated to exceed the county PIT tally, but the numbers show the reverse

**Location** — `populations.qmd` → *Homelessness*, fig-vdoe-mv bullets: "Even at
`r vdoe_last`, the school-based count exceeds the county's point-in-time homeless
tally." Code comments: `vdoe_last # 92`, `pit_fauq_2025 # 96`.

**Why it matters** — 92 < 96, so as written the sentence is contradicted by the
chapter's own callout ("Fauquier accounted for 96 of the region's 191"). The
conceptual point (McKinney-Vento's broader definition captures more instability than a
single-night PIT) may still be valid, but the specific numeric comparison is wrong.

> **✔ Verified (data check).** `pit$location_2025`: Fauquier = **96** (53 adults + 43
> children). `vdoe$fauquier` 2024-25 = **92**. `92 > 96` is **FALSE** — the school
> count is *below* the county PIT tally. The claim as written is contradicted. (VDOE
> trend for context: 191 → 135 → 101 → 100 → 92 across 2020-21…2024-25.)

**Resolution**
1. Confirm the two values in `data/vdoe.rds` and `data/pit.rds` (`vdoe_last`,
   `pit_fauq_2025`). **Done — 92 vs 96, confirmed.**
2. If 92 vs 96 holds, rewrite the claim. Options:
   - Compare against the *unsheltered-only* PIT subset if that number is smaller than
     92 and is what you meant — but you'd need that breakout, which the chapter doesn't
     currently carry.
   - Drop the "exceeds" comparison and make the definitional point qualitatively: PIT
     counts one night's literally-homeless; McKinney-Vento counts a full year's
     doubled-up and precariously housed students — different, not additive, and not
     rank-orderable at these small counts.

**Editorial decision** — *Do you want a head-to-head number here at all?* At counts of
92 and 96 the difference is within noise; recommend removing the "exceeds" framing
rather than defending a fragile inequality.

---

### C4. County 2024 population differs between chapters: ~75,900 vs 74,577

**Location** — `demographics.qmd` → *Population growth* ("about 75,900 in 2024," PEP)
vs `projections.qmd` → setup `base_pop # 74,577`, `base_year # 2024` (Weldon Cooper
base for all downstream projections).

**Why it matters** — Two different "2024" county totals (~1,300 apart, ~1.7%). Not
wrong per se — different universes — but projections silently bases every need estimate
on a figure ~1,300 below the population the prior chapter's headline reports for the
same year, with no reconciling note.

> **✔ Verified — and re-diagnosed.** My original hypothesis (a Weldon Cooper vintage
> difference) is **wrong**. The numbers: **PEP POPESTIMATE July-2024 = 75,865**
> (≈ the "~75,900" in demographics' fig-population); **ACS 2020–2024 5-year B01003 =
> 74,577**; `wcoop$assumptions$base_pop = 74,577`. So the projections base is the
> **ACS 5-year estimate**, not a WC-native figure, and the discrepancy is
> **PEP point-in-time (75,865) vs ACS 5-year (74,577)**. Note the demographics chapter
> already contains *both* (its population trend uses PEP; its other ACS figures use
> 74,577), so this is really: projections' base (ACS 74,577) ≠ demographics' headline
> (PEP 75,865), unreconciled.

**Resolution**
1. ~~Confirm the WC vintage~~ **Done — it is not a WC issue.** The choice is PEP
   (point-in-time July 2024) vs ACS 5-year (pooled ~2022 center). ACS 5-year is the
   defensible base for a projection tied to ACS household size (2.78) and CHAS shares —
   so the projections base is arguably the *right* number; it just isn't flagged.
2. Add one sentence to `projections.qmd` (or the methodology appendix): the base
   population is the ACS 2020–2024 5-year estimate (74,577), which runs modestly below
   the PEP July-2024 estimate (75,865) featured in Ch 2, because the two are different
   measures.

**Editorial decision** — *Keep the ACS 5-year base and disclose, or re-anchor the
population narrative on one series throughout?* Recommend keeping the ACS base for
projections (it's internally consistent with the household-size and CHAS inputs) and
adding the one-line reconciliation. Optionally, standardize which series each chapter
leads with. Low stakes for conclusions; matters for reader trust.

---

### C5. Bealeton population: "~6,000" vs "~5,000"

**Location** — `inventory.qmd` → *Study area* ("Bealeton CDP (~6,000)") vs
`demographics.qmd` → *Population growth* ("Bealeton to ~5,000 by 2024"; fig-alt "about
4,400 to 5,000").

**Why it matters** — A ~20% gap in a stated town population, in the first descriptive
bullet a reader hits. Inventory's round "~6,000" isn't tied to the ACS figure
demographics uses.

> **✔ Verified (data check).** ACS B01003 Bealeton CDP 2024 = **5,034** (CV 9.3% —
> High reliability). Demographics' "~5,000" is correct; inventory's "~6,000" is the
> outlier.

**Resolution**
1. Pull the current ACS 2020–2024 population for Bealeton CDP (B01003) from
   `data/acs_demographics.rds` and use it in both places. **Done — 5,034.**
2. Fix inventory's "~6,000" to "**~5,000**."

**Editorial decision** — None beyond confirming the source figure; align inventory to
demographics.

---

### C6. Full-scope need (12,457 units) exceeds stated buildable capacity (~8,381 units), unreconciled

**Location** — `projections.qmd` → *scope ladder* (`lad_c4 = 12,457` full-scope total
by 2050) vs `inventory.qmd` → *Interview validation* ("developable capacity is a finite
~8,381 units inside the service districts").

**Why it matters** — The full-scope need is ~50% above the developable ceiling the
report asserts elsewhere; even the ~7,000-unit headline is close to it. Neither chapter
connects them, so a reader is left to notice that the county may not physically hold
what Ch 6 says it needs.

> **✔ Verified — with a material caveat.** `easements` (`service_district_buildout`,
> sourced to Comp Plan / GP study Ch 3b p. 11): total capacity **19,776 units**, units
> built **as of 2010 = 11,395**, unbuilt capacity **= 8,381**. **The 8,381 is a 2010
> baseline.** At the ~266 units/yr permit pace since 2010 (~15 yrs ≈ 4,000 units), the
> *remaining* by-right capacity today is plausibly nearer ~4,000–4,500 — which makes the
> tension with the projections need (headline ~7,000; full-scope 12,457) **sharper, not
> softer.** The same record also carries a Weldon Cooper **2045** projection of 88,330,
> while Ch 6 uses a WC **2050** figure of 93,171 — different projection vintages, worth
> a footnote.

**Resolution**
1. Confirm the ~8,381 figure and its definition (`data/easements.rds`,
   `units_unbuilt_capacity`). **Done — it is by-right service-district build-out
   capacity as of a 2010 baseline (Comp Plan Ch 3b p. 11), not a current figure.** It
   can be expanded through rezoning, service-district boundary changes, or density
   increases (a *policy* lever, not a hard wall) — but as a starting point it should be
   updated to net out post-2010 construction, which likely tightens it further.
2. Add a bridging paragraph — most naturally in `projections.qmd` (scope ladder or town
   spotlight) or `conclusions.qmd` — that puts the need against the capacity and states
   the implication (e.g., meeting full-scope need requires either expanding service-
   district capacity or accepting that some need goes unmet / spills to the rural
   county).

**Editorial decision** — *Is this a finding you want to surface as a headline policy
implication (need > by-right capacity → rezoning/expansion required) or footnote as a
caveat?* This is arguably one of the strongest policy hooks in the whole report and
worth elevating rather than leaving implicit. Recommend making it explicit in
`conclusions.qmd`.

---

## Unsupported Assertions

### U1. "Few purpose-built senior rentals" attributed to Ch 3b, which has no senior-specific analysis

**Location** — `populations.qmd` → *Older adults* ("little purpose-built senior rental
stock (@sec-market-rental)") and *Interview validation* ("few small or purpose-built
senior rentals (@sec-market-rental)").

**Why it matters** — Ch 3b documents a small *general* apartment market; it never
breaks out senior/age-restricted stock. The cross-reference supports "small apartment
market," not "few senior rentals."

> **✔ Checked (data check).** The NHPD program mix contains **no cleanly
> senior-designated (Section 202) program**. Distinct `program_name` values: 4% Tax
> Credit, 9% Tax Credit, 515 Rural Housing, HFDA/8 NC, HOME, and **PRAC/811** (Project
> Rental Assistance serving elderly *or* disabled — not senior-specific). So the
> assisted inventory offers no clean data anchor for "few purpose-built *senior*
> rentals," which **reinforces** the finding: soften the claim. Separately, Ch 3b's
> prose lists "Section 202" among the program types — that appears **imprecise** against
> the NHPD record (it's PRAC/811, not 202) and is worth a second look.

**Resolution**
1. Check whether any source can substantiate the senior-specific claim — NHPD programs,
   CoStar property subtypes, or a known local inventory of age-restricted communities.
   **Done for NHPD: no Section 202; only PRAC/811 (elderly-or-disabled).**
2. Recommended: **soften** to what the data supports — "the county's small apartment
   market offers little dedicated senior product" as a reasonable inference — and drop
   the implication that Ch 3b quantifies senior stock. If FHFH has local knowledge of
   age-restricted communities, cite that directly instead.

**Editorial decision** — *Do you have local knowledge of age-restricted stock to cite?*
Absent that, soften the claim; the assisted inventory does not carry a senior-specific
category. Also decide whether to correct Ch 3b's "Section 202" reference.

---

### U2. Causal claim about young-adult out-migration

**Location** — `demographics.qmd` → *Age structure*: "young adults leave (or never
arrive) for lack of entry-level housing and jobs."

**Why it matters** — The B01001 figure shows the thin 18–34 band (the outcome), not the
cause. The attribution is plausible and consistent with the rest of the report, but
stated as fact rather than inference.

**Resolution** — No new data strictly required; this is a framing fix. Either (a)
mark it as inference ("consistent with … the county's thin entry-level supply
(@sec-market-ownership) and slower job growth (@fig-employment)"), cross-referencing the
chapters that *do* show those constraints, or (b) if you want it evidenced, migration-
by-age data (ACS B07001 or IRS county migration flows) could show net out-migration of
young adults directly.

**Editorial decision** — *Assert as evidenced causation, or present as cross-
referenced inference?* Recommend inference with cross-refs — cheap, honest, and the
supporting chapters already exist.

---

### U3. Wage-growth claim not visible in the cited figure

**Location** — `demographics.qmd` → *Employment*, fig-wages bullet: "all four counties
saw all-jobs pay rise ~42–48% since 2015."

**Why it matters** — The figure shows 2025 pay *levels* by industry, not a 2015→2025
growth series, so a reader can't verify the growth stat against the chart it sits under.

> **✔ Verified — the number is correct.** QCEW all-jobs avg annual pay, 2015→2025:
> Fauquier **+47.6%** ($46,076→$68,000), Culpeper +45.8%, Prince William +46.7%,
> Loudoun +42.1%. Range **42.1–47.6%**, matching the "~42–48%" claim. This is therefore
> **not a data error** — it reduces to a presentation issue: the figure it accompanies
> shows levels, not growth. (Also confirms Fauquier's all-jobs 2025 pay = exactly
> $68,000, the wage used in the gaps chapter.)

**Resolution**
1. Confirm the 42–48% range from QCEW (`data/qcew.rds`). **Done — 42.1–47.6%, accurate.**
2. Either add a small growth-index panel / inset so the claim is visible, or reword to
   flag it as a supplementary computation ("QCEW shows all-jobs pay rose ~42–48% across
   these counties since 2015 — not shown") so it isn't read as a chart takeaway.

**Editorial decision** — Minor: worth a visual, or acceptable as a stated aside? Given
the "level, not trajectory" point is central to the wage narrative, a small growth
inset would strengthen it.

---

## Ambiguities

### A1. "The median rent" is never defined report-wide

**Location** — cross-cutting; see C1. Ch 3b uses $1,610 (ACS) and ~$1,604 (CoStar);
Ch 4 uses $2,450 (MLS) and labels it "median asking rent."

**Resolution** — Resolved as part of C1: pick one anchor, define the term once
(methodology appendix), and use consistent labels ("median gross rent," "median new-
lease rent," "professional asking rent") rather than an unqualified "median rent."

**Editorial decision** — Folded into C1.

---

### A2. fig-commute-out mixes an inflow statistic into an outflow narrative

**Location** — `demographics.qmd` → *Commuting* and *Interview validation*: "Only 35.4%
of the jobs located in Fauquier are held by county residents — the majority of working
residents leave the county each day." The figure's subtitle is about *outflow* ("Top
destinations for employed Fauquier residents working outside the county").

**Why it matters** — "35.4% of local jobs held by residents" is an *inflow* measure
(who fills Fauquier's jobs); "majority of residents leave" is *outflow* (where residents
work). Different denominators; the em-dash implies one demonstrates the other.

> **✔ Verified — and the correct number is stronger.** `lodes$live_work`:
> residency_share = **0.354** (8,266 of 23,349 jobs *located in* Fauquier held by
> residents — the **inflow** measure). True **outflow** (`od_county`, h_geocode =
> Fauquier): of **35,028** employed residents, only **8,266 (23.6%)** work in-county, so
> **76.4% commute out.** The bedroom-community claim is not merely true — the 35.4%
> figure *understates* it. Fix: cite **76.4% outflow** for "most residents leave," and
> keep 35.4% only as a separate, correctly-labeled point about who fills local jobs.

**Resolution**
1. From LODES (`data/lodes.rds`), pull the genuinely *outflow* statistic — the share of
   *employed Fauquier residents* who work outside the county. **Done — 76.4%** (26,762
   of 35,028). Use it to support "most residents commute out."
2. Keep the 35.4% inflow stat if you want it, but label it correctly ("only 35.4% of
   jobs located in the county are filled by residents") as a *separate* point about the
   local job base, not as evidence of out-commuting.

**Editorial decision** — *Which claim is the bedroom-community headline — that most
residents leave (outflow) or that most local jobs are filled by outsiders (inflow)?*
Both are true and both support "bedroom community," but they're different sentences.
Recommend leading with the outflow share (directly on-point) and citing 35.4% as a
corroborating second fact.

---

### A3. "Senior" (65+) and "elderly" (62+) used interchangeably

**Location** — `populations.qmd`: most figures define seniors as 65+ (B11007, B25007,
B18101), but fig-senior-burden's caption reads "Elderly = households with a member age
62 or older" (CHAS), while its bullet calls them "senior renters."

**Why it matters** — The 41%/26% senior cost-burden figures rest on a 62+ universe
folded under the "senior" label used elsewhere for 65+.

**Resolution** — Editorial/labeling only; no data change. Either (a) add a half-sentence
where the burden figure is discussed noting CHAS defines elderly as 62+ (slightly
broader than the 65+ used elsewhere), or (b) if CHAS offers a 65+ cut, use it for
consistency.

**Editorial decision** — *Standardize on one age threshold, or disclose the two?* CHAS's
elderly bracket is fixed at 62+, so recommend disclosing rather than forcing — just make
the one-time note explicit so "senior" isn't silently two ages.

---

### A4. Two different "2024" county populations presented to the reader

**Location** — cross-ref C4 (75,900 vs 74,577).

**Resolution / decision** — Folded into C4; the ambiguity is resolved by the same
disclosure sentence.

---

### A5. 5-year ACS estimates labeled by a single year

**Location** — throughout `demographics.qmd`, `gaps.qmd`, `market-rental.qmd`: "2020–
2024 ACS 5-year" data captioned simply "2024" (e.g., fig-age "…Virginia, 2024,"
fig-income "2024," household composition "2024").

**Why it matters** — Standard practice, but single-year labels can lead a reader to
treat 5-year pooled estimates as point-in-time 2024 values.

**Resolution** — Handle once in the (currently stubbed) `data-notes.qmd`: state that all
ACS figures labeled by a single year are 2020–2024 5-year estimates referenced by their
end year. No per-figure change needed if the appendix is explicit and cross-referenced.

**Editorial decision** — None; this is an appendix task. Flagging because the appendix
doesn't exist yet and several chapters defer reconciliations to it.

---

### A6. "Lower-income town core" implies both towns

**Location** — `demographics.qmd` → *Household income*: "High county-wide income
coexists with a lower-income town core."

**Why it matters** — Only Warrenton ($83k) is low-income; Bealeton ($108k) is above the
state median. "Town core" reads as both towns.

**Resolution** — Wording fix: name Warrenton specifically ("a lower-income Warrenton
core," or "lower-income in Warrenton, while Bealeton tracks the county"). No data
change.

**Editorial decision** — None; straightforward edit.

---

### A7. Warrenton called "the county's principal water-and-sewer service area"

**Location** — `projections.qmd` → *Town spotlight*: "As the county's principal water-
and-sewer service area, Warrenton is where much of the projected household growth can
physically be absorbed." Compare `inventory.qmd`, which establishes **eight** designated
service districts.

**Why it matters** — "Principal" overstates Warrenton's singular role against the
eight-district framing; a reader may take it as the only serviced area.

**Resolution**
1. Confirm from the Comprehensive Plan whether Warrenton is in fact the largest
   serviced growth area (it may well be, as the county seat with its own utilities).
2. Reword to "one of the county's eight service districts — and its largest / the county
   seat" if that's accurate, or soften "principal" to "a major."

**Editorial decision** — *Is Warrenton demonstrably the largest-capacity service
district?* If yes, keep "principal" but acknowledge the eight-district context; if
unknown, soften. Low stakes.

---

## Cross-cutting note: the missing Data & Methodology appendix

Findings C1/A1 (rent definition), C4/A4 (population base), A3 (senior vs elderly), A5
(5-year labeling), and the CHAS-vs-ACS burden reconciliation the chapters explicitly
defer all point to `data-notes.qmd`, which is currently a stub. Several chapters promise
reconciliations "in the Data & Methodology appendix" that a reader cannot yet check.
Building that appendix (Session 11 per PLAN.md) will discharge a meaningful share of the
ambiguities above and should be treated as a dependency for closing them, not a separate
task.

## Suggested sequence

1. ~~**Data checks first**~~ **✅ Done (2026-07-15).** All eight numeric findings
   confirmed against the `.rds` files: C1 ($2,450 = MLS lease median; ACS $1,613 /
   CoStar $1,604), C2 (35.4% pre-1980, 55.9% pre-1990, median 1987), C3 (92 < 96),
   C4 (PEP 75,865 vs ACS 74,577 — re-diagnosed), C5 (Bealeton 5,034), C6 (8,381 is a
   2010 baseline — tension is worse), U3 (42.1–47.6%, accurate), A2 (true outflow
   76.4%), plus U1 (NHPD has no Section 202). Now edit prose against these numbers.
2. **The one real editorial fork:** C1/A1 — choose the rent anchor. This gates the gaps
   chapter's headline and should be decided before prose edits.
3. **Straight fixes (numbers now in hand):** C2 (→ "before 1990"), C3 (drop/reword the
   "exceeds" claim), C5 (→ "~5,000"), A2 (→ 76.4% outflow), U3 (label as not-shown or
   add inset). Mechanical once C1 is settled.
4. **Framing/disclosure edits:** C4 (disclose ACS-vs-PEP base), C6 (elevate; also update
   the 2010-baseline capacity), U1 (soften; fix Ch 3b "Section 202"), U2 (inference),
   A3/A6/A7 (labeling).
5. **Appendix:** build `data-notes.qmd` to absorb A5 and the deferred reconciliations.
