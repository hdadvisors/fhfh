# decennial.R ----
# What:   Decennial census population, housing units, and tenure — 1990–2020 trend
# Tables: 2020 DHC (P1, H1, H4), 2010 SF1 (P001, H001, H004), 2000 SF1 (P001, H001, H004)
#         1990 hardcoded from Census QuickFacts (tidycensus does not support 1990 DHC)
# Source: tidycensus get_decennial()
# Output: data/decennial.rds

## 1. Setup ----
library(tidyverse)
library(tidycensus)
library(janitor)

if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- "C:/Users/JTK/Documents/.Renviron"
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}

dir.create("data", showWarnings = FALSE, recursive = TRUE)

fauquier <- "51061"
towns    <- c(warrenton = "5183136", bealeton = "5105336")

## 2. Population ----

## 2a. 2020 DHC – P1 ----
message("Pulling 2020 DHC P1...")
pop_2020 <- bind_rows(
  get_decennial(geography = "county", state = "VA", table = "P1",
                year = 2020, sumfile = "dhc") |>
    filter(GEOID == fauquier) |>
    mutate(year = 2020L, geo_type = "county"),
  get_decennial(geography = "place", state = "VA", table = "P1",
                year = 2020, sumfile = "dhc") |>
    filter(GEOID %in% unname(towns)) |>
    mutate(year = 2020L, geo_type = "place")
)
message("  2020 pop rows: ", nrow(pop_2020))

## 2b. 2010 SF1 – P001 ----
message("Pulling 2010 SF1 P001...")
pop_2010 <- bind_rows(
  get_decennial(geography = "county", state = "VA", table = "P001",
                year = 2010, sumfile = "sf1") |>
    filter(GEOID == fauquier) |>
    mutate(year = 2010L, geo_type = "county"),
  get_decennial(geography = "place", state = "VA", table = "P001",
                year = 2010, sumfile = "sf1") |>
    filter(GEOID %in% unname(towns)) |>
    mutate(year = 2010L, geo_type = "place")
)
message("  2010 pop rows: ", nrow(pop_2010))

## 2c. 2000 SF1 – P001 (with tryCatch; place GEOIDs may differ from 2023 tigris) ----
message("Pulling 2000 SF1 P001...")
pop_2000 <- tryCatch({
  bind_rows(
    get_decennial(geography = "county", state = "VA", table = "P001",
                  year = 2000, sumfile = "sf1") |>
      filter(GEOID == fauquier) |>
      mutate(year = 2000L, geo_type = "county"),
    get_decennial(geography = "place", state = "VA", table = "P001",
                  year = 2000, sumfile = "sf1") |>
      filter(GEOID %in% unname(towns)) |>
      mutate(year = 2000L, geo_type = "place")
  )
}, error = function(e) {
  message("2000 SF1 P001 unavailable: ", conditionMessage(e))
  message("Using hardcoded 2000 county population: 55,139 (Census 2000 SF1)")
  tibble(GEOID = fauquier, NAME = "Fauquier County, Virginia",
         variable = "P001001", value = 55139L,
         year = 2000L, geo_type = "county", source = "hardcoded")
})
message("  2000 pop rows: ", nrow(pop_2000))

## 2d. 1990 hardcoded from Census QuickFacts ----
pop_1990 <- tibble(
  GEOID    = fauquier,
  NAME     = "Fauquier County, Virginia",
  variable = "P001001",
  value    = 48741L,           # Census 1990 SF1 (QuickFacts: 47,286 is 2000 base; see §11)
  year     = 1990L,
  geo_type = "county",
  source   = "hardcoded — Census 1990 QuickFacts"
)
message("  1990 pop hardcoded: ", pop_1990$value)

pop <- bind_rows(pop_2020, pop_2010, pop_2000, pop_1990)
message("Total pop rows: ", nrow(pop))

## 3. Housing units ----

## 3a. 2020 DHC – H1 ----
message("Pulling 2020 DHC H1...")
units_2020 <- bind_rows(
  get_decennial(geography = "county", state = "VA", table = "H1",
                year = 2020, sumfile = "dhc") |>
    filter(GEOID == fauquier) |>
    mutate(year = 2020L, geo_type = "county"),
  get_decennial(geography = "place", state = "VA", table = "H1",
                year = 2020, sumfile = "dhc") |>
    filter(GEOID %in% unname(towns)) |>
    mutate(year = 2020L, geo_type = "place")
)
message("  2020 units rows: ", nrow(units_2020))

## 3b. 2010 SF1 – H001 ----
message("Pulling 2010 SF1 H001...")
units_2010 <- bind_rows(
  get_decennial(geography = "county", state = "VA", table = "H001",
                year = 2010, sumfile = "sf1") |>
    filter(GEOID == fauquier) |>
    mutate(year = 2010L, geo_type = "county"),
  get_decennial(geography = "place", state = "VA", table = "H001",
                year = 2010, sumfile = "sf1") |>
    filter(GEOID %in% unname(towns)) |>
    mutate(year = 2010L, geo_type = "place")
)
message("  2010 units rows: ", nrow(units_2010))

## 3c. 2000 SF1 – H001 ----
message("Pulling 2000 SF1 H001...")
units_2000 <- tryCatch({
  bind_rows(
    get_decennial(geography = "county", state = "VA", table = "H001",
                  year = 2000, sumfile = "sf1") |>
      filter(GEOID == fauquier) |>
      mutate(year = 2000L, geo_type = "county"),
    get_decennial(geography = "place", state = "VA", table = "H001",
                  year = 2000, sumfile = "sf1") |>
      filter(GEOID %in% unname(towns)) |>
      mutate(year = 2000L, geo_type = "place")
  )
}, error = function(e) {
  message("2000 SF1 H001 unavailable: ", conditionMessage(e), ". Logged in §11.")
  tibble(GEOID = fauquier, NAME = "Fauquier County, Virginia",
         variable = "H001001", value = NA_integer_,
         year = 2000L, geo_type = "county", source = "not available")
})
message("  2000 units rows: ", nrow(units_2000))

units <- bind_rows(units_2020, units_2010, units_2000)
message("Total units rows: ", nrow(units))

## 4. Tenure ----

## 4a. 2020 DHC – H4 ----
message("Pulling 2020 DHC H4...")
tenure_2020 <- bind_rows(
  get_decennial(geography = "county", state = "VA", table = "H4",
                year = 2020, sumfile = "dhc") |>
    filter(GEOID == fauquier) |>
    mutate(year = 2020L, geo_type = "county"),
  get_decennial(geography = "place", state = "VA", table = "H4",
                year = 2020, sumfile = "dhc") |>
    filter(GEOID %in% unname(towns)) |>
    mutate(year = 2020L, geo_type = "place")
)
message("  2020 tenure rows: ", nrow(tenure_2020))

## 4b. 2010 SF1 – H004 ----
message("Pulling 2010 SF1 H004...")
tenure_2010 <- bind_rows(
  get_decennial(geography = "county", state = "VA", table = "H004",
                year = 2010, sumfile = "sf1") |>
    filter(GEOID == fauquier) |>
    mutate(year = 2010L, geo_type = "county"),
  get_decennial(geography = "place", state = "VA", table = "H004",
                year = 2010, sumfile = "sf1") |>
    filter(GEOID %in% unname(towns)) |>
    mutate(year = 2010L, geo_type = "place")
)
message("  2010 tenure rows: ", nrow(tenure_2010))

## 4c. 2000 SF1 – H004 ----
message("Pulling 2000 SF1 H004...")
tenure_2000 <- tryCatch({
  bind_rows(
    get_decennial(geography = "county", state = "VA", table = "H004",
                  year = 2000, sumfile = "sf1") |>
      filter(GEOID == fauquier) |>
      mutate(year = 2000L, geo_type = "county"),
    get_decennial(geography = "place", state = "VA", table = "H004",
                  year = 2000, sumfile = "sf1") |>
      filter(GEOID %in% unname(towns)) |>
      mutate(year = 2000L, geo_type = "place")
  )
}, error = function(e) {
  message("2000 SF1 H004 unavailable: ", conditionMessage(e), ". Logged in §11.")
  tibble(GEOID = fauquier, NAME = "Fauquier County, Virginia",
         variable = "H004001", value = NA_integer_,
         year = 2000L, geo_type = "county", source = "not available")
})
message("  2000 tenure rows: ", nrow(tenure_2000))

tenure <- bind_rows(tenure_2020, tenure_2010, tenure_2000)
message("Total tenure rows: ", nrow(tenure))

## 5. Write output ----
write_rds(list(pop = pop, units = units, tenure = tenure), "data/decennial.rds")
message("Wrote data/decennial.rds")

## 6. Validate ----
dec <- read_rds("data/decennial.rds")

p2020 <- dec$pop |>
  filter(GEOID == fauquier, year == 2020, str_detect(variable, "001")) |>
  pull(value)
stopifnot(between(p2020, 70000, 78000))       # Census DHC 2020: ~73,895
message("  2020 pop: ", format(p2020, big.mark = ","), " (target: 70k–78k)")

p2010 <- dec$pop |>
  filter(GEOID == fauquier, year == 2010, str_detect(variable, "001")) |>
  pull(value)
stopifnot(between(p2010, 62000, 68000))       # Census SF1 2010: ~65,203
message("  2010 pop: ", format(p2010, big.mark = ","), " (target: 62k–68k)")

message("decennial.R validation passed.")
