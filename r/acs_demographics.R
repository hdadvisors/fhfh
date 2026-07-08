# acs_demographics.R ----
# What:   ACS 5-year demographic tables for Fauquier County, towns, benchmarks, and VA
# Tables: B01003 (total pop), B01001 (age/sex → 5 bands), B03002 (race/ethnicity),
#         B11001 (household type), B11007 (seniors living alone), B25010 (avg HH size)
# Source: tidycensus ACS 5-year 2024
# Output: data/acs_demographics.rds

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

## 2. B01003 – Total population ----
# Benchmarks included at county level for comparison
message("Pulling B01003...")
b01003 <- bind_rows(
  get_acs(geography = "county", state = "VA", table = "B01003",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID %in% c(fauquier, unname(benchmarks))) |>
    mutate(geo_type = "county"),
  get_acs(geography = "place", state = "VA", table = "B01003",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID %in% unname(towns)) |>
    mutate(geo_type = "place"),
  get_acs(geography = "state", state = "VA", table = "B01003",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    mutate(geo_type = "state")
) |>
  mutate(
    year = 2024L,
    cv   = if_else(estimate > 0, (moe / 1.645) / estimate * 100, NA_real_)
  )
message("B01003 pulled: ", nrow(b01003), " rows")

## 3. B01001 – Sex by age, collapsed to 5 bands ----
# Fauquier county + towns + VA only (benchmarks not needed for age structure)
# Under 18: male 003-006, female 027-030
# 18-34:    male 007-011, female 031-035
# 35-64:    male 012-019, female 036-043
# 65-74:    male 020-022, female 044-046
# 75+:      male 023-025, female 047-049
message("Pulling B01001...")
b01001_raw <- bind_rows(
  get_acs(geography = "county", state = "VA", table = "B01001",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID == fauquier) |>
    mutate(geo_type = "county"),
  get_acs(geography = "place", state = "VA", table = "B01001",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID %in% unname(towns)) |>
    mutate(geo_type = "place"),
  get_acs(geography = "state", state = "VA", table = "B01001",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    mutate(geo_type = "state")
)

b01001 <- b01001_raw |>
  mutate(
    var_num  = as.integer(str_extract(variable, "\\d+$")),
    age_band = case_match(
      var_num,
      c(3L, 4L, 5L, 6L, 27L, 28L, 29L, 30L)                          ~ "Under 18",
      c(7L, 8L, 9L, 10L, 11L, 31L, 32L, 33L, 34L, 35L)               ~ "18-34",
      c(12L, 13L, 14L, 15L, 16L, 17L, 18L, 19L,
        36L, 37L, 38L, 39L, 40L, 41L, 42L, 43L)                       ~ "35-64",
      c(20L, 21L, 22L, 44L, 45L, 46L)                                 ~ "65-74",
      c(23L, 24L, 25L, 47L, 48L, 49L)                                 ~ "75+",
      .default = NA_character_
    )
  ) |>
  filter(!is.na(age_band)) |>
  summarize(
    estimate = sum(estimate, na.rm = TRUE),
    moe      = sqrt(sum(moe^2, na.rm = TRUE)),
    .by = c(GEOID, NAME, geo_type, age_band)
  ) |>
  mutate(
    year = 2024L,
    cv   = if_else(estimate > 0, (moe / 1.645) / estimate * 100, NA_real_)
  )
message("B01001 banded: ", nrow(b01001), " rows (5 bands × ", n_distinct(b01001$GEOID), " geographies)")

## 4. B03002 – Race/ethnicity ----
# Key groups: NH White (003), NH Black (004), NH Asian (006), Hispanic (012); Other computed
message("Pulling B03002...")
b03002_key <- bind_rows(
  get_acs(geography = "county", state = "VA", table = "B03002",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID == fauquier) |>
    mutate(geo_type = "county"),
  get_acs(geography = "place", state = "VA", table = "B03002",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID %in% unname(towns)) |>
    mutate(geo_type = "place"),
  get_acs(geography = "state", state = "VA", table = "B03002",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    mutate(geo_type = "state")
) |>
  mutate(
    race_group = case_match(
      variable,
      "B03002_001" ~ "Total",
      "B03002_003" ~ "Non-Hispanic White",
      "B03002_004" ~ "Non-Hispanic Black",
      "B03002_006" ~ "Non-Hispanic Asian",
      "B03002_012" ~ "Hispanic or Latino",
      .default = NA_character_
    )
  ) |>
  filter(!is.na(race_group)) |>
  mutate(
    year = 2024L,
    cv   = if_else(estimate > 0, (moe / 1.645) / estimate * 100, NA_real_)
  )

# Other/Multiracial = Total − (NH White + NH Black + NH Asian + Hispanic)
# MOE for a derived remainder: sqrt(sum of all constituent MOEs squared)
b03002_other <- b03002_key |>
  summarize(
    estimate = estimate[race_group == "Total"] -
               sum(estimate[race_group != "Total"], na.rm = TRUE),
    moe      = sqrt(sum(moe^2, na.rm = TRUE)),
    year     = unique(year),
    .by = c(GEOID, NAME, geo_type)
  ) |>
  mutate(
    variable   = "B03002_other",
    race_group = "Other/Multiracial",
    cv         = if_else(estimate > 0, (moe / 1.645) / estimate * 100, NA_real_)
  )

b03002 <- bind_rows(b03002_key, b03002_other)
message("B03002 pulled: ", nrow(b03002), " rows (", n_distinct(b03002$race_group), " groups)")

## 5. B11001 – Household type ----
message("Pulling B11001...")
b11001 <- bind_rows(
  get_acs(geography = "county", state = "VA", table = "B11001",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID == fauquier) |>
    mutate(geo_type = "county"),
  get_acs(geography = "place", state = "VA", table = "B11001",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID %in% unname(towns)) |>
    mutate(geo_type = "place"),
  get_acs(geography = "state", state = "VA", table = "B11001",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    mutate(geo_type = "state")
) |>
  mutate(
    year = 2024L,
    cv   = if_else(estimate > 0, (moe / 1.645) / estimate * 100, NA_real_)
  )
message("B11001 pulled: ", nrow(b11001), " rows")

## 6. B11007 – Households with seniors living alone ----
# County + places only (state not needed per plan)
message("Pulling B11007...")
b11007 <- bind_rows(
  get_acs(geography = "county", state = "VA", table = "B11007",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID == fauquier) |>
    mutate(geo_type = "county"),
  get_acs(geography = "place", state = "VA", table = "B11007",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID %in% unname(towns)) |>
    mutate(geo_type = "place")
) |>
  mutate(
    year = 2024L,
    cv   = if_else(estimate > 0, (moe / 1.645) / estimate * 100, NA_real_)
  )
message("B11007 pulled: ", nrow(b11007), " rows")

## 7. B25010 – Average household size ----
message("Pulling B25010...")
b25010 <- bind_rows(
  get_acs(geography = "county", state = "VA", table = "B25010",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID == fauquier) |>
    mutate(geo_type = "county"),
  get_acs(geography = "place", state = "VA", table = "B25010",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID %in% unname(towns)) |>
    mutate(geo_type = "place"),
  get_acs(geography = "state", state = "VA", table = "B25010",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    mutate(geo_type = "state")
) |>
  mutate(
    year = 2024L,
    cv   = if_else(estimate > 0, (moe / 1.645) / estimate * 100, NA_real_)
  )
message("B25010 pulled: ", nrow(b25010), " rows")

## 8. Write output ----
write_rds(
  list(b01003 = b01003, b01001 = b01001, b03002 = b03002,
       b11001 = b11001, b11007 = b11007, b25010 = b25010),
  "data/acs_demographics.rds"
)
message("Wrote data/acs_demographics.rds")

## 9. Validate ----
dem <- read_rds("data/acs_demographics.rds")

pop <- dem$b01003 |> filter(GEOID == fauquier) |> pull(estimate)
stopifnot(between(pop, 70000, 82000))        # GP benchmark: ~75,865

hh <- dem$b11001 |>
  filter(GEOID == fauquier, variable == "B11001_001") |>
  pull(estimate)
stopifnot(between(hh, 24000, 29000))         # GP benchmark: ~26,720

message("acs_demographics.R validation passed.")
message("  Fauquier pop: ", format(pop, big.mark = ","))
message("  Fauquier HH:  ", format(hh,  big.mark = ","))
