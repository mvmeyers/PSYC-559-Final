# 00_download.R
# Downloads the Open Play daily diary (openESM 0075) once and saves it, so the
# rest of the pipeline reads a local file and does not depend on the network.
# Run once. The saved file is committed to the repo, so most people can skip
# this script.
#
# Output: data/openesm_0075.rds   the full get_dataset() object (data + metadata)
#         data/codebook_0075.csv  the codebook from the metadata element

library(openesm)  # install.packages("openesm")
library(here)

dir.create(here("data"), showWarnings = FALSE)

open_play <- get_dataset("0075")
saveRDS(open_play, here("data", "openesm_0075.rds"))

# Codebook: one row per variable. The list columns are flattened to text.
codebook <- open_play$metadata$features[[1]]
codebook[] <- lapply(codebook, function(x) if (is.list(x)) sapply(x, toString) else x)
write.csv(codebook, here("data", "codebook_0075.csv"), row.names = FALSE)

# Citation for the References section
cite(open_play)
cat("Saved", nrow(open_play$data), "rows,", ncol(open_play$data), "columns.\n")
