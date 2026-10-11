# Maintenance scripts

These scripts help maintain the install-time [patches](../patches):

 - `Rscript scripts/update.R` runs both scripts below, moves patches that are no longer needed to `patches/old`, regenerates the patch index, and writes a work list to `scripts/output/TODO.md`. Use `--dry-run` to see what it would do without moving anything. See [CLAUDE.md](CLAUDE.md) for the full procedure.
 - `Rscript scripts/check-patches.R` tests all patches against the current sources on cran/bioc universe, and lists patches that are already applied upstream (remove) or no longer apply (update).
 - `Rscript scripts/find-failures.R report.md` lists packages that fail to build on Windows arm64 but do build on x86_64, sorted by number of reverse dependencies, with the relevant error from the build log.

Requirements: GNU patch (e.g. `brew install gpatch` on MacOS) and a GitHub token (`GITHUB_PAT` or `gh auth login`) to read build logs.

The [test-patches](../.github/workflows/test-patches.yaml) workflow builds packages from source on a Windows arm64 runner, using the patches from the selected branch.
