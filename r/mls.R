# mls.R ----
# What:   Tidy Bright MLS sales + listings + rentals; splice VAR/GP sources for 2016–2021
# Source: data/raw/mls/mls_sales_*.csv (2022+), data/raw/mls/var_*.xlsx (2016–2021),
#         data/gp_appendix.rds ($sales), data/raw/mls/mls_active_*.csv, mls_rentals_*.csv
# Output: data/mls.rds

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)
library(lubridate)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

town_zips <- c("20186", "20187", "22712")

## 2. MLS sales transactions (2022+) ----
message("Reading MLS sales CSVs (2022–2026 YTD)...")

sales_files <- list.files("data/raw/mls", pattern = "mls_sales_.*\\.csv", full.names = TRUE)
message("  Files found: ", paste(basename(sales_files), collapse = ", "))

sales_raw <- map_dfr(sales_files, \(f) {
  read_csv(f, show_col_types = FALSE) |>
    mutate(source_file = basename(f))
}) |>
  clean_names()

message("  Transactions loaded: ", nrow(sales_raw))
message("  Columns: ", paste(names(sales_raw)[1:min(12, ncol(sales_raw))], collapse = ", "))

# Actual Bright MLS column names: sales_price, sales_date, list_price, new_resale
sales <- sales_raw |>
  mutate(
    close_price = parse_number(as.character(sales_price)),
    list_price  = parse_number(as.character(list_price)),
    close_date  = mdy(sales_date),
    year        = year(close_date),
    month       = month(close_date)
  ) |>
  filter(!is.na(close_date), !is.na(close_price), close_price > 0)

message("  Parsed transactions: ", nrow(sales),
        " (", min(sales$year), "–", max(sales$year), ")")

## 3. VAR monthly data (2016–2021) ----
message("Reading VAR xlsx files...")

var_msp_raw <- read_excel("data/raw/mls/var_msp_2016_2026_ytd.xlsx", col_names = FALSE)
var_sal_raw <- read_excel("data/raw/mls/var_sales_2016_2026_ytd.xlsx", col_names = FALSE)

# Row containing Fauquier County identified by col 1 label
fauquier_msp_row <- var_msp_raw |>
  filter(str_detect(`...1`, regex("fauquier", ignore_case = TRUE)))
fauquier_sal_row <- var_sal_raw |>
  filter(str_detect(`...1`, regex("fauquier", ignore_case = TRUE)))

stopifnot(nrow(fauquier_msp_row) == 1, nrow(fauquier_sal_row) == 1)

# Build date sequence by column position (col 2 = Jan 2016).
# Labels are unreliable — July 2020 is mislabeled "2021 - Jul" in the sales file.
date_seq_msp <- seq(as.Date("2016-01-01"), by = "month",
                    length.out = ncol(var_msp_raw) - 1)
date_seq_sal <- seq(as.Date("2016-01-01"), by = "month",
                    length.out = ncol(var_sal_raw) - 1)

var_monthly_msp <- tibble(
  date         = date_seq_msp,
  median_price = parse_number(as.character(unlist(fauquier_msp_row[-1])))
) |>
  mutate(year = year(date), month = month(date))

var_monthly_sal <- tibble(
  date        = date_seq_sal,
  sales_count = parse_number(as.character(unlist(fauquier_sal_row[-1])))
) |>
  mutate(year = year(date), month = month(date))

# Restrict VAR to 2016–2021 (MLS covers 2022+)
var_monthly <- var_monthly_msp |>
  left_join(var_monthly_sal, by = c("date", "year", "month")) |>
  filter(year <= 2021, !is.na(median_price))

message("  VAR monthly rows (2016–2021): ", nrow(var_monthly))

## 4. Monthly price series — VAR splice to MLS ----
message("Building monthly price series...")

mls_monthly <- sales |>
  filter(year >= 2022) |>
  summarize(
    median_price = median(close_price, na.rm = TRUE),
    sales_count  = n(),
    .by = c(year, month)
  ) |>
  mutate(date = make_date(year, month, 1))

monthly <- bind_rows(
  var_monthly |> mutate(source = "VAR"),
  mls_monthly |> mutate(source = "MLS")
) |>
  arrange(date)

message("  Monthly rows: ", nrow(monthly),
        " (", min(monthly$year), "–", max(monthly$year), ")")

## 5. Annual series — GP appendix splice to MLS ----
message("Building annual series (GP 2016–2021 / MLS 2022+)...")

gp <- read_rds("data/gp_appendix.rds")
message("  GP appendix frames: ", paste(names(gp), collapse = ", "))

# Confirmed column names from gp_appendix.rds: year, county, sales, median_sold_price, source
gp_annual <- gp$sales |>
  filter(county == "Fauquier", year <= 2021) |>
  select(year, sales_count = sales, median_price = median_sold_price)

mls_annual <- sales |>
  filter(year >= 2022) |>
  summarize(
    median_price = median(close_price, na.rm = TRUE),
    sales_count  = n(),
    .by = year
  )

annual <- bind_rows(
  gp_annual |> mutate(source = "GP"),
  mls_annual |> mutate(source = "MLS")
) |>
  arrange(year)

message("  Annual rows: ", nrow(annual),
        " (", min(annual$year), "–", max(annual$year), ")")

## 6. Active listings snapshot ----
message("Reading active listings snapshot...")

active_files <- list.files("data/raw/mls", pattern = "mls_active", full.names = TRUE)
active_raw   <- map_dfr(active_files, \(f) read_csv(f, show_col_types = FALSE)) |>
  clean_names()

active <- active_raw |>
  mutate(
    list_price = parse_number(as.character(list_price)),
    list_date  = mdy(sales_date)   # in active file sales_date = listing date
  ) |>
  filter(!is.na(list_price), list_price > 0)

message("  Active listings: ", nrow(active), " (benchmark ~218)")

## 7. Rental transactions ----
message("Reading rental CSVs...")

rental_files <- list.files("data/raw/mls", pattern = "mls_rentals", full.names = TRUE)

rentals_raw <- map_dfr(rental_files, \(f) {
  read_csv(f, show_col_types = FALSE) |>
    mutate(source_file = basename(f))
}) |>
  clean_names()

rentals <- rentals_raw |>
  mutate(
    lease_price = parse_number(as.character(sales_price)),
    lease_date  = mdy(sales_date),
    year        = year(lease_date),
    month       = month(lease_date)
  ) |>
  filter(!is.na(lease_date), !is.na(lease_price), lease_price > 0)

message("  Rental records: ", nrow(rentals),
        " (", min(rentals$year), "–", max(rentals$year), ")")

## 8. Write output ----
write_rds(
  list(monthly = monthly, annual = annual, active = active, rentals = rentals),
  "data/mls.rds"
)
message("Wrote data/mls.rds")

## 9. Validate ----
out <- read_rds("data/mls.rds")

stopifnot(
  min(out$monthly$year) == 2016,
  max(out$monthly$year) >= 2025,
  nrow(out$active) >= 100
)

ann_2025 <- out$annual |> filter(year == 2025) |> pull(median_price)
if (length(ann_2025) > 0) {
  if (!between(ann_2025, 550000, 750000))
    warning("2025 annual median $", round(ann_2025, 0),
            " outside expected range $550k–$750k")
  message("  2025 annual median: $", format(round(ann_2025, 0), big.mark = ","),
          " (benchmark ~$645,250)")
}

median_rent <- median(out$rentals$lease_price, na.rm = TRUE)

message("mls.R validation passed.")
message("  Monthly rows: ", nrow(out$monthly))
message("  Annual rows:  ", nrow(out$annual))
message("  Active listings: ", nrow(out$active))
message("  Rental records:  ", nrow(out$rentals))
message("  Median rental price: $", format(round(median_rent, 0), big.mark = ","),
        " (benchmark ~$2,450)")
