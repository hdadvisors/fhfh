# wcoop.R ----
# What:   Weldon Cooper population projections → Fauquier/Warrenton totals, senior-age detail,
#         household & production projections (two methods), and a tenure×AMI needs-allocation frame.
# Source: data/raw/wcoop/*.xlsx (WC 1-July-2025 vintage) + data/{acs_demographics,bps,chas,gaps,hud_ami}.rds
# Output: data/wcoop.rds
#   NOTE (Session 7): the household conversion is stored BOTH ways — constant average household size
#   (WC pop ÷ ACS B25010) and constant total-population headship (base HH ÷ base pop). The GP study
#   reports +7,737 HH / ~307 units/yr to 2050, which implies an avg HH size of ~2.70; the current
#   2020-2024 ACS B25010 for Fauquier is 2.78, so BOTH methods here land ~264-269 units/yr and fall
#   short of GP. Headline method is chosen at the Ch 6 build (Session 11); both are carried here.

## 1. Setup ----
library(tidyverse)
library(readxl)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

# Geography constants (mirror _common.R — defined here so the script runs standalone)
fauquier <- "51061"
towns    <- c(warrenton = "5183136", bealeton = "5105336")
virginia <- "51000"                                   # WC statewide FIPS is 51000

wc_dir    <- "data/raw/wcoop"
wc_total  <- file.path(wc_dir, "VAPopProjections_Total_2030-2050_1July2025.xlsx")
wc_towns  <- file.path(wc_dir, "VAPopProjections_LargeTowns_2030-2050_1July2025.xlsx")
wc_agesex <- file.path(wc_dir, "VAPopProjections_AgeSex_2030-2050_1July2025.xlsx")

## 2. WC total population (county + VA) ----
# Two sheets: {2030,2040,2050} and {2035,2045,2055}. skip=4 drops 2 title + 2 header rows;
# data begins at Virginia (51000). Values are floats → round. 2055 is dropped (horizon caps at 2050).
wc_total_a <- read_excel(wc_total, sheet = "Total_2030,2040,2050", skip = 4,
                         col_names = c("fips", "geography", "pop_2030", "pop_2040", "pop_2050"))
wc_total_b <- read_excel(wc_total, sheet = "Total_2035,2045,2055", skip = 4,
                         col_names = c("fips", "geography", "pop_2035", "pop_2045", "pop_2055"))

pop_county <- list(wc_total_a, wc_total_b) |>
  reduce(full_join, by = c("fips", "geography")) |>
  mutate(fips = as.character(fips)) |>
  filter(fips %in% c(fauquier, virginia)) |>
  pivot_longer(starts_with("pop_"), names_to = "year", names_prefix = "pop_",
               names_transform = as.integer, values_to = "population") |>
  filter(year <= 2050) |>
  transmute(geoid = fips, name = geography, year, population = round(population)) |>
  arrange(geoid, year)

## 3. WC large-town (Warrenton — the only Fauquier town WC projects; Bealeton is a CDP, absent) ----
pop_town <- read_excel(wc_towns, sheet = 1, skip = 4,
                       col_names = c("fips", "town", "parent_county",
                                     "pop_2030", "pop_2040", "pop_2050")) |>
  mutate(fips = as.character(fips)) |>
  filter(str_detect(fips, "^\\d"), fips == towns[["warrenton"]]) |>   # drops trailing "Note:" row
  pivot_longer(starts_with("pop_"), names_to = "year", names_prefix = "pop_",
               names_transform = as.integer, values_to = "population") |>
  transmute(geoid = fips, name = town, year, population = round(population)) |>
  arrange(year)

## 4. WC age/sex — Total section only (Total/Female/Male order; Total = 1-based cols 4-21), 65+/75+ ----
age_labels <- c("0 to 4", "5 to 9", "10 to 14", "15 to 19", "20 to 24", "25 to 29", "30 to 34",
                "35 to 39", "40 to 44", "45 to 49", "50 to 54", "55 to 59", "60 to 64",
                "65 to 69", "70 to 74", "75 to 79", "80 to 84", "85 and Over")   # 18 five-year bands

read_agesex <- function(sheet) {
  read_excel(wc_agesex, sheet = sheet, skip = 4, col_names = FALSE,
             .name_repair = "unique_quiet") |>
    select(1:3, 4:21) |>                                    # id cols + Total section (cols 4-21, 1-based)
    set_names(c("fips", "geography", "total_pop", age_labels)) |>
    mutate(fips = as.character(fips)) |>
    filter(fips == fauquier) |>
    pivot_longer(all_of(age_labels), names_to = "age_band", values_to = "population") |>
    mutate(year = as.integer(sheet), population = round(population),
           age_band = factor(age_band, levels = age_labels)) |>
    select(geoid = fips, name = geography, year, age_band, population)
}
age_county <- map_dfr(c("2030", "2040", "2050"), read_agesex)

senior <- age_county |>
  summarise(senior_65plus = sum(population[age_band %in% age_labels[14:18]]),
            senior_75plus = sum(population[age_band %in% age_labels[16:18]]), .by = year)
age_county <- age_county |> left_join(senior, by = "year")     # per-year 65+/75+ carried on each band row

## 5. Baselines + headship (2020-2024 ACS 5-year, Fauquier county) ----
dem <- read_rds("data/acs_demographics.rds")
pull1 <- function(tbl, v) {
  dem[[tbl]] |> filter(GEOID == fauquier, variable == v, geo_type == "county") |> pull(estimate)
}
base_hh   <- pull1("b11001", "B11001_001")     # occupied households  = 26,720
base_pop  <- pull1("b01003", "B01003_001")     # total population     = 74,577
avg_hh    <- pull1("b25010", "B25010_001")     # avg household size   = 2.78 (not GP's implied ~2.70)
base_year <- 2024L
headship  <- base_hh / base_pop                # 0.3583

## 6. Household + production frames (BOTH methods) ----
vac <- 0.03                                    # vacancy allowance on net new units
households <- pop_county |>
  filter(geoid == fauquier) |>
  transmute(year, wc_pop = population,
            hh_headship     = round(wc_pop * headship),
            hh_avgsize      = round(wc_pop / avg_hh),
            growth_headship = hh_headship - base_hh,
            growth_avgsize  = hh_avgsize  - base_hh)

bps_avg <- read_rds("data/bps.rds")$bps_county |>
  filter(year >= 2020) |>
  summarise(t = sum(units, na.rm = TRUE), .by = year) |>
  summarise(m = mean(t)) |> pull(m)            # 2020-2025 mean permits/yr = 266

production <- households |>
  filter(year %in% c(2030, 2040, 2050)) |>
  transmute(horizon = year, years_out = year - base_year,
            units_needed_avgsize    = round(growth_avgsize  * (1 + vac)),
            units_needed_headship   = round(growth_headship * (1 + vac)),
            units_per_year_avgsize  = growth_avgsize  * (1 + vac) / years_out,
            units_per_year_headship = growth_headship * (1 + vac) / years_out,
            bps_2020_25_avg = bps_avg)

## 7. Needs-allocation — tenure × AMI forward need, joined to Session 6 gap direction ----
# forward_need = current CHAS-T7 tenure×AMI share × total projected growth (avg-size method, to 2050).
# Gap direction is attached TENURE-AWARE: Homeowner rows carry the ownership_gap surplus/deficit
# (ami30…ami120), Renter rows carry the rental_gap surplus/deficit. Rental affordability collapses
# above 80% AMI, so ami100 & ami120 renter rows both map to the rental_gap ">80% AMI" band.
ami_from_income <- c("≤30% AMI" = "ami30", "30-50% AMI" = "ami50", "50-80% AMI" = "ami80",
                     "80-100% AMI" = "ami100", ">100% AMI" = "ami120")
rent_band_of    <- c(ami30 = "≤30% AMI", ami50 = "30-50% AMI", ami80 = "50-80% AMI",
                     ami100 = ">80% AMI", ami120 = ">80% AMI")

chas <- read_rds("data/chas.rds")
gaps <- read_rds("data/gaps.rds")

shares <- chas$t7 |>
  filter(geo_type == "county", !is.na(tenure), household_income %in% names(ami_from_income)) |>
  summarise(hh = sum(estimate, na.rm = TRUE), .by = c(tenure, household_income)) |>
  mutate(share = hh / sum(hh), band = unname(ami_from_income[household_income]))

total_growth <- households |> filter(year == 2050) |> pull(growth_avgsize)   # avg-size method

own_gap  <- gaps$ownership_gap |> transmute(band = as.character(band), own_sd = surplus_deficit)
rent_gap <- gaps$rental_gap    |> transmute(rent_band = band,          rent_sd = surplus_deficit)

needs_allocation <- shares |>
  mutate(forward_need = round(share * total_growth),
         rent_band    = unname(rent_band_of[band])) |>
  left_join(own_gap,  by = "band") |>
  left_join(rent_gap, by = "rent_band") |>
  mutate(existing_surplus_deficit = if_else(tenure == "Homeowner", own_sd, rent_sd),
         gap_source               = if_else(tenure == "Homeowner", "ownership_gap", "rental_gap")) |>
  select(tenure, household_income, band, current_hh = hh, share, forward_need,
         existing_surplus_deficit, gap_source) |>
  arrange(tenure, band)

## 8. Assumptions record (for Session 11 data-notes) ----
assumptions <- tibble(
  base_year         = base_year,
  base_pop          = base_pop,
  base_hh           = base_hh,
  headship          = headship,
  avg_hh_size       = avg_hh,
  vacancy_allowance = vac,
  bps_2020_25_avg   = bps_avg,
  source = paste(
    "Population: Weldon Cooper Center 1-July-2025 projections (Total, LargeTowns, AgeSex).",
    "Baselines: 2020-2024 ACS 5-year (B11001 households, B01003 population, B25010 avg HH size).",
    "Households stored two ways: constant avg HH size (WC pop ÷ B25010=", round(avg_hh, 2), ") and",
    "constant total-pop headship (", round(headship, 4), "). Production applies a 3% vacancy",
    "allowance; recent pace = BPS 2020-2025 mean permits (", round(bps_avg), "/yr). GP study reports",
    "+7,737 HH / ~307 units/yr to 2050 (implies avg HH size ~2.70); headline method deferred to Ch 6."
  )
)

## 9. Write output ----
write_rds(
  list(pop_county       = pop_county,
       pop_town         = pop_town,
       age_county       = age_county,
       households       = households,
       production       = production,
       needs_allocation = needs_allocation,
       assumptions      = assumptions),
  "data/wcoop.rds"
)
message("Wrote data/wcoop.rds")

## 10. Validate ----
out   <- read_rds("data/wcoop.rds")
g_avg <- out$households$growth_avgsize[out$households$year == 2050]
g_hs  <- out$households$growth_headship[out$households$year == 2050]
pyr   <- out$production$units_per_year_avgsize[out$production$horizon == 2050]
pyr_hs <- out$production$units_per_year_headship[out$production$horizon == 2050]

message("  Fauquier pop 2050 = ", out$pop_county |> filter(geoid == fauquier, year == 2050) |> pull(population),
        " | Warrenton 2050 = ", out$pop_town |> filter(year == 2050) |> pull(population),
        " (Bealeton absent — CDP)")
message("  HH growth to 2050 — avg-size (÷", round(avg_hh, 2), "): +", g_avg,
        " | headship (", round(headship, 4), "): +", g_hs)
message("  Production need/yr to 2050 — avg-size: ", round(pyr), " | headship: ", round(pyr_hs),
        " | recent BPS pace: ", round(bps_avg))
message("  NOTE: GP = +7,737 HH / ~307 units/yr (implies avg HH size ~2.70). Current ACS B25010 = ",
        round(avg_hh, 2), " → both methods below GP; headline deferred to Session 11.")
message("  needs_allocation forward_need sum = ", sum(out$needs_allocation$forward_need),
        " (≈ total growth ", total_growth, ")")

stopifnot(
  out$pop_county |> filter(geoid == fauquier, year == 2050) |> pull(population) |> between(88000, 98000),
  between(g_avg, 6000, 9500),                # avg-size route (real B25010=2.78 → +6,795; GP was +7,737)
  between(pyr,   240, 360),                  # ~269/yr (GP ~307/yr)
  nrow(out$pop_town) >= 1,                   # Warrenton present
  tail(out$age_county$year, 1) == 2050,
  sum(out$needs_allocation$forward_need) |> between(0.9 * g_avg, 1.1 * g_avg)   # allocation ≈ total growth
)
message("wcoop.R validation passed.")
