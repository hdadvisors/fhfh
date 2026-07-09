# acs_costs.R ----
# What:   ACS cost & burden tables — median rents/values, distributions, cost burden
# Tables: B25031, B25063, B25064, B25070, B25071, B25075, B25077, B25091
#         Trend: B25064 (median rent), B25077 (median value) — 2013/2017/2021/2024
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

## 5. Write output ----
write_rds(
  c(pit, list(trend_rent = trend_rent, trend_value = trend_value)),
  "data/acs_costs.rds"
)
message("Wrote data/acs_costs.rds")

## 6. Validate ----
costs <- read_rds("data/acs_costs.rds")

rent_fauquier <- costs$B25064 |>
  filter(GEOID == fauquier, str_detect(variable, "_001"))

value_fauquier <- costs$B25077 |>
  filter(GEOID == fauquier, str_detect(variable, "_001"))

stopifnot(
  length(costs) == length(tables_pit) + 2,
  nrow(trend_rent) > 0,
  nrow(trend_value) > 0,
  between(rent_fauquier$estimate, 1000, 3000),
  between(value_fauquier$estimate, 300000, 900000)
)
message("acs_costs.R validation passed.")
message("  Fauquier 2024 median rent: $", format(rent_fauquier$estimate, big.mark = ","))
message("  Fauquier 2024 median value: $", format(value_fauquier$estimate, big.mark = ","))
