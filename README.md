# PSYC 559 Final Project, Group 1: Open Play daily diary

The analysis code and data for the final project. The data are the Open Play
daily diary, **openESM dataset 0075** (Ballou et al., 2025): 1,284 adult
video game players, one survey a day for up to 30 days, 16,346 person-days.

**Research question:** how well can same-day predictors and intake
demographics predict a player's daily **life satisfaction** on days they
played? The analysis also adds K-means types of play days, built from the
BANGS items, and PCA dimensions of the daily needs items.

- How we made each choice, and how to read each result: [`DECISIONS.md`](DECISIONS.md).
- The final model: the elastic net on feature set B. Test RMSE 14.79, R²
  .575, MAE 11.12.

## Quick start

1. Clone the repo and open `psyc559-final-group1.Rproj`.
2. Install the packages once:

   ```r
   install.packages(c("openesm", "dplyr", "tidyr", "ggplot2", "naniar",
                      "rsample", "recipes", "cluster", "caret", "glmnet",
                      "ranger", "doParallel", "rmarkdown"))
   ```

3. Open `final_project.Rmd` and click **Knit**. Or, from the R console:

   ```r
   rmarkdown::render("final_project.Rmd")
   ```

It knits in about 2 minutes on a laptop. It does not refit any model,
because the fitted models are saved in `output/model_fits/` and the Rmd
reads them. No other script has to run first, and no internet connection is
needed (the data are in `data/`).

**For group members: knit it as it is.** Don't change the two switches at
the top of the Rmd (below). With them as they are, your knit reads the saved
fits and gives exactly the numbers in the report. Check that your HTML shows
test RMSE 14.79, R² .575, and MAE 11.12.

- Don't set `refit_models <- TRUE` to "check" the file. It takes about 1.5
  hours and **overwrites the saved fits** in `output/model_fits/`. Only the
  one clean knit for submission refits (see "When to refit" below), and
  one person runs it.
- Don't commit a changed `output/model_fits/` folder unless the group agreed
  on that refit. A knit with the saved fits only rewrites
  `output/final_results.rds` and `final_project.html`, and both should come
  out the same.

## The one file

`final_project.Rmd` is the whole analysis, from the downloaded data to the
test set:

1. It reads the saved diary and cleans it (the `clean-daily` chunk).
2. It builds the play-day table and joins the intake demographics.
3. It splits by person, then fits the clustering and the PCA on the training
   days.
4. It fits every model on feature sets A and B and chooses the final model.
5. It evaluates that model once on the test set and saves the results.

It reads only the files in `data/`. It writes its results to `output/` and
the knitted `final_project.html` next to the Rmd.

### Two switches at the top

| Switch | Now | What it does |
|---|---|---|
| `run_test_set` | `TRUE` | Runs the test-set chunks (Section 9). The test set was opened once, on 2026-11-25, after the final model was chosen. Leave it `TRUE`. |
| `refit_models` | `FALSE` | `FALSE` reads the saved fits. `TRUE` refits every model and overwrites `output/model_fits/`. |

### When to refit

- **Editing text, tables, or plots:** leave `refit_models <- FALSE`. Nothing
  is refit.
- **Changing anything before Section 8** (the data, the clustering, the PCA,
  the recipes, the grids): set `refit_models <- TRUE`.
- **The knit that is submitted:** the handout says "Cache while drafting…
  and knit clean before submitting." Our saved fits work like a cache, so
  the submitted HTML should come from one clean knit with
  `refit_models <- TRUE`. Set it back to `FALSE` afterwards. The fits are
  exactly reproducible (seed 559 and a fixed `seeds` list), so the clean knit
  should give the same numbers.
- **How long a refit takes:** about 1.5 hours on a laptop. The 10 folds run
  in parallel, on all but two of the computer's cores.
- **The handout also says** "Everyone should run the full code once before
  it is submitted." With the saved fits, that is a few minutes.

### Package versions

The results were produced with **R 4.6.1 on Windows 11** and these package
versions: caret 7.0-1, glmnet 5.1, ranger 0.18.0, recipes 1.4.0,
rsample 1.3.2, cluster 2.1.8.2, doParallel 1.0.17, dplyr 1.2.1,
tidyr 1.3.2, ggplot2 4.0.3, naniar 1.1.0, openesm 0.2.1,
rmarkdown 2.32. The full list is in Section 12 (Software) of the knitted
HTML, from `sessionInfo()`.

- **Knitting with the saved fits:** different package versions should not
  change any number, because nothing is refit.
- **Refitting:** the seeds make a refit reproduce exactly *on the same
  setup*. That was checked on one computer (the versions above). A
  different R or package version, especially of ranger, glmnet, caret, or
  recipes, could shift the numbers slightly. Whoever runs the submission
  refit should compare its tables with the current `final_project.html`. If
  anything differs, tell the group before anyone writes numbers into the
  report.

## Folder layout

```
final_project.Rmd        the whole analysis: all the code (knit this)
final_project.html       the knitted Rmd: read the results without knitting
DECISIONS.md             every choice beyond the walkthroughs, and how to read the results
data/
  openesm_0075.rds       get_dataset("0075") output, saved once (data + metadata).
                         If it is missing, the Rmd downloads it (needs the internet)
  survey_intake.csv.gz   Open Play intake survey (demographics), from the Open Play repository
  game_classification.csv, game_classification_excluded.csv
                         hand-reviewed game genre lookup
  codebook_0075.csv      the codebook from the metadata, saved for reading (the Rmd uses the metadata)
output/
  final_results.rds      every table and number the report needs
  model_fits/            the saved train() fits (null, glmnet_A/B, rf_A/B, and the check_* fits
                         for the K and PC sensitivity checks)
```

The Rmd is the only code. The group's earlier cleaning scripts and their
output (`daily_clean.rds`) were folded into it and removed. They are still
in the git history.

## The analysis in brief

| Step | What | Details |
|---|---|---|
| Rows | 12,407 play days with gaming answers and a target, 1,169 people | Section 3 of the Rmd |
| Target | `life_satisfaction`, 0 to 100 ("I was satisfied with my life today") | `affective_valence` is excluded (r = .87 with the target) |
| Split | By person, 70/30, stratified by each person's mean life satisfaction | ICC = .73. Training: 8,677 days, 814 people. Test: 3,730 days, 355 people |
| Folds | 10 grouped folds (by person) | The same folds for every model |
| Clusters | K-means, K = 3, on the six BANGS items | Connected, Frustrating, and Smooth solo play days |
| Components | PCA on the six daily needs items, two varimax-rotated components | `need_satisfaction` and `need_frustration` |
| Set A | Shared predictors + the six raw needs items | 32 predictors |
| Set B | Shared predictors + the two components + the play-day type | 29 predictors |
| Models | Null, elastic net (`glmnet`), random forest (`ranger`), each on A and B | As in walkthrough Part 3 |
| Final model | Elastic net, set B | Lowest CV RMSE (14.63), and the simplest candidate |

The full reasoning, the sensitivity checks (K = 2 and 4; 1 and 3
components), the missing-data rules (KNN in the models, the median in the
clustering and PCA blocks), and the 2 SE rule are in
[`DECISIONS.md`](DECISIONS.md).

## Data source and license

Ballou, N., Földes, T. A., Vuorre, M., Hakman, T., Magnusson, K., &
Przybylski, A. K. (2025). *Open Play: A longitudinal dataset of multi-platform
video game digital trace data and psychological measures*. PsyArXiv.
<https://doi.org/10.31234/osf.io/nz96c_v1>. Retrieved through openESM
(Siepe et al., 2026; <https://openesmdata.org>). The intake survey comes
from <https://github.com/digital-wellbeing/open-play>.

License: CC0 1.0 with one added condition (Section 5 of the `LICENSE` file
in the Open Play repository): **do not attempt to re-identify participants**,
link the data to specific individuals, or share derived data in a way that
could enable re-identification. Otherwise, CC0 allows copying and
redistributing the data, so this repo does not have to be private.
