# acs_costs.R ----
# What:   ACS cost & burden tables — median rents/values, distributions, cost burden
# Tables: B25031, B25063, B25064, B25070, B25071, B25075, B25077, B25091
#         Trend: B25064 (median rent), B25077 (median value) — 2013/2017/2021/2024
#         Burden trend: B25070 (renter), B25091 (owner) — 2013/2017/2021/2024
# Source: tidycensus ACS 5-year 2024
# Output: data/acs_costs.rds

## 1. Setup ----
library(tidyverse)
library(tidycensus)

if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- "C:/Users/JTK/Documents/.Renviron"
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}

dir.create("data", showWarnings = FALSE, recursive = TRUE)

fauquier    <- "51061"
towns       <- c(warrenton = "5183136", bealeton = "5105336")
virginia    <- "51"
acs_year    <- 2024
trend_years <- c(2013, 2017, 2021, 2024)

## 2. Helper — pull table for county + towns + state, bind ----
pull_acs_bind <- function(table, year = acs_year) {
  county <- get_acs(
    geography = "county", state = "VA", table = table,
    year = year, survey = "acs5", cache_table = TRUE
  ) |>
    filter(GEOID == fauquier) |>
    mutate(geo_type = "county")

  place <- get_acs(
    geography = "place", state = "VA", table = table,
    year = year, survey = "acs5", cache_table = TRUE
  ) |>
    filter(GEOID %in% unname(towns)) |>
    mutate(geo_type = "place")

  state <- get_acs(
    geography = "state", table = table,
    year = year, survey = "acs5", cache_table = TRUE
  ) |>
    filter(GEOID == virginia) |>
    mutate(geo_type = "state")

  bind_rows(county, place, state) |>
    mutate(
      year = year,
      cv   = if_else(estimate > 0, (moe / 1.645) / estimate * 100, NA_real_)
    )
}

## 3. Point-in-time tables ----
tables_pit <- c(
  "B25031",  # median gross rent by bedrooms
  "B25063",  # gross rent distribution
  "B25064",  # median gross rent
  "B25070",  # renter cost burden (gross rent as % of HH income)
  "B25071",  # median gross rent as % of HH income
  "B25075",  # home value distribution
  "B25077",  # median home value
  "B25091"   # owner cost burden (monthly owner costs as % of HH income)
)

message("Pulling ", length(tables_pit), " point-in-time ACS tables...")
pit <- map(tables_pit, \(tbl) {
  message("  ", tbl, "...")
  pull_acs_bind(tbl)
}) |>
  set_names(tables_pit)

## 4. Trend pulls — median rent + median value ----
message("Pulling trend tables (", paste(trend_years, collapse = "/"), ")...")

trend_rent <- map_dfr(trend_years, \(yr) {
  message("  B25064 ", yr, "...")
  pull_acs_bind("B25064", year = yr)
})

trend_value <- map_dfr(trend_years, \(yr) {
  message("  B25077 ", yr, "...")
  pull_acs_bind("B25077", year = yr)
})

## 4b. Burden trend — renter (B25070) + owner (B25091), same vintages ----
# Burden share = Σ(30%+ categories) ÷ (total with a computed ratio).
# The "not computed" categories are excluded from BOTH numerator and denominator,
# which is why ACS burden exceeds CHAS (CHAS keeps a different universe). See PLAN.md §11.
message("Pulling burden-trend tables (B25070 renter / B25091 owner)...")

# Variable-suffix maps (numeric tail of the ACS variable code).
# B25070 (renter GRAPI): 002-010 = computed ratio categories, 011 = not computed.
#   30%+ burden = 007 (30-34.9) 008 (35-39.9) 009 (40-49.9) 010 (50%+).
# B25091 (owner SMOCAPI): mortgaged 003-011 + non-mortgaged 014-022 = computed;
#   012 / 023 = not computed; 001/002/013 = totals/subtotals.
#   30%+ burden = mortgaged 008-011 + non-mortgaged 019-022.
renter_burden_suffix   <- c(7, 8, 9, 10)
renter_computed_suffix <- 2:10
owner_burden_suffix    <- c(8, 9, 10, 11, 19, 20, 21, 22)
owner_computed_suffix  <- c(3:11, 14:22)

# Derived-proportion CV: MOE(num) from SRSS of category MOEs; MOE(den) likewise.
# MOE(p) via the Census ratio/proportion formula; fall back to ratio form if the
# proportion radicand goes negative. cv = (MOE/1.645)/p * 100 (0-100 scale).
compute_burden <- function(table, tenure, burden_suffix, computed_suffix) {
  map_dfr(trend_years, \(yr) {
    message("  ", table, " ", yr, "...")
    pull_acs_bind(table, year = yr) |>
      mutate(suffix = as.integer(str_sub(variable, -3))) |>
      summarize(
        burdened     = sum(estimate[suffix %in% burden_suffix]),
        moe_burdened = sqrt(sum(moe[suffix %in% burden_suffix]^2)),
        computed     = sum(estimate[suffix %in% computed_suffix]),
        moe_computed = sqrt(sum(moe[suffix %in% computed_suffix]^2)),
        .by = c(GEOID, NAME, geo_type, year)
      ) |>
      mutate(
        tenure = tenure,
        share  = if_else(computed > 0, burdened / computed, NA_real_),
        radicand = moe_burdened^2 - share^2 * moe_computed^2,
        moe_share = if_else(
          radicand >= 0,
          sqrt(radicand) / computed,
          sqrt(moe_burdened^2 + share^2 * moe_computed^2) / computed
        ),
        cv = if_else(share > 0, (moe_share / 1.645) / share * 100, NA_real_)
      ) |>
      select(GEOID, NAME, geo_type, year, tenure,
             burdened, computed, share, moe_share, cv)
  })
}

burden_trend <- bind_rows(
  compute_burden("B25070", "Renter", renter_burden_suffix, renter_computed_suffix),
  compute_burden("B25091", "Owner",  owner_burden_suffix,  owner_computed_suffix)
)

## 5. Write output ----
write_rds(
  c(pit, list(trend_rent = trend_rent, trend_value = trend_value,
              burden_trend = burden_trend)),
  "data/acs_costs.rds"
)
message("Wrote data/acs_costs.rds")

## 6. Validate ----
costs <- read_rds("data/acs_costs.rds")

rent_fauquier <- costs$B25064 |>
  filter(GEOID == fauquier, str_detect(variable, "_001"))

value_fauquier <- costs$B25077 |>
  filter(GEOID == fauquier, str_detect(variable, "_001"))

bt <- costs$burden_trend
renter_2024 <- bt |> filter(GEOID == fauquier, year == 2024, tenure == "Renter") |> pull(share)
owner_2024  <- bt |> filter(GEOID == fauquier, year == 2024, tenure == "Owner")  |> pull(share)

stopifnot(
  length(costs) == length(tables_pit) + 3,
  nrow(trend_rent) > 0,
  nrow(trend_value) > 0,
  between(rent_fauquier$estimate, 1000, 3000),
  between(value_fauquier$estimate, 300000, 900000),
  # Burden trend: non-empty for all four vintages, both tenures
  nrow(bt) > 0,
  setequal(unique(bt$year), trend_years),
  setequal(unique(bt$tenure), c("Renter", "Owner")),
  # 2024 Fauquier burden must match GP headline (renter 40.2% / owner 21.5%)
  abs(renter_2024 - 0.402) < 0.005,
  abs(owner_2024  - 0.215) < 0.005
)
message("acs_costs.R validation passed.")
message("  Fauquier 2024 median rent: $", format(rent_fauquier$estimate, big.mark = ","))
message("  Fauquier 2024 median value: $", format(value_fauquier$estimate, big.mark = ","))
message("  Fauquier 2024 renter burden: ", round(renter_2024 * 100, 1), "%")
message("  Fauquier 2024 owner burden: ",  round(owner_2024 * 100, 1), "%")
