# R on ARM64 Windows 

Building upon [earlier work](https://blog.r-project.org/2024/04/23/r-on-64-bit-arm-windows/index.html) by Tomáš Kalibera[†](https://www.r-project.org/doc/obit/tomas.html) we provide the resources and infrastructure for using R natively on ARM64 Windows hardware. For now this effort is fully community driven, not endorsed or supported by R-core.


## Base R Installers

Base R installers are built daily on GitHub actions using the [r-devel/actions](https://github.com/r-devel/actions) workflow. You can download them here:

 - R-devel: https://github.com/r-devel/actions/releases/tag/devel
 - R-patched: https://github.com/r-devel/actions/releases/tag/next
 - R-release: https://github.com/r-devel/actions/releases/tag/4.6.1

Because R officially does not support arm64 on Windows, an unpatched build would install Windows binary packages for x86_64 which won't work. 

Therefore this build is [patched](https://github.com/r-devel/actions/blob/main/build-r-windows/winarm64.patch) to download binaries from  `/bin/windows/clang-aarch64/contrib/` instead of `/bin/windows/contrib/` on CRAN-like package repositories, e.g:

 - https://cran.r-universe.dev/bin/windows/clang-aarch64/contrib/4.7/PACKAGES
 - https://bioc.r-universe.dev/bin/windows/clang-aarch64/contrib/4.7/PACKAGES

This directory does not exist on upstream CRAN, so there R will fall back to install from source. However the directory does exist on repositories which build Windows ARM64 binaries such as [R-universe](https://r-universe.dev) (more below).

## Compiler toolchain (Rtools)

Currently we build everything with [rtools45-aarch64](https://cran.r-project.org/bin/windows/Rtools/rtools45/files/rtools45-aarch64-6768-6492.exe) which was the last stable version of Rtools for arm64 released by Tomáš. This toolchain was cross-compiled from [a fork of MXE](https://github.com/r-devel/r-dev-web/tree/HEAD/WindowsBuilds/winutf8/ucrt3/toolchain_libs) and includes [clang 19.1.7 with MinGW-w64 11.0.1](https://cran.r-project.org/bin/windows/Rtools/rtools45/news.html).

After the passing of the maintainer, Rtools is de-facto unmaintained, so be aware that toolchain / library updates are unlikely any time soon, and we have to work with what we got. Fortunately it seems that tools45 is a solid release.

## Binary Packages

Windows ARM64 binary packages for CRAN and other repositories are available from R-universe (currently only for R-devel 4.7). Simply set the R-universe mirror as the CRAN mirror and things will work: 

```r
# Requires R-4.7 for now
options(repos = c(CRAN = "https://cran.r-universe.dev"))
install.packages("tidyverse")
```

You can also inspect check results for the packages, for example: https://cran.r-universe.dev/dplyr#checktable

We are currently in the process of backfilling the arm64 binaries for other universes as well.

Note that R-universe only builds packages for ARM64 on Windows and Linux if they contain compiled (C/C++/Fortran/Rust) code. For packages containing only R code, there is no difference between x86_64 and arm64 binary, so we serve the same binary to both architectures.


## Rust Support

Rust is fully supported. As 2025 the `aarch64-pc-windows-gnullvm` target (which is what rtools45 needs) has [tier-2 status](https://doc.rust-lang.org/stable/rustc/platform-support/windows-gnullvm.html), so we can install the toolchain using rustup:

```sh
rustup target add aarch64-pc-windows-gnullvm.
```

However not all R packages work yet because the R package needs to invoke `cargo` with `--target=aarch64-pc-windows-gnullvm` but many older R packages are unconditionally targeting `x86_64-pc-windows-gnu` on Windows, which is wrong. For a simple solution, see the [method from hellorust](https://github.com/r-rust/hellorust/commit/e371cae6bbd7a812e363aa723b1d106389feeb02).

R packages using `extendr` need at least version `0.8.2` of the `externdr-api` cargo crate due to [extendr#950](https://github.com/extendr/extendr/pull/950).



## More Tools

JAGS: a community port of JAGS for Windows ARM64 to compile `rjags` and `runjags`  is available here: https://github.com/r-windows/JAGS/releases/tag/installers.

Pandoc/quarto: these are standalone executables so I recommend just installing the x86_64 ones, which will run fine on ARM64 as well.

Extra libs: for system libraries that rtools/MXE does not support, an unofficial msys2 based build system is available at https://github.com/r-windows/ucrt-libs



## Testing on GitHub Actions

GitHub provides free runners for `windows-11-arm` that you can use to test your R packages.

The popular workflows from [r-lib/actions](https://github.com/r-lib/actions) support Windows ARM64 out of the box. Simply replace or add one of your `windows-latest` entries with `windows-11-arm` and off you go.

Alternatively you can copy the [canned workflow from r-universe](https://docs.r-universe.dev/publish/troubleshoot-build.html#how-to-test-the-r-universe-build-workflow-from-your-own-github-repository) in your own package repository to run the exact same builds and checks that R-universe would run.



## Debugging setup for MacOS users

For debugging you can use VMware fusion on MacOS (free version) to run Windows 11 for ARM (downloaded from https://www.microsoft.com/en-us/software-download/windows11arm64) on Apple M1+ hardware.

![screenshot of vmware](https://github.com/user-attachments/assets/9c446af5-0076-472f-9df4-efdf565207d0)

You can run this on your macbook, but VMware can be a bit battery hungry. So I personally run it on a Mac Mini server that I keep at home. In the Windows VM you can enable RDP (remote access) to connect using any RDP client (confusingly called "Windows App" on MacOS these days), which works well. Finally tailscale also works well on Windows ARM64 so if you install that on the Windows VM and your macbook, you can RDP to the Windows machine from anywhere in the world.



## Other Common Issues

 - Packages unconditionally passing `-msse` flags to the C/C++ compiler fails because these extensions are not available on arm64 [example](https://github.com/Huber-group-EMBL/rhdf5filters/pull/33/changes)
 - Autotools configure scripts often misdetect mingw on arm64, and generates MSVC style '.lib' files and commands
 - Windows ARM64 [does not have MPI](https://github.com/microsoft/Microsoft-MPI/issues/75). So packages like Rmpi do not work.