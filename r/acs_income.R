# acs_income.R ----
# What:   ACS 5-year income and poverty tables
# Tables: B19013 (median HH income, 2010–2024 trend), B19001 (income distribution),
#         S1701 (poverty status)
# Source: tidycensus ACS 5-year
# Output: data/acs_income.rds

## 1. Setup ----
library(tidyverse)
library(tidycensus)
library(janitor)

if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- "C:/Users/JTK/Documents/.Renviron"
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}

dir.create("data", showWarnings = FALSE, recursive = TRUE)

fauquier   <- "51061"
towns      <- c(warrenton = "5183136", bealeton = "5105336")
benchmarks <- c(culpeper = "51047", prince_william = "51153", loudoun = "51107")

## 2. B19013 – Median HH income trend 2010–2024 ----
# Fauquier + 3 benchmark counties + towns + VA (chapter distinguishes county vs peers by GEOID).
message("Pulling B19013 trend 2010-2024 (may take a few minutes first run)...")
b19013_trend <- map_dfr(2010:2024, \(yr)
  bind_rows(
    get_acs(geography = "county", state = "VA", table = "B19013",
            year = yr, survey = "acs5", cache_table = TRUE) |>
      filter(GEOID %in% c(fauquier, unname(benchmarks))) |>
      mutate(geo_type = "county"),
    get_acs(geography = "place", state = "VA", table = "B19013",
            year = yr, survey = "acs5", cache_table = TRUE) |>
      filter(GEOID %in% unname(towns)) |>
      mutate(geo_type = "place"),
    get_acs(geography = "state", state = "VA", table = "B19013",
            year = yr, survey = "acs5", cache_table = TRUE) |>
      mutate(geo_type = "state")
  ) |>
  mutate(year = yr)
) |>
  mutate(cv = if_else(estimate > 0, (moe / 1.645) / estimate * 100, NA_real_))
message("B19013 trend pulled: ", nrow(b19013_trend), " rows (",
        n_distinct(b19013_trend$year), " years × ",
        n_distinct(b19013_trend$GEOID), " geographies)")

## 3. B19001 – HH income distribution (2024), aggregated to 6 bands ----
# _001=Total, _002=<$10k, _003=$10-15k, _004=$15-20k, _005=$20-25k,
# _006=$25-30k, _007=$30-35k, _008=$35-40k, _009=$40-45k, _010=$45-50k,
# _011=$50-60k, _012=$60-75k, _013=$75-100k, _014=$100-125k, _015=$125-150k,
# _016=$150-200k, _017=$200k+
message("Pulling B19001...")
b19001_raw <- bind_rows(
  get_acs(geography = "county", state = "VA", table = "B19001",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID == fauquier) |>
    mutate(geo_type = "county"),
  get_acs(geography = "place", state = "VA", table = "B19001",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID %in% unname(towns)) |>
    mutate(geo_type = "place"),
  get_acs(geography = "state", state = "VA", table = "B19001",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    mutate(geo_type = "state")
)

b19001 <- b19001_raw |>
  mutate(
    var_num  = as.integer(str_extract(variable, "\\d+$")),
    inc_band = case_match(
      var_num,
      c(2L, 3L, 4L, 5L)      ~ "< $25k",
      c(6L, 7L, 8L, 9L, 10L) ~ "$25-50k",
      c(11L, 12L)             ~ "$50-75k",
      13L                     ~ "$75-100k",
      c(14L, 15L)             ~ "$100-150k",
      c(16L, 17L)             ~ "$150k+",
      .default = NA_character_
    )
  ) |>
  filter(!is.na(inc_band)) |>
  summarize(
    estimate = sum(estimate, na.rm = TRUE),
    moe      = sqrt(sum(moe^2, na.rm = TRUE)),
    .by = c(GEOID, NAME, geo_type, inc_band)
  ) |>
  mutate(
    year = 2024L,
    cv   = if_else(estimate > 0, (moe / 1.645) / estimate * 100, NA_real_)
  )
message("B19001 banded: ", nrow(b19001), " rows (6 bands × ", n_distinct(b19001$GEOID), " geographies)")

## 4. S1701 – Poverty status (2024 only) ----
message("Pulling S1701...")
s1701 <- bind_rows(
  get_acs(geography = "county", state = "VA", table = "S1701",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID == fauquier) |>
    mutate(geo_type = "county"),
  get_acs(geography = "place", state = "VA", table = "S1701",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID %in% unname(towns)) |>
    mutate(geo_type = "place"),
  get_acs(geography = "state", state = "VA", table = "S1701",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    mutate(geo_type = "state")
) |>
  mutate(
    year = 2024L,
    cv   = if_else(estimate > 0, (moe / 1.645) / estimate * 100, NA_real_)
  )
message("S1701 pulled: ", nrow(s1701), " rows")

## 5. Write output ----
write_rds(
  list(b19013_trend = b19013_trend, b19001 = b19001, s1701 = s1701),
  "data/acs_income.rds"
)
message("Wrote data/acs_income.rds")

## 6. Validate ----
inc <- read_rds("data/acs_income.rds")

inc_2024 <- inc$b19013_trend |>
  filter(GEOID == fauquier, year == 2024) |>
  pull(estimate)
stopifnot(between(inc_2024, 115000, 145000))   # GP benchmark: ~$130,189

# All four counties (Fauquier + 3 benchmarks) present across the trend
county_geoids <- inc$b19013_trend |> filter(geo_type == "county") |> distinct(GEOID) |> pull()
stopifnot(all(c(fauquier, unname(benchmarks)) %in% county_geoids))

message("acs_income.R validation passed.")
message("  Fauquier 2024 median HH income: $", format(inc_2024, big.mark = ","))
message("  Benchmark counties present: ", paste(sort(county_geoids), collapse = ", "))
