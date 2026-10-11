# Master script for regular maintenance of the install-time patches.
# See scripts/CLAUDE.md for the full procedure.
#
#  1. Runs check-patches.R and find-failures.R (results in scripts/output/)
#  2. Moves patches that are no longer needed to patches/old:
#     - APPLIED: the fix landed upstream
#     - MISSING: package no longer on cran/bioc universe
#     - FAILED, but the latest arm64 build ran without the patch (it failed
#       to apply) and still produced a binary
#  3. Regenerates patches/patches_idx.rds
#  4. Writes scripts/output/TODO.md listing patches to update and packages
#     that may need a new patch.
#
# Usage: Rscript scripts/update.R [--dry-run]
# Needs GNU patch (gpatch) and a GitHub token (GITHUB_PAT or 'gh auth login').

dryrun <- "--dry-run" %in% commandArgs(TRUE)
scriptdir <- normalizePath(dirname(sub("^--file=", "", grep("^--file=",
  commandArgs(FALSE), value = TRUE)[1])))
rootdir <- dirname(scriptdir)
patchdir <- file.path(rootdir, "patches")
outdir <- file.path(scriptdir, "output")
dir.create(outdir, showWarnings = FALSE)

rscript <- file.path(R.home("bin"), "Rscript")
run <- function(script, ...) {
  message("\n>> Running ", script)
  status <- system2(rscript, c(file.path(scriptdir, script), ...))
  if (status != 0) stop(script, " failed")
}
run("check-patches.R", paste0("--csv=", file.path(outdir, "patches.csv")))
run("find-failures.R", paste0("--csv=", file.path(outdir, "failures.csv")),
  file.path(outdir, "failures.md"))

patches <- read.csv(file.path(outdir, "patches.csv"), stringsAsFactors = FALSE)
failures <- read.csv(file.path(outdir, "failures.csv"), stringsAsFactors = FALSE)

# Patches that are no longer needed
patches$reason <- with(patches, ifelse(status == "APPLIED", "fixed upstream",
  ifelse(status == "MISSING", "package not on cran/bioc universe",
  ifelse(status == "FAILED" & buildlog %in% "failed" & !is.na(arm64) & arm64 != "FAIL",
    sprintf("does not apply, but arm64 %s builds without it (check: %s)", version, arm64), NA))))
retire <- patches[!is.na(patches$reason), ]

if (!dryrun && nrow(retire)) {
  dir.create(file.path(patchdir, "old"), showWarnings = FALSE)
  for (pkg in retire$package) {
    from <- file.path(patchdir, paste0(pkg, ".diff"))
    to <- file.path(patchdir, "old", paste0(pkg, ".diff"))
    if (system2("git", c("-C", rootdir, "mv", "-f", from, to), stderr = FALSE) != 0)
      file.rename(from, to)
  }
}

# Regenerate the index (index.R uses relative paths)
if (!dryrun) {
  owd <- setwd(patchdir)
  source("index.R")
  setwd(owd)
}

# Patches that need work
update <- patches[patches$status == "FAILED" & is.na(patches$reason), ]
update$lastchange <- vapply(update$package, function(pkg) {
  out <- system2("git", c("-C", rootdir, "log", "-1", "--format=%cs", "--",
    file.path("patches", paste0(pkg, ".diff"))), stdout = TRUE)
  if (length(out)) out else NA_character_
}, "")

# Failures that may need a new patch (or have a broken patch)
fixable <- failures[failures$type %in% c("COMPILE", "CONFIGURE", "LOAD", "UNKNOWN"), ]
blocked <- failures[failures$type == "DEPENDENCY", ]
timeout <- failures[failures$type == "TIMEOUT", ]

fmt_update <- function(x) with(x, sprintf(
  "- [ ] %s/%s %s: arm64 check %s, patch in last build: %s, patch last changed %s",
  universe, package, version, arm64, buildlog, lastchange))
fmt_fail <- function(x) with(x, sprintf(
  "- [ ] %s/%s %s (%s, used by %d)%s: %s", universe, package, version, type, usedby,
  ifelse(patched, " **has patch, still fails**", ""), log))

todo <- c(
  "# Patch maintenance TODO", "",
  sprintf("Generated %s%s. Details in failures.md, patches.csv and failures.csv.",
    format(Sys.time(), "%Y-%m-%d %H:%M"), if (dryrun) " (dry run: nothing moved)" else ""), "",
  sprintf("## Retired patches (%s patches/old)", if (dryrun) "would move to" else "moved to"), "",
  if (nrow(retire)) sprintf("- %s: %s", retire$package, retire$reason) else "None", "",
  "## Patches to update (do not apply to current version)", "",
  if (nrow(update)) fmt_update(update) else "None", "",
  "## Packages failing on arm64 only (sorted by reverse dependencies)", "",
  if (nrow(fixable)) fmt_fail(fixable) else "None", "",
  "## Blocked by unavailable dependencies (fix the dependency instead)", "",
  if (nrow(blocked)) sprintf("- %s: needs %s", blocked$package, blocked$detail) else "None", "",
  "## Build timed out", "",
  if (nrow(timeout)) sprintf("- %s: %s", timeout$package, timeout$log) else "None")
writeLines(todo, file.path(outdir, "TODO.md"))
cat("\n", todo, sep = "\n")
