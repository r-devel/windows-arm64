# Check which install-time patches still apply to the current package sources
# on cran.r-universe.dev / bioc.r-universe.dev.
#
# For every patches/*.diff this downloads the current source tarball and runs
# the same 'patch' dry-runs that R's installer does (tools:::.install_packages):
#
#   OK       patch applies cleanly: keep it
#   APPLIED  patch applies in reverse: fixed upstream, remove the patch
#   FAILED   patch does not apply: needs to be updated (or removed)
#   MISSING  package not found on cran/bioc universe (archived?)
#
# For FAILED patches it also reads the latest arm64 build log on GitHub to see
# what happened to the patch in that build (column 'buildlog'):
#
#   applied  the patch was applied in the build (patch changed since?)
#   failed   the patch failed to apply, so the build ran unpatched
#   skipped  R thought the patch was already applied
#
# Usage: Rscript scripts/check-patches.R [--csv=results.csv] [pkg ...]
# Prefers GNU patch ('gpatch', e.g. brew install gpatch) when available.
# Reading build logs needs GITHUB_PAT or 'gh auth token' (otherwise skipped).

library(jsonlite)

universes <- c("cran", "bioc")
patchdir <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=",
  commandArgs(FALSE), value = TRUE)[1])), "..", "patches"))
patchbin <- Sys.which(c("gpatch", "patch"))
patchbin <- patchbin[nzchar(patchbin)][1]
if (is.na(patchbin)) stop("No 'patch' utility found")

files <- list.files(patchdir, pattern = "\\.diff$", full.names = TRUE)
names(files) <- sub("\\.diff$", "", basename(files))
args <- commandArgs(TRUE)
csvfile <- sub("^--csv=", "", grep("^--csv=", args, value = TRUE)[1])
args <- grep("^--", args, value = TRUE, invert = TRUE)
if (length(args)) files <- files[names(files) %in% args]

token <- Sys.getenv("GITHUB_PAT", Sys.getenv("GITHUB_TOKEN"))
if (!nzchar(token)) token <- tryCatch(suppressWarnings(system2("gh", c("auth", "token"),
  stdout = TRUE, stderr = FALSE)), error = function(e) "")

read_universe <- function(universe) {
  url <- sprintf("https://%s.r-universe.dev/api/files?type=src&fields=_jobs", universe)
  df <- stream_in(url(url), verbose = FALSE, simplifyDataFrame = FALSE)
  out <- do.call(rbind, lapply(df, function(x) {
    arm <- Filter(function(j) j$config == "windows-release-arm64", x[["_jobs"]])
    data.frame(universe = universe, package = x$package, version = x$version,
      arm64 = if (length(arm)) arm[[1]]$check else NA_character_,
      job = if (length(arm)) as.character(arm[[1]]$job) else NA_character_)
  }))
}

# What happened to the patch in the latest arm64 build on r-universe
patch_in_buildlog <- function(universe, job, pkg) {
  if (!length(token) || !nzchar(token[1]) || is.na(job)) return(NA_character_)
  url <- sprintf("https://api.github.com/repos/r-universe/%s/actions/jobs/%s/logs", universe, job)
  h <- curl::new_handle(httpheader = paste("Authorization: Bearer", token[1]))
  res <- curl::curl_fetch_memory(url, handle = h)
  if (res$status_code != 200) return(NA_character_)
  lines <- strsplit(rawToChar(res$content), "\r?\n")[[1]]
  diff <- paste0("[ /]", gsub(".", "\\.", pkg, fixed = TRUE), "\\.diff")
  if (any(grepl(paste0("Applied installation-time patch.*", diff), lines))) "applied"
  else if (any(grepl(paste0("failed to apply patch.*", diff), lines))) "failed"
  else if (any(grepl(paste0("Skipping installation-time patch.*", diff), lines))) "skipped"
  else "none"
}

pkgs <- do.call(rbind, lapply(universes, read_universe))
pkgs <- pkgs[!duplicated(pkgs$package), ]

dry_run <- function(pkgdir, patchfile, reverse = FALSE) {
  owd <- setwd(pkgdir)
  on.exit(setwd(owd))
  args <- c("--dry-run", if (reverse) "-R", "-p2", "--binary", "--force")
  out <- suppressWarnings(system2(patchbin, args, stdin = patchfile,
    stdout = TRUE, stderr = TRUE))
  structure(is.null(attr(out, "status")), output = out)
}

tmp <- tempfile("check-patches")
dir.create(tmp)
results <- lapply(names(files), function(pkg) {
  info <- pkgs[pkgs$package == pkg, ]
  if (!nrow(info)) {
    return(data.frame(package = pkg, universe = NA, version = NA,
      arm64 = NA, status = "MISSING", buildlog = NA))
  }
  url <- sprintf("https://%s.r-universe.dev/src/contrib/%s_%s.tar.gz",
    info$universe, pkg, info$version)
  tarball <- file.path(tmp, basename(url))
  curl::curl_download(url, tarball)
  utils::untar(tarball, exdir = tmp)
  pkgdir <- file.path(tmp, pkg)
  status <- if (dry_run(pkgdir, files[[pkg]])) {
    "OK"
  } else if (dry_run(pkgdir, files[[pkg]], reverse = TRUE)) {
    "APPLIED"
  } else {
    out <- attr(dry_run(pkgdir, files[[pkg]]), "output")
    message(sprintf("\n== %s %s ==\n%s", pkg, info$version, paste(out, collapse = "\n")))
    "FAILED"
  }
  unlink(pkgdir, recursive = TRUE)
  buildlog <- if (status == "FAILED") patch_in_buildlog(info$universe, info$job, pkg) else NA
  data.frame(package = pkg, universe = info$universe, version = info$version,
    arm64 = info$arm64, status = status, buildlog = buildlog)
})
results <- do.call(rbind, results)
results <- results[order(match(results$status, c("FAILED", "APPLIED", "MISSING", "OK"))), ]
rownames(results) <- NULL
cat("\n")
print(results)
if (!is.na(csvfile)) write.csv(results, csvfile, row.names = FALSE)
cat(sprintf("\nUsing %s. Patches to remove: %s\nPatches to update: %s\n", patchbin,
  paste(results$package[results$status %in% c("APPLIED", "MISSING")], collapse = " "),
  paste(results$package[results$status == "FAILED"], collapse = " ")))
