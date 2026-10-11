# List patches that are candidates to send upstream as a pull request.
# See "Step 8" in scripts/CLAUDE.md.
#
# For every patch in patches/ this looks at the latest r-universe build run of the
# package and reports:
#   before    failing Windows arm64 job (previous attempt, without the patch)
#   after     Windows arm64 job of the latest attempt (with the patch) where the package installed
#             (the job may still fail on check errors, e.g. tests: that's fine for our purpose)
#   applied   whether the 'after' log confirms the patch was applied and the package installed
#   devurl    development repository according to r-universe (verify this!)
#   prs       earlier pull requests by the current gh user in that repository
#   tracked   the entry in scripts/upstream-prs.md, if any
#
# Usage: Rscript scripts/upstream-candidates.R [pkg ...]
# Output: scripts/output/upstream-candidates.csv (or upstream-candidates-subset.csv when packages are given)

library(jsonlite)

scriptdir <- normalizePath(dirname(sub("^--file=", "", grep("^--file=",
  commandArgs(FALSE), value = TRUE)[1])))
patchdir <- file.path(dirname(scriptdir), "patches")
outdir <- file.path(scriptdir, "output")
dir.create(outdir, showWarnings = FALSE)
pkgs <- sub("\\.diff$", "", list.files(patchdir, pattern = "\\.diff$"))
args <- commandArgs(TRUE)
if (length(args)) pkgs <- intersect(pkgs, args)

gh <- function(...) {
  out <- suppressWarnings(system2("gh", c(...), stdout = TRUE, stderr = FALSE))
  if (!is.null(attr(out, "status"))) return(NULL)
  paste(out, collapse = "\n")
}
gh_json <- function(endpoint) {
  out <- gh("api", shQuote(endpoint))
  if (is.null(out)) NULL else fromJSON(out, simplifyVector = FALSE)
}

read_universe <- function(universe) {
  url <- sprintf("https://%s.r-universe.dev/api/files?type=src&fields=_buildurl,_devurl", universe)
  df <- stream_in(url(url), verbose = FALSE, simplifyDataFrame = FALSE)
  do.call(rbind, lapply(df, function(x) data.frame(universe = universe, package = x$package,
    version = x$version, buildurl = if (length(x[["_buildurl"]])) x[["_buildurl"]] else NA,
    devurl = if (length(x[["_devurl"]])) x[["_devurl"]] else NA)))
}
info <- do.call(rbind, lapply(c("cran", "bioc"), read_universe))
info <- info[info$package %in% pkgs & !duplicated(info$package), ]

tracked <- if (file.exists(file.path(scriptdir, "upstream-prs.md"))) {
  lines <- grep("^\\| *[A-Za-z0-9.]+ *\\|", readLines(file.path(scriptdir, "upstream-prs.md")), value = TRUE)
  rows <- strsplit(sub("^\\|", "", lines), "\\|")
  setNames(vapply(rows, function(r) trimws(paste(r[-1], collapse = "|")), ""),
    vapply(rows, function(r) trimws(r[1]), ""))
} else character()

arm64_jobs <- function(repo, run, attempt) {
  res <- gh_json(sprintf("repos/%s/actions/runs/%s/attempts/%d/jobs?per_page=100", repo, run, attempt))
  jobs <- Filter(function(j) grepl("Windows arm64", j$name), res$jobs)
  data.frame(name = vapply(jobs, `[[`, "", "name"), id = vapply(jobs, function(j) format(j$id, scientific = FALSE), ""),
    conclusion = vapply(jobs, function(j) if (is.null(j$conclusion)) "pending" else j$conclusion, ""),
    url = vapply(jobs, `[[`, "", "html_url"))
}

token <- gh("auth", "token")
patch_applied_and_installed <- function(repo, job, pkg) {
  # Not 'gh api': it refuses to print logs with terminal escape sequences
  h <- curl::new_handle(httpheader = paste("Authorization: Bearer", token))
  res <- curl::curl_fetch_memory(sprintf("https://api.github.com/repos/%s/actions/jobs/%s/logs", repo, job), h)
  pkgre <- gsub(".", "\\.", pkg, fixed = TRUE)
  log <- if (res$status_code == 200) rawToChar(res$content) else ""
  grepl(paste0("Applied installation-time patch \\S*/", pkgre, "\\.diff"), log) &&
    grepl(paste0("\\* DONE \\(", pkgre, "\\)"), log)
}

rows <- lapply(seq_len(nrow(info)), function(i) {
  x <- info[i, ]
  repo <- sub("https://github.com/([^/]+/[^/]+)/.*", "\\1", x$buildurl)
  run <- sub(".*/runs/", "", x$buildurl)
  latest <- gh_json(sprintf("repos/%s/actions/runs/%s", repo, run))
  attempt <- if (is.null(latest)) 1L else latest$run_attempt
  after <- arm64_jobs(repo, run, attempt)
  # Jobs where the package installed with the patch (check errors don't matter here)
  installed <- vapply(after$id, function(id) patch_applied_and_installed(repo, id, x$package), logical(1))
  ok <- after[installed, ]
  before <- if (attempt > 1) arm64_jobs(repo, run, attempt - 1L) else after[0, ]
  bad <- before[before$conclusion == "failure", ]
  applied <- nrow(ok) > 0
  ghrepo <- if (!is.na(x$devurl) && grepl("github.com", x$devurl))
    sub("^https?://github.com/([^/]+/[^/#?]+).*", "\\1", x$devurl) else NA
  prs <- if (!is.na(ghrepo)) gh("search", "prs", "--author=@me", paste0("--repo=", ghrepo),
    "--json", "url,state", "-q", shQuote('.[] | "\\(.state) \\(.url)"')) else NULL
  message(sprintf("%s: attempt %d, arm64 %s", x$package, attempt, paste(after$conclusion, collapse = "/")))
  data.frame(package = x$package, universe = x$universe, version = x$version,
    arm64 = paste(after$conclusion, collapse = "/"), applied = applied,
    before = if (nrow(bad)) bad$url[1] else NA, after = if (nrow(ok)) ok$url[1] else NA,
    devurl = x$devurl, prs = if (length(prs) && nzchar(prs)) gsub("\n", "; ", prs) else NA,
    tracked = if (x$package %in% names(tracked)) tracked[[x$package]] else NA)
})
results <- do.call(rbind, rows)
# Candidates: the retry with the patch fixed the build, and we have not tracked or sent a PR yet.
# Packages with an earlier PR (prs column) need a manual check if that PR already covers this issue.
results$candidate <- results$applied & !is.na(results$before) & is.na(results$tracked) & is.na(results$prs)
results <- results[order(!results$candidate, results$package), ]
rownames(results) <- NULL
# Only a full run replaces the csv, so checking a few packages doesn't clobber it
csvfile <- if (length(args)) "upstream-candidates-subset.csv" else "upstream-candidates.csv"
write.csv(results, file.path(outdir, csvfile), row.names = FALSE)
print(results[c("package", "arm64", "applied", "devurl", "prs", "candidate")])
