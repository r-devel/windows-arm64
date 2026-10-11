# Find packages on cran/bioc r-universe where the Windows arm64 build fails
# (no binary) while the Windows x86_64 build succeeds. These are candidates
# for a new install-time patch, especially if other packages depend on them.
#
# Check failures (ERROR/WARNING, e.g. failing unit tests) are ignored: only
# jobs with status FAIL (i.e. no binary produced) are considered. For each hit
# the GitHub Actions log is downloaded to classify the failure:
#
#   COMPILE     compilation failed (needs a patch)
#   CONFIGURE   configure script failed (needs a patch)
#   LOAD        built but fails to load
#   DEPENDENCY  blocked by a dependency that is unavailable on arm64
#   TIMEOUT     build timed out
#   UNKNOWN     look at the log
#
# Usage: Rscript scripts/find-failures.R [--csv=failures.csv] [outfile.md]
# Needs a GitHub token in GITHUB_PAT or via 'gh auth token' to read logs.

library(jsonlite)

universes <- c("cran", "bioc")
args <- commandArgs(TRUE)
csvfile <- sub("^--csv=", "", grep("^--csv=", args, value = TRUE)[1])
outfile <- grep("^--", args, value = TRUE, invert = TRUE)[1]
patchdir <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=",
  commandArgs(FALSE), value = TRUE)[1])), "..", "patches"))
patches <- sub("\\.diff$", "", list.files(patchdir, pattern = "\\.diff$"))

token <- Sys.getenv("GITHUB_PAT", Sys.getenv("GITHUB_TOKEN"))
if (!nzchar(token)) token <- tryCatch(system2("gh", c("auth", "token"), stdout = TRUE), error = function(e) "")
if (!nzchar(token)) stop("Need GITHUB_PAT or gh auth to download logs")

read_universe <- function(universe) {
  url <- sprintf("https://%s.r-universe.dev/api/files?type=src&fields=_jobs,_usedby,_buildurl", universe)
  df <- stream_in(url(url), verbose = FALSE, simplifyDataFrame = FALSE)
  out <- lapply(df, function(x) {
    jobs <- x[["_jobs"]]
    get <- function(config, field = "check") {
      job <- Filter(function(j) j$config == config, jobs)
      if (length(job)) as.character(job[[1]][[field]]) else NA_character_
    }
    for (flavor in c("release", "devel")) {
      arm <- get(paste0("windows-", flavor, "-arm64"))
      x86 <- get(paste0("windows-", flavor, "-x86_64"))
      if (identical(arm, "FAIL") && !is.na(x86) && x86 != "FAIL") {
        return(data.frame(universe = universe, package = x$package,
          version = x$version, usedby = if (length(x[["_usedby"]])) x[["_usedby"]] else 0L,
          flavor = flavor, x86_64 = x86,
          job = get(paste0("windows-", flavor, "-arm64"), "job"),
          buildurl = x[["_buildurl"]]))
      }
    }
  })
  do.call(rbind, out)
}

get_log <- function(universe, job) {
  url <- sprintf("https://api.github.com/repos/r-universe/%s/actions/jobs/%s/logs", universe, job)
  h <- curl::new_handle(httpheader = paste("Authorization: Bearer", token))
  res <- curl::curl_fetch_memory(url, handle = h)
  if (res$status_code != 200) return(character())
  lines <- strsplit(rawToChar(res$content), "\r?\n")[[1]]
  lines <- sub("^\\S+Z ", "", lines)           # strip timestamps
  gsub("\033\\[[0-9;]*m", "", lines)           # strip ansi colors
}

classify <- function(lines) {
  if (!length(lines)) return(list(type = "UNKNOWN", detail = "Failed to download log"))
  deps <- grep("ERROR: dependenc(y|ies) .* (is|are) not available", lines, value = TRUE)
  if (length(deps)) {
    deps <- sub(".*dependenc(y|ies) (.*) (is|are) not available.*", "\\2", deps)
    deps <- trimws(unlist(strsplit(gsub("['\u2018\u2019]", "", deps), ",")))
    return(list(type = "DEPENDENCY", detail = paste(unique(deps), collapse = ", ")))
  }
  type <- if (any(grepl("ERROR: compilation failed", lines))) "COMPILE"
    else if (any(grepl("ERROR: configuration failed", lines))) "CONFIGURE"
    else if (any(grepl("ERROR: (lazy )?loading failed", lines))) "LOAD"
    else if (any(grepl("The action has timed out", lines))) "TIMEOUT"
    else "UNKNOWN"
  start <- grep("^\\* installing \\*source\\* package", lines)
  if (length(start)) lines <- lines[start[1]:length(lines)]
  errs <- grep("error:|Error [0-9]|ERROR|undefined reference|unable to find|cannot stat|No such file",
    lines, value = TRUE)
  errs <- errs[!grepl("warning:|^\\s*[0-9]* \\||^(ERROR: (compilation|configuration) failed|\\* removing|##\\[)", errs)]
  errs <- unique(trimws(substr(errs, 1, 300)))
  if (length(errs) > 6) errs <- c(utils::head(errs, 4), "...", utils::tail(errs, 1))
  end <- grep("^ERROR: |CONFIGURATION FAILED", lines)
  if (length(errs) < 2 && length(end)) {
    # No clear error message: show the output preceding the failure instead
    errs <- lines[max(1, end[1] - 10):end[1]]
  }
  list(type = type, detail = paste(errs, collapse = "\n"))
}

fails <- do.call(rbind, lapply(universes, read_universe))
fails <- fails[order(-fails$usedby, fails$package), ]
message(sprintf("Found %d packages failing on arm64 only, downloading logs...", nrow(fails)))

info <- lapply(seq_len(nrow(fails)), function(i) {
  classify(get_log(fails$universe[i], fails$job[i]))
})
fails$type <- vapply(info, `[[`, "", "type")
fails$detail <- vapply(info, `[[`, "", "detail")
fails$patched <- fails$package %in% patches
fails$log <- paste0(fails$buildurl, "/job/", fails$job)

# For dependency failures: the root cause is a dependency, which itself should appear in this list
fails <- fails[order(fails$type == "DEPENDENCY", -fails$usedby, fails$package), ]
rownames(fails) <- NULL
print(fails[c("universe", "package", "version", "usedby", "flavor", "x86_64", "type", "patched")])
if (!is.na(csvfile)) write.csv(fails[setdiff(names(fails), "buildurl")], csvfile, row.names = FALSE)

report <- c("# Windows arm64-only build failures", "",
  sprintf("Generated %s. Sorted by number of reverse dependencies.", format(Sys.time(), "%Y-%m-%d %H:%M")), "",
  unlist(lapply(seq_len(nrow(fails)), function(i) with(fails[i, ], c(
    sprintf("## %s/%s %s (%s, used by %d)%s", universe, package, version, type, usedby,
      if (patched) " [has patch]" else ""), "",
    sprintf("arm64 %s build failed, x86_64: %s. [log](%s)", flavor, x86_64, log), "",
    if (type == "DEPENDENCY") paste("Unavailable dependencies:", detail)
    else c("```", detail, "```"), "")))))
if (!is.na(outfile)) {
  writeLines(report, outfile)
  message("Wrote ", outfile)
} else {
  cat(report, sep = "\n")
}
