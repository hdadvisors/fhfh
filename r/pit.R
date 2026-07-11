# pit.R ----
# What:   Foothills Housing Network (FHN) Point-in-Time counts — region trend, 2025 Fauquier location
#         split, and a compact 2025 region demographic profile.
# Source: data/raw/pit/fhn_2025_pit_summary.pdf  (transcribed by hand; the PDF is the source of record)
# Output: data/pit.rds
#   NOTE: FHN region = Culpeper, Fauquier, Madison, Orange, Rappahannock. The historical TREND is
#   REGION-WIDE (not Fauquier-only); ONLY 2025 is broken out by county. Orange & Rappahannock had 0
#   individuals in 2025. Counts only — never rates (small, volatile, single-night counts). A future
#   PIT vintage means re-reading the PDF and editing these tibbles.

## 1. Setup ----
library(tidyverse)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

## 2. Region-wide historical trend, 2018-2025 (all five FHN counties combined) ----
trend <- tribble(
  ~year, ~individuals, ~adults, ~children, ~households,
  2018,  146,          93,       53,        77,
  2019,  162,          91,       71,        89,
  2020,  213,          108,      105,       85,
  2021,  236,          138,      98,        142,
  2022,  280,          221,      63,        174,
  2023,  275,          183,      92,        160,
  2024,  274,          181,      93,        172,
  2025,  191,          135,      56,        128
)

## 3. 2025 location split (the only year broken out by county) ----
# Region totals: 135 adults / 56 children / 191 individuals. Orange & Rappahannock = 0 in 2025.
location_2025 <- tribble(
  ~county,         ~adults, ~children, ~total,
  "Fauquier",      53,      43,        96,
  "Culpeper",      67,      9,         76,
  "Madison",       15,      4,         19,
  "Orange",        0,       0,         0,
  "Rappahannock",  0,       0,         0
)

## 4. Compact 2025 region demographic profile (region-wide, all five counties) ----
# Tidy long: category | subcategory | count | base (denominator N for the "count out of base" framing
# the PDF uses; store counts, not rates). Bases: adults = 135, children = 56, all persons = 191,
# adults who listed a disability = 54.
demographics_2025 <- tribble(
  ~category,                   ~subcategory,                         ~count, ~base,
  # Gender (all persons)
  "Gender (all)",              "Female",                             106,    191,
  "Gender (all)",              "Male",                               83,     191,
  "Gender (all)",              "Don't know / refused",               2,      191,
  # Race & ethnicity — adults
  "Race/ethnicity (adults)",   "Black",                              60,     135,
  "Race/ethnicity (adults)",   "White",                              61,     135,
  "Race/ethnicity (adults)",   "Hispanic",                           2,      135,
  "Race/ethnicity (adults)",   "Multi-racial, Hispanic",             2,      135,
  "Race/ethnicity (adults)",   "Multi-racial, not Hispanic",         5,      135,
  "Race/ethnicity (adults)",   "Native Hawaiian/Pacific Islander",   1,      135,
  "Race/ethnicity (adults)",   "Did not respond",                    4,      135,
  # Race & ethnicity — children
  "Race/ethnicity (children)", "Black",                              26,     56,
  "Race/ethnicity (children)", "White",                              16,     56,
  "Race/ethnicity (children)", "Hispanic",                           3,      56,
  "Race/ethnicity (children)", "Multi-racial, not Hispanic",         6,      56,
  "Race/ethnicity (children)", "Multi-racial, Hispanic",             5,      56,
  # Shelter status (all persons)
  "Shelter (all)",             "Transitional shelter",               61,     191,
  "Shelter (all)",             "Emergency shelter",                  83,     191,
  "Shelter (all)",             "Unsheltered",                        23,     191,
  "Shelter (all)",             "Hotel/motel (not household-paid)",   6,      191,
  "Shelter (all)",             "Observed on street (likely unshelt.)", 18,   191,
  # Age — adults
  "Age (adults)",              "18-24",                              5,      135,
  "Age (adults)",              "25-34",                              24,     135,
  "Age (adults)",              "35-44",                              34,     135,
  "Age (adults)",              "45-54",                              27,     135,
  "Age (adults)",              "55-64",                              27,     135,
  "Age (adults)",              "65+",                                16,     135,
  "Age (adults)",              "Didn't answer",                      2,      135,
  # Age — children (summary bands)
  "Age (children)",            "Under 5",                            16,     56,
  "Age (children)",            "5-17 (school-aged)",                 40,     56,
  # Other
  "Other",                     "Veterans (all unsheltered)",         4,      135,
  "Other",                     "Pregnant / planning to parent",      2,      135,
  # Reason for experiencing homelessness (adults)
  "Reason",                    "Eviction",                           30,     135,
  "Reason",                    "Domestic violence",                  18,     135,
  "Reason",                    "Underemployed",                      13,     135,
  "Reason",                    "Unemployment",                       18,     135,
  "Reason",                    "Disability",                         9,      135,
  "Reason",                    "Dual diagnosis (SUD & SMI)",         2,      135,
  "Reason",                    "Severe mental illness",              5,      135,
  "Reason",                    "Substance use disorder",             1,      135,
  "Reason",                    "Release from incarceration",         3,      135,
  "Reason",                    "Other",                              19,     135,
  "Reason",                    "Doesn't know / refused",             17,     135,
  # Disability (adults; top line out of 135, detail out of the 54 who listed one)
  "Disability",                "Listed a disability",                54,     135,
  "Disability",                "Substantially limits them",          34,     54,
  "Disability",                "Severe mental illness",              25,     54,
  "Disability",                "Substance use disorder",             16,     54,
  "Disability",                "Developmental disability",           8,      54,
  "Disability",                "Physical disability",                24,     54,
  "Disability",                "Other long-term illness",            6,      54
)

## 5. Write output ----
write_rds(
  list(trend = trend,
       location_2025 = location_2025,
       demographics_2025 = demographics_2025,
       meta = list(
         region     = c("Culpeper", "Fauquier", "Madison", "Orange", "Rappahannock"),
         count_date = as.Date("2025-01-22"),
         source     = "Foothills Housing Network 2025 Point-in-Time Count Summary (PDF)",
         caveat     = paste("Historical trend is REGION-WIDE (5 counties), not Fauquier-only; only",
                            "2025 is broken out by county. Orange & Rappahannock = 0 in 2025.",
                            "Single-night counts — report as counts, not rates.")
       )),
  "data/pit.rds"
)
message("Wrote data/pit.rds")

## 6. Validate ----
out <- read_rds("data/pit.rds")
loc <- out$location_2025
message("  Region 2025: 191 individuals (", out$trend$adults[out$trend$year == 2025], " adults + ",
        out$trend$children[out$trend$year == 2025], " children) | Fauquier = ",
        loc$total[loc$county == "Fauquier"], " of 191 (",
        round(100 * loc$total[loc$county == "Fauquier"] / 191, 1), "%)")

stopifnot(
  nrow(out$trend) == 8,
  with(out$trend[out$trend$year == 2025, ], adults + children == individuals),   # 135 + 56 = 191
  loc$total[loc$county == "Fauquier"] == 96,
  sum(loc$adults)   == 135,                                                       # location reconciles
  sum(loc$children) == 56,
  sum(loc$total)    == 191,
  all(with(loc, adults + children == total)),                                     # row-wise consistency
  nrow(out$demographics_2025) > 0
)
message("pit.R validation passed.")
