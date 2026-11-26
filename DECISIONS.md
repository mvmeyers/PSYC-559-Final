# Analysis decisions and how to read the results

This file lists every choice in `final_project.Rmd` that goes beyond the
course walkthroughs (Parts 1 to 3) or the handout's defaults, with the reason,
and how we read each result. Use it when writing the report and the slides.

Every number below comes from the knitted Rmd (saved in
`output/final_results.rds`). If a number here ever disagrees with the knit,
the knit is right and this file needs updating.

**Contents**

1. [The result in brief](#1-the-result-in-brief)
2. [Data and coding](#2-data-and-coding)
3. [Missing data: KNN in the models, the median in the blocks](#3-missing-data-knn-in-the-models-the-median-in-the-blocks)
4. [Split and folds](#4-split-and-folds)
5. [Clustering: types of play days (K = 3)](#5-clustering-types-of-play-days-k--3)
6. [PCA: dimensions of a day (two components)](#6-pca-dimensions-of-a-day-two-components)
7. [Feature sets and leakage](#7-feature-sets-and-leakage)
8. [Models and tuning](#8-models-and-tuning)
9. [Choosing the final model: the 2 SE rule](#9-choosing-the-final-model-the-2-se-rule)
10. [The test set](#10-the-test-set)
11. [What the results mean](#11-what-the-results-mean)
12. [Reproducibility](#12-reproducibility)

---

## 1. The result in brief

- **Target:** daily life satisfaction ("I was satisfied with my life today,"
  0 to 100), on play days only.
- **Predictors:** same-day items plus intake demographics.
- **Final model:** the **elastic net on feature set B**. It had the lowest
  cross-validated RMSE and is also the simplest candidate.
- **Feature sets:** set B (the two need components and the play-day type)
  did as well as set A (the six raw needs items) for every model.

| | Cross-validated (10 folds) | Test (3,730 days, 355 people) |
|---|---|---|
| RMSE | 14.63 | 14.79 |
| R² | .623 | .575 |
| MAE | 11.12 | 11.12 |
| Null model RMSE | 24.10 | 22.43 |

All three test values fall inside the range of the 10 folds (RMSE 12.81 to
16.57, R² .542 to .757, MAE 9.68 to 12.06), so the cross-validated estimate
held up on people the model never saw.

---

## 2. Data and coding

| Decision | What we did | Why |
|---|---|---|
| One file | All the code is in the Rmd. The group's earlier cleaning script is now its `clean-daily` chunk; it was checked to give the same table, minus two lag helper columns that nothing used, and the old script and its output were then removed. | The handout asks for one `.Rmd` that knits from the downloaded data. |
| Play days only | 16,346 diary days → 12,435 play days → 12,407 with gaming answers and a target (1,169 people). | The BANGS items exist only on play days. The proposal is about play days. |
| Days with no answer to the play question | Dropped with the non-play days (271 days). | Nearly all are empty surveys: 248 of the 271 have no life satisfaction rating either. |
| The 0, 50, and 100 slider values | Kept as real answers. Nothing in the target is recoded. | The histogram is in Section 4 of the Rmd. |
| `affective_valence` is not a predictor | Removed. | r = .87 with life satisfaction, answered in the same sitting: it is the target in another form. |
| Swapped stress columns fixed | The "health" and "other" severity ratings sit in each other's columns in the source. The Rmd checks this and swaps them back. | Every day with a health event has its rating in `how_stressful_other`, and the reverse holds. |
| 16 play days with no gaming answers dropped | These days have no title, no social box, no platform, and no BANGS item (4 of them had a target). | Every gaming predictor would be imputed. A blank title would be coded "Unclassified" and the missing context would read as solo. |
| **Solo days: the person's answer wins** | On a day the person answered "Single-player games only," every game that day is coded single-player, whatever its genre in our lookup. | **This reasoning must be in the report.** We trust how people described their own session over our classification of the title. A "multiplayer" game (Call of Duty, Mario Kart, Minecraft) can be played solo, and only the person knows which mode they played. The BANGS items describe how the session felt, so they must be read in the context the person reported. We do not overrule what people said in the survey. |
| Effect of the solo rule | Of 5,391 solo days, 899 lose a competitive or co-op code and 1,068 unclassifiable titles become single-player. | Game type and play context now overlap on solo days by design, so read their importance together. |
| Single-player games on days with other players | Kept as coded (834 days). | Not a contradiction: the play context covers the whole day, while the game type describes only the most recent session. |
| Solo days kept | All play days are kept, not only multiplayer days. | The proposal commits to all play days and predicted a "satisfying solo session" type, which the clustering found. |
| "Unknown" game type | 34 days (0.3%) stay "Unknown": unreadable titles, and multi-game answers whose codes disagree. | Any code would be a guess. |
| Stress coding | Includes `had_stress`, 7 event types, and `stress_worst` as an ordered factor (None < Not very < Somewhat < Very). The 2 "Not at all" days are merged into "Not very". | Two days cannot support a level of their own, and "Not very" is the nearest level. |
| Ordinal rule | Items with 5 or more response options are numeric. Fewer options make an ordered factor. | A 4-option scale has too few levels to treat as numeric. |
| Demographics | Age, gender, employment, education, relationship status, and caring for children. Neurodivergence is not used. | These are the variables listed in the proposal. |

---

## 3. Missing data: KNN in the models, the median in the blocks

The walkthrough imputes medians and modes. We used these rules
instead:

| What is missing | Variables | How it is filled | Where | Why |
|---|---|---|---|---|
| The target | life satisfaction | The row is dropped (12 days) | Before the split | A missing target cannot be scored |
| A categorical intake answer | gender, employment, relationship, cares for children | Its own **"Not reported"** level | Before the split | Declining may depend on the answer (MNAR), and the level keeps that information |
| A numeric intake answer | age, education | **Training median** | Model recipe | Person-level facts, so every day of a person gets the same value |
| A daily answer in the models | BANGS, needs items (set A), sleep, day type, platform, stress items | **KNN, 5 neighbors**, from the other predictors (never the target) | Model recipe, relearned in each fold | Unfinished surveys (MCAR) and the platform question added partway through the study (MAR). Each daily item other than platform is missing on 11 play days or fewer (0.1%). |
| A daily answer in the clustering or PCA block | the 6 BANGS items, the 6 needs items | **Training median** | Before K-means and PCA | See below |

**Why the median, and not KNN, inside the blocks:**

- K-means and PCA cannot run with gaps, and they run once, before any model.
- A day missing one item of a block is missing all six. KNN inside the block
  would have no answers to match on.
- Bringing in predictors from outside the block would build the clusters
  and components partly from other variables.
- **Cost:** very small. Every filled day gets the same values. Only 1
  training day and 2 test days are filled for BANGS, and 3 training days
  (0 test days) for the needs items.

**Why platform is MAR.** Platform is missing almost entirely in the first
months of the study, so whether it is missing depends on *when* someone took
part, which is observed. It does not mark a different kind of day: mean life
satisfaction is 67.3 on days with platform missing and 66.1 on days with it
recorded.

**Intake missingness:** 46 people have no intake record, which is close to
MCAR (most likely a gap in linking the two surveys). Only a few people
declined a question: gender 1, employment 1, education 3, relationship 9,
children 12. So the part that could be MNAR is small. Only the 3 people who
declined education are filled (median) without a "Not reported" marker.

**A side effect of KNN.** KNN fills each column on its own, so on an imputed
day the stress columns may disagree (for example, `had_stress` "No" with an
event type "Yes"). This can happen on at most 9 days.

**Platform is a stated limitation.** It is missing on 747 play days, mostly
early in the study, because the question was added later. KNN does not use
the person's own other days, even though people play on their usual platform
on 77% of days. Filling from the person's usual platform was considered and
rejected, so that platform is imputed like every other predictor (KNN inside
the folds).

---

## 4. Split and folds

| Decision | Walkthrough or handout | Ours | Why |
|---|---|---|---|
| Split | `initial_split()` by day | **`group_initial_split()` by person**: 70/30, strata = quartiles of each person's mean life satisfaction, seed 559 | ICC = **.73**: 73% of the variation in life satisfaction is between people. A day split puts the same person in both sets, so the model would learn each person's usual level and the test score would be too optimistic. |
| Sizes | | Training: 8,677 days, 814 people. Test: 3,730 days, 355 people. No person in both. | |
| Folds | 5 ("a classroom size; use ten in your report") | **10 grouped folds** (`groupKFold` by person) | The handout asks for ten in the report. The 2 SE rules depend on the spread of the fold differences, and 10 folds estimate that spread better than 5. |
| Seeds | `set.seed(559)` before each `train()` | Same, plus a `seeds` list in `trainControl()` | The folds run in parallel. The seeds list fixes the forests' random parts on every worker, so the results are identical with any number of cores. |

---

## 5. Clustering: types of play days (K = 3)

K-means on the six BANGS items, standardized, with 25 starts, fit on the
training days only. Test days get the nearest training centroid. The handout
says clusters are types of days, so each cluster is named as a **type of play
day**, defined by how that day's most recent session went.

**Choosing K.** Neither criterion is sharp:

| K | Silhouette | Within-cluster SS (share of K = 1) | Stability (mean adj. Rand, 20 resamples of 80% of people) | R² of life satisfaction on the types |
|---|---|---|---|---|
| 2 | **.292** | .716 | .970 | .090 |
| 3 | .218 | .620 | **.972** | .093 |
| 4 | .211 | .559 | .911 | .108 |

- **Why K = 3 although the silhouette prefers 2.** K = 2 only separates good
  play days from bad ones. K = 3 splits the good days by whether the person
  formed relationships while playing. That is the one BANGS item the others
  do not capture, and the split matters for life satisfaction (72.7 vs 65.3).
- **Why not K = 4.** K = 4 is a finer cut with no better silhouette, and it
  is less stable (minimum adjusted Rand .79, against .93 for K = 3).
- **How to read the silhouettes.** Values of .2 to .3 mean the types
  overlap. Play days vary continuously and do not fall into separate groups.
  Say this in the report.

**The three types** (training days; item means on the 1 to 7 scale):

| Type | Days | Autonomy | Wish to do else | Progress | Disappointed | Relationships | Toxic | Mean life satisfaction |
|---|---|---|---|---|---|---|---|---|
| Connected play day | 3,986 (46%) | 6.2 | 1.7 | 6.0 | 1.7 | 5.1 | 1.7 | 72.7 |
| Frustrating play day | 2,654 (31%) | 4.6 | 3.7 | 4.3 | 3.7 | 3.4 | 3.2 | 55.5 |
| Smooth solo play day | 2,037 (23%) | 6.0 | 1.9 | 5.6 | 1.7 | 1.5 | 1.3 | 65.3 |

The types are named by rules on the centroids, so the names do not depend on
the cluster numbers. The K = 2 and K = 4 types are named the same way.

**What the types are** (use these descriptions in the report):

- **Smooth solo play day.** The person played the way they wanted and made
  progress, with little disappointment and almost no toxicity, but formed no
  relationships. Most of these days were solo, single-player play.
- **Connected play day.** The gaming went just as smoothly, and the person
  also formed relationships. These days are split between solo play and play
  with friends. The item asks about players *or characters*, so a story game
  can count.
- **Frustrating play day.** Lower autonomy and progress, more wishing to do
  something else, disappointment, and toxicity. Team competition and
  strangers-only play are more common than on the other types.

**Compared with the proposal.** The proposal expected days built around a
"toxic competitive session," a "low improvement session," and a "satisfying
solo session."

- The satisfying solo type appears.
- The other two appear together, as the one frustrating type. It leans
  toward competitive play but is not defined by it. Toxicity is only
  moderate even there (mean 3.2, below the scale's midpoint).
- At K = 4 the frustrating days split into a **toxic social** and a
  **stalled** type, close to the proposal's two. But K = 4 is less stable and
  has no better silhouette (see above), so we keep K = 3. Say this in the
  report.

**The types and life satisfaction.** The type is clearly related to that
day's life satisfaction, although no BANGS item asks about life. Frustrating
play days are lowest and connected play days highest. The spread within each
type is wide. These are same-day associations: a bad day may make the gaming
feel worse as much as the other way around. The types also line up with the
components: frustrating play days are lower on need satisfaction and higher
on need frustration.

**Sensitivity check: does the choice of K matter for prediction?** No. We
refit the final model (elastic net, set B) with the type from K = 2, 3, or 4,
and with no type at all:

| Variant | CV RMSE | Chosen − variant | 2 SE | Folds where the variant is better |
|---|---|---|---|---|
| No play-day type | 14.627 | +0.002 | 0.021 | 5 of 10 |
| K = 2 | 14.632 | −0.003 | 0.011 | 4 |
| **K = 3 (chosen)** | 14.629 | | | |
| K = 4 | 14.633 | −0.004 | 0.016 | 3 |

Every difference is far inside 2 SE. The elastic net set both K = 3 type
columns to zero. **How to read it:** the play-day type adds nothing on top of
the six BANGS items it was built from, because both feature sets keep those
items. The types are useful for *describing* days, not for improving the
prediction. The handout requires cluster membership in set B, so it stays.

---

## 6. PCA: dimensions of a day (two components)

PCA on the six daily needs items (satisfaction and frustration of autonomy,
competence, and relatedness), standardized and fit on the training days.
Test scores use the training weights, rotation, and sign flip.

**How many components.** We used only the rules from the course (the PCA
lecture, the walkthrough, and the handout):

| Rule | Components kept |
|---|---|
| Scree plot | 1 (58.6% for component 1, then 13.1%, then flat) |
| Eigenvalue ≥ 1 (lecture) | 1 |
| Eigenvalue ≥ 0.75 (walkthrough) | **2** (the second eigenvalue is 0.78) |
| 80% of the variance | 3 (two components explain 71.7%, three 81.3%) |
| Parallel analysis (handout) | 1 (0.78 is below the random cutoff of 1.03) |
| Theory (self-determination theory) | **2**: need satisfaction and need frustration |

Parallel analysis and the eigenvalue rule at 1 are close to the same test
here, so in the report count them as one piece of evidence, not two.
Parallel analysis replaces the fixed cutoff of 1 with the eigenvalues of
random data of the same size. With 8,677 days and 6 items those barely
stray from 1 (cutoff 1.03 for the second component). The two rules part ways
only when the sample is small or the items are many.

**Why two.** Theory and the walkthrough's cutoff both say two. The proposal
predicted exactly these two dimensions. A second component also carries the
frustration items much better: communality of autonomy frustration is .43
with one component and .71 with two.

**Rotation.** We used varimax, as in walkthrough Part 2, and flipped the
signs so that high scores mean more of the named thing. The rotated loadings
are clean:

| Item | need_satisfaction | need_frustration |
|---|---|---|
| autonomy satisfied | **.86** | −.28 |
| competence satisfied | **.85** | −.28 |
| relatedness satisfied | **.76** | −.27 |
| autonomy frustrated | −.15 | **.83** |
| competence frustrated | −.46 | **.67** |
| relatedness frustrated | −.31 | **.76** |

**Sensitivity check: does the number of components matter for prediction?**

| Variant | CV RMSE | Chosen − variant | 2 SE | Reading |
|---|---|---|---|---|
| One component | 14.872 | −0.243 | 0.130 | **Worse, beyond noise**: two components win in 9 of 10 folds |
| **Two (chosen)** | 14.629 | | | |
| Three components | 14.615 | +0.014 | 0.040 | No gain |
| Six raw needs items | 14.650 | −0.021 | 0.057 | Same as two components |
| No needs items at all | 19.089 | −4.459 | 0.972 | Much worse: CV R² falls from .623 to .371. The needs carry most of the prediction |

**Caveats for the report:**

- Satisfaction and frustration go together in the data: the item
  correlations range from −.36 to −.59. The rotated scores are uncorrelated
  only because varimax is an orthogonal rotation.
- A third component would be mostly relatedness (relatedness frustration
  loads .85, relatedness satisfaction −.61; eigenvalue 0.58, 9.6% of the
  variance), but it adds nothing to the prediction.
- Autonomy and competence cannot be told apart: their satisfaction items
  correlate .75.
- **Compared with the proposal.** The proposal read two components as days
  differing "more in how fulfilling or frustrating they are overall rather
  than in which specific need is met." That reading holds, with one
  qualification: relatedness carries a little variance of its own.
- The components mix differences between people with day-to-day
  differences within a person.
- Call the components **dimensions of a day**. "Types of days" means the
  clusters.

---

## 7. Feature sets and leakage

**The two feature sets.** Both share every predictor outside the needs
block, **including the six BANGS items**.

| Set | Adds | Predictors |
|---|---|---|
| A | the six raw needs items | 32 |
| B | the two need components + the play-day type (a factor) | 29 |

The handout defines set B as the components plus cluster membership. Our
clustering block (the BANGS items) is not the PCA block, which the handout
allows, so the BANGS items stay in both sets. The A versus B comparison
therefore asks two questions: do two scores carry what the six needs items
carry, and does the play-day type add anything to the items it was built
from?

**Leakage we checked** (the report should list these):

| Risk | What we did |
|---|---|
| The target in another form | `affective_valence` removed (r = .87). |
| The needs items | **Kept**, as the proposal planned. They ask about the day's experiences, not about life satisfaction, but they are answered in the same sitting and need satisfaction correlates **.66** with the target. Much of the accuracy comes from them, and it describes what goes together on a day. It does not show that needs cause life satisfaction. |
| Blocks built from the target | None: neither block contains the target. |
| Lags | None built: every daily predictor is from the same day. |
| Repeated measures | The split and the folds hold out whole people. |
| Preprocessing | Imputation, dummies, and scaling are in recipes, relearned in each fold. The recoding in Section 3 of the Rmd learns nothing from the data. |
| Unsupervised structure | Fit on the training days only; the test days are scored from that fit. **One small limitation:** the centroids, component weights, and block medians were learned from all training days, so inside cross-validation the held-out fold helped shape them. They never use the target, and six items fit on about 8,700 days barely move when a tenth is held out, so the effect on the CV comparison should be negligible. The test set is untouched by this. |
| Information from the future | The intake survey came before every diary day: 0 training days fall before the person's intake (the gap is 4.9 to 192 days, median 42). |

---

## 8. Models and tuning

| Decision | Ours | Why |
|---|---|---|
| Models | Null, elastic net (`glmnet`), and random forest (`ranger`), each on sets A and B. | Exactly the walkthrough Part 3 set. |
| Gradient boosting | Tried, then **dropped**. | It is optional in the walkthrough, and it was not reproducible: gbm 2.3.1 gave slightly different results on each refit with the same seeds, even with serial folds. That is a package bug. The final model was never in question (gbm was 0.33 RMSE behind). |
| Elastic net grid | `alpha` 0, 0.25, 0.5, 0.75, 1 × a `lambda` grid. | Best values: A `alpha` = 0.25, `lambda` = 0.85; B `alpha` = 0.75, `lambda` = 0.31. Both are inside the grid. |
| Random forest grid | `mtry` from 2 to p, `min.node.size` 5, 20, 50, 100, 200, with 500 trees. | Widened after the first run's best values landed on the top edge. Best values: B `mtry` = 14, node size 50 (inside the grid); A `mtry` = 6, node size 5. |
| Forest node size at the edge (set A) | Kept at 5, the bottom of the grid and ranger's default for regression. | The RMSE barely changes from 5 to 50, and the forest is far enough behind the elastic net that smaller nodes would not change the ranking. |
| `respect.unordered.factors = "order"` | Set for ranger. | With ranger's default, an unordered factor splits only in its stored level order, so some groupings (such as Steam + Mobile against the rest) can never be tried. `"order"` finds the best split for a continuous target. |
| Recipes | Linear: median for age and education, KNN, dummies, drop zero-variance columns, standardize. Trees: the same without dummies or standardizing. | Everything is learned inside each fold. |

---

## 9. Choosing the final model: the 2 SE rule

The walkthrough says: "If the top ones are within noise of each other, say
so, then pick one and give the reason. Simpler is a legitimate reason." We
made "within noise" exact, and **fixed the rule before opening the test
set**:

1. Take the model with the lowest mean cross-validated RMSE.
2. For each other model, take its RMSE minus the best model's, **fold by
   fold** (all models share the same 10 folds). If the mean of those
   differences is no more than **2 SE**, the model is within noise. Here
   2 SE = 2 × SD of the differences / √10.
3. Of the models within noise, take the simplest. The order is: elastic net
   B < elastic net A < forest B < forest A. The elastic net is simpler than
   the forest, and set B has fewer columns than set A.

**The cross-validated table:**

| Model | Set | RMSE | R² | MAE |
|---|---|---|---|---|
| **Elastic net** | **B** | **14.629** | **.623** | **11.117** |
| Elastic net | A | 14.649 | .622 | 11.129 |
| Random forest | A | 14.839 | .621 | 11.394 |
| Random forest | B | 14.991 | .607 | 11.457 |
| Null | | 24.098 | | 19.293 |

The elastic net on set B is both the best and the simplest candidate, so the
rule picks it with no trade-off.

**Did set B help? (A − B, fold by fold; positive means B is better)**

| Model | A − B | 2 SE | Folds B better | Beyond noise? |
|---|---|---|---|---|
| Elastic net | +0.020 | 0.059 | 5 of 10 | No |
| Random forest | −0.152 | 0.183 | 2 of 10 | No |

**How to read it:** set B matches set A for both models. The two components
carry what the six needs items carry, in a third of the columns. Report it as
"no difference," not as "B is better."

---

## 10. The test set

- Opened **once**, on 2026-11-25, after the final model was fixed from the
  cross-validated table. **No modeling choice may change because of these
  numbers.**
- The test days get their play-day type from the nearest training centroid
  and their component scores from the training PCA. Nothing is refit on the
  test set.
- The results are in Section 1 above.
- **How to read them:**
  - Test RMSE 14.79 against 14.63 in CV; MAE identical. R² is lower (.575
    against .623) mostly because the test people vary less (the test SD is
    22.4 and the training SD is 24.2), not because the errors are larger.
  - The error is 34% smaller than the null model's.
  - A typical error is about 11 points on the 0 to 100 scale. That is enough
    to flag days that are likely to be low, but too coarse to rank two days
    that are close.

**What the final model uses.** `varImp()` for glmnet is |coefficient| scaled
to 100, on standardized predictors:

| Predictor | Importance | Coefficient (points per SD) |
|---|---|---|
| need_satisfaction | 100 | +13.2 |
| need_frustration | 57 | −7.5 |
| sleep_quality | 32 | +4.2 |
| stress_worst (linear trend) | 16 | −2.1 |
| everything else | under 10 | |

- 31 of 52 columns are nonzero.
- Both play-day-type columns are zero.
- Every BANGS item scores under 5.

**The worst stressor, translated** (one day, changing only `stress_worst`):

| Worst stressor | Days | Raw gap from "None" | Model gap (all else fixed) |
|---|---|---|---|
| Not very | 131 | −4.4 | −0.8 |
| Somewhat | 637 | −13.2 | −3.4 |
| Very | 436 | −29.5 | −7.8 |

Stressful days also have worse needs and sleep, and those predictors take
their share. The decline is curved: mild stressors barely matter.

---

## 11. What the results mean

- **For the users** (designers of well-being check-ins): a few in-game
  questions plus a short needs check can flag days that are likely to be low
  in life satisfaction. A frustrating play day is one marker.
- **What a model of days cannot do:** 73% of the variation is between people.
  This model cannot say *which players* are generally less satisfied, or why.
  That needs a model of people.
- **Same-day caveat:** every predictor comes from the same day's survey, so
  the model describes what goes together on a day. It does not forecast
  tomorrow, and the direction can run either way (a bad day can make the
  gaming and the needs feel worse).
- **The needs carry the prediction:** need satisfaction alone correlates .66
  with the target, and without the needs block CV R² falls from .623 to
  .371. The BANGS items and the person characteristics add little once the
  needs are in.
- **Interpretability:** nothing is lost. The final model is also the most
  accurate, and it can be handed over as a list of coefficients.

---

## 12. Reproducibility

- Every random step uses seed 559. The parallel folds use a fixed `seeds`
  list.
- Refits are exactly reproducible, which is the reason gbm was dropped.
- The saved fits in `output/model_fits/` let anyone knit in a few minutes
  without refitting. See the README for how to run it, and for the clean
  refit before submission.
