# PSYC 559 Final Project, Group 1: Open Play daily diary

Shared data and cleaning code for the final project. The data are the Open
Play daily diary, **openESM dataset 0075** (Ballou et al., 2025): 1,284 adult
video game players, one survey a day for up to 30 days, 16,346 person-days.

## Quick start

1. Clone the repo and open the folder as an R project (`psyc559-final-group1.Rproj`),
   so `here::here()` finds the repo root.
2. Install packages: `install.packages(c("dplyr", "here", "openesm"))`.
3. Load the clean table:

   ```r
   library(here)
   daily <- readRDS(here("data", "daily_clean.rds"))
   source(here("R", "functions.R"))   # lag_within_person()
   ```

Both data files are already committed, so you do not need to run the scripts
to start. Run them to rebuild from scratch.

## Run order

| Step | Script | Reads | Writes |
|---|---|---|---|
| 0 | `R/00_download.R` | openESM (network) | `data/openesm_0075.rds`, `data/codebook_0075.csv` |
| 1 | `R/01_clean_daily.R` | `data/openesm_0075.rds` | `data/daily_clean.rds` |
| — | `R/functions.R` | — | helpers, sourced by later scripts |

Run each from the repo root, for example `Rscript R/01_clean_daily.R`. Step 0
needs the internet and is only needed if the saved file is missing. The
analysis (split, recipes, clustering, PCA, models) will go in later numbered
scripts or one `.Rmd`.

## Folder layout

```
data/
  openesm_0075.rds     get_dataset("0075") output, saved once (data + metadata)
  codebook_0075.csv    codebook from the metadata element
  daily_clean.rds      the shared daily table (built by 01_clean_daily.R)
R/
  00_download.R
  01_clean_daily.R
  functions.R
```

## The clean table (`daily_clean.rds`)

One row per person per day, **all 16,346 days**, play days and non-play days
alike. 44 columns. It is recoded only: no target has been chosen, no rows are
dropped, nothing is imputed, and there is no train/test split. Those depend on
the research question and happen in the analysis code.

| Variable(s) | Type | Notes |
|---|---|---|
| `id` | text | participant ID |
| `day` | number 1–30 | calendar day of the study for that person |
| `days_since_prev` | number | days since this person's previous row (NA on their first row). 1 = consecutive |
| `n_days_person` | integer | number of days this person answered |
| `affective_valence` | number 0–100 | "How are you feeling right now?" |
| `life_satisfaction` | number 0–100 | "I was satisfied with my life today." |
| `sleep_quality` | number 1–5 | very poor to very good, last night |
| `day_type` | factor | Work day, Day off, Weekend, Holiday or vacation, Other |
| `played24hr` | factor No/Yes | played in the last 24 hours |
| `gaming_autonomy`, `gaming_wish_else`, `gaming_progress`, `gaming_disappointed`, `gaming_relationships`, `gaming_toxic` | number 1–7 | session items (BANGS). **NA on non-play days** (see below) |
| `social_singleplayer`, `social_friends_realworld`, `social_friends_online`, `social_strangers` | factor No/Yes | who they played with. "No" on non-play days |
| `play_context` | factor | Did not play, Solo only, Friends only, Friends + strangers, Strangers only |
| `platform` | factor | Did not play, Steam, Xbox, PlayStation, Nintendo, Mobile, Other |
| `needs_*` (6 items) | number 1–7 | autonomy, competence, relatedness, each satisfied and frustrated. Asked every day |
| `had_stress` | factor No/Yes | any stressful event in the last 24 hours |
| `stress_events_*` (7 types) | factor No/Yes | argument, discrimination, friend_rel, health, home, other, work_school. "No" when `had_stress` is No |
| `n_stress_events` | number 0–7 | count of event types checked |
| `how_stressful_*` (7 types) | ordered factor | No event < Not at all < Not very < Somewhat < Very |
| `stress_worst` | ordered factor | highest severity that day, same levels |

The full item wording is in `data/codebook_0075.csv` and at
<https://github.com/digital-wellbeing/open-play/blob/main/codebook.xlsx>.

## What the cleaning script does

- **Skip-pattern blanks recoded, not imputed.** The social-play checkboxes are
  "No" on days without play, and the stress type and severity items are
  "No" / "No event" on days without a stressful event, as the project
  directions say.
- **Checkboxes to factors.** A checked box holds its label and an unchecked box
  is blank in the source, so each becomes No/Yes.
- **Ordinal coding rule.** Items with 5 or more response options are numeric
  (1–7 items, `sleep_quality` 1–5, 0–100 sliders). Stress severity has only 4
  options, so it is an ordered factor.
- **Holiday + Vacation day combined** in `day_type` (each is 2–3% of days).
- **Fixed swapped columns.** In the source data, the severity ratings for the
  "health" and "other" stress events are in each other's columns (every health
  event has its rating in `how_stressful_other`, and the reverse holds). The
  script swaps them back and checks the result. The authors' Zenodo release has
  the same swap.
- **Dropped:** bookkeeping columns (`date`, `beep`, `baseline_day`,
  `ideal_baseline_day`, `n_valid`, `original_wave`, `survey_duration`), the
  attention-check and duplicate-item columns, and free text
  (`most_recent_game`, `displaced_activity`). `most_recent_game_plat` is
  replaced by `platform`.

## Things to decide as a group

- **Session items on non-play days.** The six `gaming_*` items are missing on
  about 24% of days because they were only asked after play. They cannot be
  recoded to zero (the scale is 1–7). Options: model play days only, or leave
  them out of an all-days model. Do not impute them.
- **Same day or previous day.** For previous-day predictors use
  `lag_within_person(daily, c("var1", "var2"))`. It sets the lag to NA when
  yesterday is missing (about 23% of consecutive rows skip a day), and it only
  looks backward.
- **Missing targets.** About 1.7% of days have no valence or life
  satisfaction, mostly near-empty surveys (about 260 rows). Drop rows with a
  missing target in the analysis script, not here.
- **Leakage.** If the target is in an item block (for example a `needs_*`
  item), leave it out of that block before clustering or PCA.
- **Extra data.** The intake survey and platform play logs at
  <https://github.com/digital-wellbeing/open-play> use the same IDs (about 95%
  of diary participants have an intake record) if we want person traits or
  logged play time.

## Data source and license

Ballou, N., Földes, T. A., Vuorre, M., Hakman, T., Magnusson, K., &
Przybylski, A. K. (2025). *Open Play: A longitudinal dataset of multi-platform
video game digital trace data and psychological measures*. PsyArXiv.
<https://doi.org/10.31234/osf.io/nz96c_v1>. Retrieved through openESM
(Siepe et al., 2026; <https://openesmdata.org>).

License: CC0 1.0, modified. See the conditions in the Open Play repository.
**Do not attempt to re-identify participants.** Keep this repo private.
