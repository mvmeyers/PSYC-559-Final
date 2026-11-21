# 01_clean_daily.R
# Builds the shared daily table: one row per person per day, ALL 16,346 days
# (play and non-play days), recoded to the types the variables really are.
#
# Input:  data/openesm_0075.rds  (from 00_download.R)
# Output: data/daily_clean.rds
#
# This script only recodes. It does not choose a target, drop rows with a
# missing target, build lags, impute, or split the data. Those choices belong
# to the analysis script, because they depend on the research question.
# See README.md for the variable list and the decisions made here.

library(dplyr)
library(here)

raw <- readRDS(here("data", "openesm_0075.rds"))$data

# Checks that this is the expected file: one row per person per day
stopifnot(nrow(raw) == 16346,
          n_distinct(raw$id) == 1284,
          !anyDuplicated(raw[c("id", "day")]))


# 1. Fix the swapped stress ratings ------------------------------------------
# In the source data the "health" and "other" severity ratings are stored in
# each other's columns: every day with the health box checked has a rating in
# how_stressful_other and none in how_stressful_health, and the reverse holds
# for the "other" box. (Same in the authors' Zenodo release.) Swap them back.
crosstab <- c(
  health_checked_other_rated = sum(!is.na(raw$stress_events_health) & !is.na(raw$how_stressful_other)),
  health_checked             = sum(!is.na(raw$stress_events_health)),
  other_checked_health_rated = sum(!is.na(raw$stress_events_other) & !is.na(raw$how_stressful_health)),
  other_checked              = sum(!is.na(raw$stress_events_other))
)
print(crosstab)
stopifnot(crosstab[1] == crosstab[2], crosstab[3] == crosstab[4])

raw <- raw %>%
  rename(how_stressful_health = how_stressful_other,
         how_stressful_other  = how_stressful_health)


# 2. Recode -------------------------------------------------------------------
yes_no <- function(x) factor(x, levels = c("No", "Yes"))

# A checkbox holds its label when checked and NA when not. On days the
# question was not shown (no play / no stress), unchecked means "No".
# `asked` is TRUE when shown, FALSE when skipped by design, NA when the gate
# question itself is missing.
checkbox <- function(x, asked) {
  factor(ifelse(is.na(asked), NA, ifelse(!is.na(x), "Yes", "No")),
         levels = c("No", "Yes"))
}

social_cols <- c("social_singleplayer", "social_friends_realworld",
                 "social_friends_online", "social_strangers")
event_cols  <- grep("^stress_events_", names(raw), value = TRUE)
sev_cols    <- grep("^how_stressful_", names(raw), value = TRUE)
sev_levels  <- c("No event", "Not at all", "Not very", "Somewhat", "Very")

daily <- raw %>%
  mutate(
    played24hr = yes_no(played24hr),
    had_stress = yes_no(had_stress),

    # Who they played with: recode checkboxes to No/Yes. Days without play are
    # "No" for every box. The few play days with no box checked are NA
    # (everyone who played played with someone or alone).
    no_social_box = rowSums(!is.na(across(all_of(social_cols)))) == 0,
    across(all_of(social_cols),
           ~ checkbox(.x, asked = played24hr == "Yes")),
    across(all_of(social_cols),
           ~ replace(.x, played24hr == "Yes" & no_social_box, NA)),

    # One summary of the social context, with its own level for non-play days
    play_context = case_when(
      played24hr == "No" ~ "Did not play",
      social_strangers == "Yes" &
        (social_friends_realworld == "Yes" | social_friends_online == "Yes") ~ "Friends + strangers",
      social_strangers == "Yes" ~ "Strangers only",
      social_friends_realworld == "Yes" | social_friends_online == "Yes" ~ "Friends only",
      social_singleplayer == "Yes" ~ "Solo only"),
    play_context = factor(play_context,
                          levels = c("Did not play", "Solo only", "Friends only",
                                     "Friends + strangers", "Strangers only")),

    # Platform of the most recent session, grouped. Typed "Other" answers
    # (PC, laptop, Chromebook...) stay in "Other".
    platform = case_when(
      played24hr == "No" ~ "Did not play",
      most_recent_game_plat == "Steam"       ~ "Steam",
      most_recent_game_plat == "Xbox"        ~ "Xbox",
      most_recent_game_plat == "Playstation" ~ "PlayStation",
      grepl("^Nintendo", most_recent_game_plat) ~ "Nintendo",
      most_recent_game_plat %in% c("iOS", "Android", "AMAZON TABLET") ~ "Mobile",
      !is.na(most_recent_game_plat) ~ "Other"),
    platform = factor(platform, levels = c("Did not play", "Steam", "Xbox",
                                           "PlayStation", "Nintendo",
                                           "Mobile", "Other")),

    # Stress event types: No/Yes. Days with had_stress = "No" are "No" for
    # every type.
    any_event_box = rowSums(!is.na(across(all_of(event_cols)))) > 0,
    across(all_of(event_cols), ~ checkbox(.x, asked = had_stress == "Yes")),
    # had_stress = "Yes" but no type checked (3 days): types unknown
    across(all_of(event_cols),
           ~ replace(.x, had_stress == "Yes" & !any_event_box, NA)),
    n_stress_events = rowSums(across(all_of(event_cols), ~ .x == "Yes")),

    # Severity (1-4 in the source) as an ordered factor with a "No event"
    # level below "Not at all". Four response options, so ordered factor,
    # not numeric.
    worst_raw = suppressWarnings(
      do.call(pmax, c(across(all_of(sev_cols)), na.rm = TRUE))),
    across(all_of(sev_cols),
           ~ factor(ifelse(is.na(had_stress), NA,
                           ifelse(is.na(.x), 0, .x)),
                    levels = 0:4, labels = sev_levels, ordered = TRUE)),
    across(all_of(sev_cols),
           ~ replace(.x, had_stress == "Yes" & !any_event_box, NA)),
    stress_worst = factor(case_when(
      had_stress == "No"  ~ 0,
      had_stress == "Yes" ~ worst_raw),    # NA if "Yes" but nothing rated
      levels = 0:4, labels = sev_levels, ordered = TRUE),

    # Type of day. Holiday and vacation day are both small (2-3% of days) and
    # both mean a weekday off, so they are combined.
    day_type = factor(day_type,
                      levels = c("Regular work day", "Regular day off", "Weekend",
                                 "Holiday", "Vacation day", "Other (please specify):"),
                      labels = c("Work day", "Day off", "Weekend",
                                 "Holiday or vacation", "Holiday or vacation", "Other"))
    # Numeric items kept as numbers: gaming_* and needs_* (1-7),
    # sleep_quality (1-5), affective_valence and life_satisfaction (0-100).
    # All are inside their scale ranges, so there are no placeholder codes.
  )

# Event types whose severity box was checked must have a severity rating
for (e in sub("stress_events_", "", event_cols)) {
  sev <- if (e == "home") "how_stressful_home_issue" else paste0("how_stressful_", e)
  stopifnot(all((daily[[paste0("stress_events_", e)]] == "Yes") ==
                  (daily[[sev]] > "No event"), na.rm = TRUE))
}


# 3. Day index helper for lags -------------------------------------------------
# `day` counts calendar days from the person's first diary day (a gap in `day`
# always equals the gap in calendar dates), so a lag is valid only when
# days_since_prev == 1. See lag_within_person() in scripts/functions.R.
daily <- daily %>%
  arrange(id, day) %>%
  group_by(id) %>%
  mutate(days_since_prev = day - lag(day),
         n_days_person   = n()) %>%
  ungroup()


# 4. Keep the variables ---------------------------------------------------------
# Dropped: bookkeeping (date, beep, baseline_day, ideal_baseline_day, n_valid,
# original_wave, survey_duration), the attention-check and duplicate-item
# columns (bpnsfs_dup_item, bpnsfs_dup_score, bpnsfs_failed_att_check), free
# text (most_recent_game, displaced_activity), most_recent_game_plat (replaced
# by platform), and the helper columns made above.
daily <- daily %>%
  select(
    id, day, days_since_prev, n_days_person,
    # outcomes / day-level ratings
    affective_valence, life_satisfaction, sleep_quality,
    day_type,
    # play
    played24hr, starts_with("gaming_"), all_of(social_cols), play_context, platform,
    # needs (all days)
    starts_with("needs_"),
    # stress
    had_stress, all_of(event_cols), n_stress_events, all_of(sev_cols), stress_worst
  )


# 5. Report and save --------------------------------------------------------------
cat("\nRows:", nrow(daily), " People:", n_distinct(daily$id),
    " Columns:", ncol(daily), "\n")
cat("Consecutive rows that skip at least one day:",
    round(100 * mean(daily$days_since_prev > 1, na.rm = TRUE), 1), "%\n\n")

pct_missing <- sort(round(100 * colMeans(is.na(daily)), 1), decreasing = TRUE)
print(pct_missing[pct_missing > 0])

saveRDS(daily, here("data", "daily_clean.rds"))
cat("\nSaved data/daily_clean.rds\n")
