# Instructions for Claude: regular patch maintenance

Follow this when the user asks to "update the patches", "run the patch maintenance" or similar.
Goal: keep `patches/` limited to patches that are needed and still apply, and add patches
for packages that fail to build on Windows arm64 (but build on x86_64), prioritizing packages
with many reverse dependencies, because those block other packages from building.

## Background

- r-universe builds arm64 binaries with `_R_INSTALL_TIME_PATCHES_=http://contributor.r-project.org/windows-arm64/patches`,
  which serves this repo's `patches/` folder. R looks up `patches_idx.rds` and applies `<pkg>.diff` from inside the
  package source dir with `patch -p2 --binary --force` (dry-run first; on failure it tries `-R` to detect
  "already applied"). A failed patch only gives a warning: the build continues unpatched.
- Patch format: `diff -Nru orig/<pkg>/... new/<pkg>/...` so that `-p2` strips `orig/<pkg>/`.
- In r-universe job results, `FAIL` means no binary was built. `ERROR`/`WARNING`/`NOTE` are check results
  (e.g. failing tests) and do not block dependents: ignore those.
- macOS `/usr/bin/patch` (2.0) is stricter than the GNU patch in Rtools. Always use `gpatch` (`brew install gpatch`).
- We cannot build for Windows arm64 locally. Local verification = the patch applies with `gpatch`.
  Real verification = the `test-patches.yaml` workflow on a `windows-11-arm` runner (see step 5).

## Step 1: run the master script (about 3 minutes)

```sh
Rscript scripts/update.R            # or --dry-run to move nothing
```

Run it in the background, or with a long timeout. It runs `check-patches.R` and `find-failures.R`, moves
patches that are no longer needed to `patches/old/` (with `git mv`), regenerates `patches/patches_idx.rds`
and writes to `scripts/output/` (gitignored):

- `TODO.md`: the work list. Start here.
- `failures.md`: the relevant error lines for each failing package, plus a link to the log.
- `patches.csv`, `failures.csv`: raw results.

Patches it retires automatically: `APPLIED` (fixed upstream), `MISSING` (package gone), and `FAILED`
patches where the latest arm64 build log shows the patch failed to apply but a binary was built anyway.
Check `git status` and include the retired patches in your report to the user.

## Step 2: update patches that no longer apply ("Patches to update")

For each one:

1. Look at the `buildlog` column and `git log -p -1 -- patches/<pkg>.diff`. If the patch was changed
   recently and the build log says `applied`, the patch was probably updated on purpose for an upcoming
   version (example: in Oct 2026 the arrow patch was updated for arrow 26 while CRAN still had 25.0.1).
   Do not touch it. Report it to the user instead.
2. Otherwise get the current source and regenerate the patch. Work in the scratchpad:
   ```sh
   curl -sL https://<universe>.r-universe.dev/src/contrib/<pkg>_<version>.tar.gz | tar xz && mv <pkg> orig-<pkg>
   mkdir -p orig new && mv orig-<pkg> orig/<pkg> && cp -R orig/<pkg> new/<pkg>
   (cd new/<pkg> && gpatch -p2 --binary --force --no-backup-if-mismatch < $REPO/patches/<pkg>.diff)
   ```
   Fix the rejected hunks (`*.rej`) by hand in `new/<pkg>`, delete the `.rej`/`.orig` files, then:
   ```sh
   diff -Nru orig/<pkg> new/<pkg> > $REPO/patches/<pkg>.diff
   ```
   If the hunks are no longer needed (upstream fixed part of it), leave them out.
3. Verify: `Rscript scripts/check-patches.R <pkg>` must report `OK`.

## Step 3: new patches for failing packages

Work through "Packages failing on arm64 only" in `TODO.md`, starting with the highest `used by`.
Look at the errors in `failures.md` (open the log link if it's not clear). Skip, but report:

- Problems we cannot fix with a patch: missing system libraries (e.g. tiledb static libs), MPI (not on arm64),
  timeouts, failures in vendored binaries we can't rebuild.
- `DEPENDENCY`: fix the dependency instead (it's usually in the list as well).
- Packages that already have a patch but still fail: treat as Step 2.

Known recipes (see the existing patches in `patches/` and `patches/old/` for examples):

| Symptom | Fix | Example |
|---|---|---|
| Rust: target `-pc-windows-gnu` / `x86_64-pc-windows-gnu` hardcoded | pick the target in R: `aarch64-pc-windows-gnullvm` on arm64 | `old/clarabel.diff`, `h3o.diff` |
| Rust: `failed to run custom build command for extendr-ffi v0.8.0/0.8.1` | bump extendr-api/ffi/macros to `0.8.2` in `Cargo.toml` and `Cargo.lock` (with crates.io checksums), and turn off the vendored tarball so cargo downloads the new crates | `h3o.diff` |
| `-msse*` flags, `<emmintrin.h>`, `_mm_*` intrinsics | remove the flags / guard x86 code with `#if defined(__x86_64__)` or use the fallback code path | `dada2.diff` |
| `std::random_shuffle` not found | replace with `std::shuffle(begin, end, std::mt19937{std::random_device{}()})` | |
| K&R style C function definitions (`unknown type name` on the parameters) | add `-std=gnu17` to `PKG_CFLAGS` in `src/Makevars.win` (create it if needed) | |
| `-lgfortran`, `-lquadmath`, `-latomic` hardcoded | use `$(FLIBS)` / `$(LAPACK_LIBS) $(BLAS_LIBS)` / drop `-latomic` | `baseline.diff` |
| flang: `unknown argument '--float-store'`, `-fall-intrinsics`, etc. | remove the gfortran-only flags from Makevars | |
| Autotools/CMake can't detect arm64 mingw, makes MSVC `.lib` | pass `--host=aarch64-w64-mingw32`, or skip configure in `configure.win` | |
| `Rip`, `Eip` in `CONTEXT`, x64 inline asm | add the `_M_ARM64`/`__aarch64__` case (`Pc` register) | |

Before building bundled third-party libraries from source, check if Rtools already ships them
(e.g. SYMPHONY/Coin-OR, see how other CRAN packages like Rsymphony link them on Windows): linking to
the Rtools library is much simpler and more robust (see `lpsymphony.diff`). To make a Makevars.win
change for arm64 only, test `R.version$platform` (see `lpsymphony.diff`); `$(WIN)` is empty on arm64.

Create the patch with the same orig/new layout as in Step 2 (start from an unmodified copy), keep the change
small and limited to Windows arm64 where possible (so the same patch doesn't break x86_64), and check it
with `Rscript scripts/check-patches.R <pkg>`.

If you can't find a reasonable fix in a few attempts, move on and list the package as unresolved in your report.

## Step 4: regenerate the index

`update.R` already did this, but after adding/updating patches run it again:

```sh
cd patches && Rscript index.R
```

## Step 5: test on Windows arm64 (ask first)

New and updated patches have only been verified to apply. To actually build them, the
`.github/workflows/test-patches.yaml` workflow builds packages from source on `windows-11-arm` using
the patches in the selected branch. This needs a push, so **ask the user before pushing anything**.
Then:

```sh
git push origin HEAD:patch-updates
gh workflow run test-patches.yaml --ref patch-updates -f packages="pkg1 pkg2"
gh run watch $(gh run list --workflow test-patches.yaml --limit 1 --json databaseId -q '.[0].databaseId')
```

The workflow is on `main`. Group packages into a few runs (e.g. by kind of fix) so they run in parallel.
Each package gets a `##[notice]<pkg>: OK/FAILED` line; grep for that in `gh run view <id> --log`.
Caveats:
- It tests R-release only. Failures specific to R-devel build fine there with or without the patch.
  Known R-devel issue: Fortran programs linked with `aarch64-w64-mingw32-flang` (x13binary, cepreader,
  Uno) fail. That compiler name makes flang act like a gcc toolchain: it uses the x86_64 `ld` from PATH,
  and with `-fuse-ld=lld` it needs `-lgcc`/`-lgcc_eh`, which don't exist. This needs fixing in R-devel's
  Makeconf/toolchain (R-release uses plain `flang` and works); don't patch packages for it.
- Some packages (e.g. ones building bundled libraries) take 20+ minutes. Don't assume a run is hung
  just because it is slow; check the streamed log.
- Packages whose dependencies have no arm64 binary yet will be built from source as dependencies.

After testing, ask the user before merging into `main` (that makes the patches live). Then delete the
`patch-updates` branch.

## Step 6: retry the failed r-universe builds (after merging)

r-universe only picks up new patches when a package is rebuilt. After the patches are merged into
`main`, retry the failed arm64 builds of every package with a new or updated patch:

1. Check that the patch server serves the merged patches (it should match `patches/patches_idx.rds`;
   for updated patches also compare a `.diff`):
   ```sh
   curl -sL http://contributor.r-project.org/windows-arm64/patches/patches_idx.rds -o idx.rds
   Rscript -e 'setequal(names(readRDS("idx.rds")), names(readRDS("patches/patches_idx.rds")))'
   ```
2. Get the build run of each package from `https://<universe>.r-universe.dev/api/files?type=src&fields=_buildurl,_jobs`
   (`_buildurl` is `https://github.com/r-universe/<universe>/actions/runs/<run>`). Only retry
   packages where a `windows-*-arm64` job has status `FAIL`.
3. Re-run the failed jobs of that run:
   ```sh
   gh run rerun <run> --failed -R r-universe/<universe>
   ```
   The user has admin rights on `r-universe/cran` and `r-universe/bioc`. GitHub refuses re-runs for
   runs older than 30 days or still in progress; list those in the report.
4. Next time, `scripts/update.R` shows which packages are fixed. A package that still fails after a
   retry with the patch applied needs another look (check the log for `Applied installation-time patch`).

## Step 7: report to the user

Keep it short:

- retired patches (and why)
- updated patches, new patches (with the fix in one line each), and whether they were tested on arm64
- patches left alone on purpose (e.g. prepared for an upcoming version)
- unresolved failures, especially ones with many reverse dependencies
- packages whose fix should go upstream (the patch is only a stopgap until the fix lands on CRAN/BioC)

Do not commit, push or merge unless the user asks. After a merge the user approved, do Step 6 right away.

## Step 8: send fixes upstream (once the retries have finished)

A patch is only a stopgap: the real fix belongs in the package. For patches that fixed the build in the
Step 6 retry, send a pull request to the upstream repository. **Be careful and conservative**: package
authors don't like bad or spammy PRs, and every PR goes out under the user's name. When in doubt, skip it
and write down why in `scripts/upstream-prs.md`.

1. Run `Rscript scripts/upstream-candidates.R` (writes `scripts/output/upstream-candidates.csv`).
   Candidates are packages where the arm64 job failed before the retry and succeeded in the retry with
   `Applied installation-time patch` in the log, which have no row in `upstream-prs.md` yet and no earlier
   PR of ours in the repo (column `prs`). For packages that do have an earlier PR, check if it covers
   this issue; if so add a row for it (`merged` if it was merged but is not on CRAN/BioC yet).
2. Find the upstream repository where development actually happens. Start from `devurl` (from
   r-universe), and the `URL`/`BugReports` fields in DESCRIPTION. Verify it:
   - it is the package: the `DESCRIPTION` has the same `Package:` (possibly in a subdirectory);
   - development happens there: not archived, recent commits by the maintainers, version on the default
     branch >= the CRAN version. For Bioconductor, compare against the maintainers' own commits instead:
     Bioconductor bumps versions automatically in its own git, which GitHub repos often don't merge.
     Read-only mirrors (`github.com/cran/*`, `github.com/bioc/*`) don't count.
   - Only GitHub repositories (we use `gh`). For other hosts, note the URL with status `skip` so the
     user can decide.
   If there is no such repository: add a row with status `skip` and a note (for Bioconductor packages
   include the maintainer from DESCRIPTION, so the user can decide to email them), and move on.
   The GitHub search API is rate limited; `gh pr list -R <repo> --state all --search ...` and
   `gh issue list` work as a fallback.
3. Verify the fix is still needed and not already proposed:
   - Shallow clone the default branch and dry-run the patch on it (`gpatch --dry-run -p2` from the package
     directory). If it applies in reverse, or the code was fixed in another way: status `skip`, note
     "fixed upstream, not yet released".
   - Search existing PRs and issues: `gh search prs --repo <repo> arm64`, also `aarch64` and the error
     message. If someone (including us) already has an open PR for this issue: `skip` with a link.
4. Prepare the change in a fork (`gh repo fork <repo> --clone=false`, clone it, branch `windows-arm64`):
   - Apply the patch. Adapt it where the repository differs from the CRAN tarball (e.g. files that are
     generated at release time, like `configure` from `configure.ac`, or vendored Rust crate tarballs:
     change the sources, not the generated files). Keep the diff minimal: no version bumps, NEWS entries,
     reformatting or unrelated changes.
   - One commit, authored by the user: `git -c user.name="Jeroen Ooms" -c user.email="jeroenooms@gmail.com" commit`.
     One-line message: `Fix build on Windows ARM64`, optionally with a few words why, e.g.
     `Fix build on Windows ARM64: replace removed std::random_shuffle`.
     No `Co-Authored-By` or other Claude/AI attribution, in commits or PR text (the user's explicit wish).
5. Write the PR. Title: `Fix build on Windows ARM64`. Body, concise like the user's earlier PRs
   (e.g. https://github.com/thomasp85/waysign/pull/4):
   ```
   This fixes the build on Windows ARM64. <1-3 lines: what was the problem and what this changes>

   Before (without this patch): <failing arm64 job URL from the 'before' column>
   After (with this patch): <successful arm64 job URL from the 'after' column>

   For more details see https://github.com/r-devel/windows-arm64
   ```
6. **Ask the user before opening any PR**: show the list (package, repository, one-line description of
   the change) and one or two full drafts. After approval, push the branch to the fork and open the PR:
   `gh pr create -R <repo> --head jeroen:windows-arm64 --title "..." --body "..."`. Never more than one
   PR per repository for the same issue.
7. Record every package in `scripts/upstream-prs.md` (PR URL and `opened`, or `skip` with the reason).

On every maintenance run, also update the tracking table: refresh the state of open PRs with
`gh pr view <url> --json state,mergedAt`, and mark a PR `landed` when `update.R` retires the patch
because it is fixed upstream (move the row's patch to `patches/old` as usual).
