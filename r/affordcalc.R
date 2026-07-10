## r/affordcalc.R
## What: affordability calculation function library (rent, sales, income-needed)
## Source: adapted from R:\hda\faar\r\affordcalc.R
## Output: function library only — safe to source() with no side effects

library(tidyverse)
library(FinCal)

## Mortgage assumption defaults (PLAN.md §8). Updated Session 6 (2026-07-10).
## Authoritative rate/tax/ins are passed explicitly from r/gaps.R; these are library fallbacks.
## GP-mirrored so the ownership gap reconciles with GP Figs 27-28 / the Fauquier fact sheet.

.int_rate_default  <- 0.0649  # 30-yr PMMS monthly avg, 2026-06 (data/fred.rds, last non-NA) — was 0.0694 (2024-05-23)
.tax_ins_monthly   <- 697     # combined RE tax + insurance proxy (GP-mirrored). Reverse-engineered to
                              # reproduce GP's ~$183k income-needed on the $645,250 median home at 6.1%/
                              # 10% down/28% via this engine (~1.3% of value/yr). GP published no itemized
                              # tax rate or insurance figure (GP study pp.42,48 + Fauquier fact sheet). — was 250

## 1. calc_affordable_rent ----
## Returns max affordable monthly rent at 30% of annual income (PLAN.md §8).

calc_affordable_rent <- function(data, input_col) {
  data |>
    mutate(affordable_rent = (0.3 * !!sym(input_col)) / 12)
}

## 2. calc_affordable_sales ----
## Returns max affordable home price for each down payment fraction in dwn_opts.
## dwn_opts: numeric vector (e.g. c(0.03, 0.10, 0.20)); one output column per element.
## Payment cap: 28% of monthly income minus tax_ins_monthly (PLAN.md §8).

calc_affordable_sales <- function(
    data,
    input_col,
    dwn_opts        = c(0.03, 0.10, 0.20),
    int_rate        = .int_rate_default,
    tax_ins_monthly = .tax_ins_monthly
) {
  data <- data |>
    mutate(
      .ho_monthly = (!!sym(input_col) * 0.28 / 12) - tax_ins_monthly,
      .pv_base    = abs(pv(int_rate / 12, 360, 0, .ho_monthly, 0))
    )
  for (dwn in dwn_opts) {
    col  <- paste0("affordable_sales_", dwn)
    data <- data |> mutate("{col}" := .pv_base * (1 - dwn))
  }
  select(data, -.ho_monthly, -.pv_base)
}

## 3. calc_income_needed ----
## Returns annual income needed to afford avg_rent_col (renter) and med_price_col (buyer).
## renter_income and buyer_income are numeric (renter_income was a formatted string in faar).

calc_income_needed <- function(
    data,
    med_price_col,
    avg_rent_col,
    int_rate        = .int_rate_default,
    down_pct        = 0.05,
    tax_ins_monthly = .tax_ins_monthly
) {
  calc_buy_income <- function(med_price) {
    principal <- med_price - (med_price * down_pct)
    loan_amt  <- principal / (1 - 0.015)  # 1.5% closing costs rolled into loan
    payment   <- abs(pmt(int_rate / 12, 360, loan_amt, 0)) + tax_ins_monthly
    (payment / 0.28) * 12
  }

  data |>
    mutate(
      renter_income = (!!sym(avg_rent_col) / 0.30) * 12,
      buyer_income  = calc_buy_income(!!sym(med_price_col))
    )
}
