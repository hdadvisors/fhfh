# gaps.R ----
# What:   Affordability by AMI band, rental gap, ownership gap, wages-vs-costs matrix (per PLAN §8)
# Source: data/{hud_ami,chas,mls,qcew,fred}.rds + r/affordcalc.R
# Output: data/gaps.rds
#
# Assumptions (Session 6, GP-mirrored so results reconcile with the Fauquier fact sheet):
#   mortgage rate = current PMMS 30-yr (fred, last non-NA); 10% down; 28% front-end (affordcalc);
#   tax+insurance = $697/mo combined proxy (reverse-engineered from GP's $183k on the $645,250
#   median at 6.1%); representative household size = 3-person (§8d). Rental gap uses CHAS T15C/T14B
#   (no PUMS — GP Fig 27 is PUMS-based; this is the county-specific CHAS analog).

## 1. Setup ----
library(tidyverse)
source("r/affordcalc.R")

hud_ami <- read_rds("data/hud_ami.rds")
chas    <- read_rds("data/chas.rds")
mls     <- read_rds("data/mls.rds")
qcew    <- read_rds("data/qcew.rds")
fred    <- read_rds("data/fred.rds")

rep_size  <- "3-person"                                  # §8(d)
down_pct  <- 0.10                                        # GP-mirrored
rate_row  <- fred$pmms_monthly |> filter(!is.na(mortgage_rate_30yr)) |> slice_max(date, n = 1)
int_rate  <- rate_row$mortgage_rate_30yr / 100           # DECIMAL (fred is percent)
rate_date <- rate_row$date
tax_ins   <- .tax_ins_monthly                            # GP-mirrored (affordcalc default, $697)

# Market reference points (last complete year = 2025; fact sheet: $645,250 sale / $2,450 rent)
ref_year  <- 2025
med_price <- mls$annual |> filter(year == ref_year) |> pull(median_price)
med_rent  <- mls$rentals |>
  filter(year == ref_year, between(lease_price, 200, 15000)) |>
  pull(lease_price) |> median(na.rm = TRUE)

## 2. "What each band affords" (Ch4 Fig 2) ----
# Band income ceilings at the representative household size → max rent (30%) + max price (10% down).
afford_by_band <- hud_ami$ami |>
  filter(hh_size == rep_size) |>
  transmute(band = level, income) |>
  calc_affordable_rent("income") |>
  calc_affordable_sales("income", dwn_opts = down_pct, int_rate = int_rate, tax_ins_monthly = tax_ins) |>
  rename(max_rent = affordable_rent, max_price = !!paste0("affordable_sales_", down_pct)) |>
  mutate(max_rent = round(max_rent), max_price = round(max_price))

## 3. Rental gap — CHAS T15C occupied + T14B vacant, "affordable & available" (Ch4 Fig 6) ----
# GP Fig 27 analog (county-specific, CHAS — no PUMS). Renter households by AMI band vs rental units
# affordable + available to that band. A unit affordable at band b is "available" to b if vacant or
# occupied by a household with income <= b (units taken by higher-income households are unavailable).
# Rent affordability tops out at ">80% AMI" (RHUD80), so income 80-100 & >100 collapse into >80.
rent_bands <- c("≤30% AMI", "30-50% AMI", "50-80% AMI", ">80% AMI")
to_rent_band <- function(x) if_else(x %in% c("80-100% AMI", ">100% AMI"), ">80% AMI", x)
band_idx <- set_names(seq_along(rent_bands), rent_bands)

t15c <- chas$t15c |>
  filter(geo_type == "county", rent %in% rent_bands) |>
  mutate(inc = to_rent_band(household_income))

renter_hh   <- t15c |> summarise(renter_hh = sum(estimate, na.rm = TRUE), .by = inc) |> rename(band = inc)
occ_afford  <- t15c |> summarise(occ = sum(estimate, na.rm = TRUE), .by = rent) |> rename(band = rent)
occ_avail   <- t15c |> filter(band_idx[inc] <= band_idx[rent]) |>     # occupant income <= unit rent band
  summarise(occ_avail = sum(estimate, na.rm = TRUE), .by = rent) |> rename(band = rent)
vacant      <- chas$t14b |>
  filter(geo_type == "county", rent %in% rent_bands) |>
  summarise(vacant = sum(estimate, na.rm = TRUE), .by = rent) |> rename(band = rent)

rental_gap <- tibble(band = factor(rent_bands, rent_bands)) |>
  left_join(renter_hh,  by = "band") |>
  left_join(occ_afford, by = "band") |>
  left_join(vacant,     by = "band") |>
  left_join(occ_avail,  by = "band") |>
  mutate(across(-band, \(x) replace_na(x, 0)),
         units_affordable = occ + vacant,             # all units renting in this band
         units_available  = occ_avail + vacant,       # affordable to & available for this band
         surplus_deficit  = units_available - renter_hh) |>
  select(band, renter_hh, units_affordable, units_available, surplus_deficit)

## 4. Ownership gap — MLS active listings × band affordability (Ch4 Fig 7, GP Fig 28) ----
# Active for-sale listings binned into each band's affordable price range vs households in the band.
# Caveat: listings are a point-in-time flow; households are a stock — mirror GP's framing in captions.
ami_from_income <- c("≤30% AMI" = "ami30", "30-50% AMI" = "ami50", "50-80% AMI" = "ami80",
                     "80-100% AMI" = "ami100", ">100% AMI" = "ami120")

hh_by_band <- chas$t7 |>
  filter(geo_type == "county", household_income %in% names(ami_from_income)) |>
  summarise(households = sum(estimate, na.rm = TRUE), .by = household_income) |>
  mutate(band = factor(ami_from_income[household_income], levels = levels(afford_by_band$band)))

active   <- mls$active |> filter(!is.na(list_price), list_price > 0)
ceilings <- afford_by_band |> arrange(band) |> pull(max_price)
lowers   <- c(0, head(ceilings, -1))                 # lower edge of each band's price range
uppers   <- c(head(ceilings, -1), Inf)               # top band is open-ended (all higher-priced homes)

ownership_gap <- afford_by_band |>
  arrange(band) |>
  mutate(lower = lowers, upper = uppers,
         listings_affordable = map2_int(lower, upper,
                                        \(lo, hi) sum(active$list_price > lo & active$list_price <= hi))) |>
  left_join(hh_by_band |> select(band, households), by = "band") |>
  transmute(band, max_price, price_range_low = lower, price_range_high = upper,
            listings_affordable, households,
            surplus_deficit = listings_affordable - households)

## 5. Wages-vs-costs matrix (Ch4 Fig 8 — signature chart, fact-sheet replication) ----
# GP's four bars: All Jobs (county total), the top-3 employment categories (Health Care & Retail =
# private NAICS sectors; Local Government = ownership own_code 3), plus a 2-worker household (2×All
# Jobs). Wages = avg annual pay (≈ GP's avg weekly wage × 52). Government kept separate from the
# private sectors to avoid double-counting.
qyr <- max(qcew$total$year)
wage_of <- function(tbl, ...) tbl |> filter(area_fips == "51061", year == qyr, ...) |> pull(avg_annual_pay)

all_jobs <- wage_of(qcew$total, own_code == "0")
wages_costs <- tibble(
  category = c("All Jobs", "Health Care", "Retail Trade", "Local Government", "2-worker household"),
  type     = c("total", "sector (private)", "sector (private)", "local government", "2 × All Jobs"),
  avg_wage = c(all_jobs,
               wage_of(qcew$sector, industry_code == "62",    own_code == "5"),
               wage_of(qcew$sector, industry_code == "44-45", own_code == "5"),
               wage_of(qcew$ownership, own_code == "3"),
               all_jobs * 2)
) |>
  mutate(one_earner = if_else(category == "2-worker household", NA_real_, avg_wage),
         two_earner = avg_wage * if_else(category == "2-worker household", 1, 2))

## 6. Income-needed thresholds + summary (fact-sheet ~$98k rent / ~$183k buy) ----
thresholds <- tibble(med_price = med_price, med_rent = med_rent) |>
  calc_income_needed("med_price", "med_rent",
                     int_rate = int_rate, down_pct = down_pct, tax_ins_monthly = tax_ins)
income_needed <- thresholds |>
  transmute(med_rent, med_price, renter_income = round(renter_income), buyer_income = round(buyer_income))

# attach the thresholds to the wages matrix for the chart's reference lines
wages_costs <- wages_costs |>
  mutate(income_needed_rent = income_needed$renter_income,
         income_needed_buy  = income_needed$buyer_income)

## 7. Assumptions record (for Session 11 data-notes) ----
assumptions <- tibble(
  mortgage_rate          = int_rate,
  rate_pull_date         = rate_date,
  down_payment           = down_pct,
  front_end_ratio        = 0.28,
  tax_ins_monthly        = tax_ins,
  representative_hh_size  = rep_size,
  median_price           = med_price,
  median_rent            = med_rent,
  reference_year         = ref_year,
  source = paste("Rate: PMMS via fred.rds (last non-NA). Down/front-end/tax+ins mirror the GP study",
                 "(fact sheet + pp.42,48); tax+ins is a combined proxy (GP published no itemized",
                 "figure). Rental gap: CHAS T15C/T14B (no PUMS). Wages: QCEW avg annual pay.")
)

## 8. Write output ----
write_rds(
  list(afford_by_band = afford_by_band, rental_gap = rental_gap, ownership_gap = ownership_gap,
       wages_costs = wages_costs, income_needed = income_needed, assumptions = assumptions),
  "data/gaps.rds"
)
message("Wrote data/gaps.rds")

## 9. Validate ----
out <- read_rds("data/gaps.rds")
rg  <- out$rental_gap
og  <- out$ownership_gap

message("  Rate: ", round(int_rate * 100, 2), "% (", rate_date, ") | ",
        "median price $", format(med_price, big.mark = ","), " | median rent $", med_rent)
message("  Income needed — rent: $", format(out$income_needed$renter_income, big.mark = ","),
        " (fact-sheet ~$98k) | buy: $", format(out$income_needed$buyer_income, big.mark = ","),
        " (fact-sheet ~$183k)")
message("  Rental gap ≤30% AMI: ", rg$surplus_deficit[rg$band == "≤30% AMI"],
        " (deficit expected) | Ownership gap ≤30%: ", og$surplus_deficit[og$band == "ami30"])

stopifnot(
  abs(out$income_needed$renter_income - 98000)  / 98000  < 0.20,
  abs(out$income_needed$buyer_income  - 183000) / 183000 < 0.25,
  all(diff(afford_by_band$max_price) >= 0),                 # higher band → higher max price
  rg$surplus_deficit[rg$band == "≤30% AMI"] < 0,            # rental deficit at the bottom (GP Fig 27)
  og$surplus_deficit[og$band == "ami30"]    < 0,            # ownership deficit at low band (GP Fig 28)
  nrow(out$wages_costs) == 5,
  out$wages_costs$income_needed_rent[1] > 0
)
message("gaps.R validation passed.")
