# Upstream pull requests

Tracks which patches were sent upstream (see Step 8 in [CLAUDE.md](CLAUDE.md)).
Status: `opened`, `merged` (waiting for the CRAN/BioC release), `landed` (released, patch retired), `closed`, `skip` (not sent, see notes).
Keep one row per package, sorted by package name.

| package | upstream | pull request | status | notes |
|---|---|---|---|---|
| adbcdrivermanager | https://github.com/apache/arrow-adbc | https://github.com/apache/arrow-adbc/pull/4591 | merged |  |
| arcgisgeocode | https://github.com/R-ArcGIS/arcgisgeocode | https://github.com/R-ArcGIS/arcgisgeocode/pull/44 | opened |  |
| arcgisplaces | https://github.com/R-ArcGIS/arcgisplaces | https://github.com/R-ArcGIS/arcgisplaces/pull/10 | opened |  |
| automerge | https://github.com/posit-dev/automerge-r | https://github.com/posit-dev/automerge-r/pull/52 | merged |  |
| b64 | https://github.com/extendr/b64 | https://github.com/extendr/b64/pull/13 | opened |  |
| cartogramR | https://github.com/ESO-Rennes/cartogramR |  | skip | repo only has release tarballs, no sources |
| CGEN |  |  | skip | no GitHub repo (Bioc git only); maintainer Justin Lee <jhylee@stanford.edu> |
| chopsticks |  |  | skip | no GitHub repo (Bioc git only); maintainer Hin-Tak Leung <htl10@users.sourceforge.net> |
| ciflyr | https://github.com/mwien/CIfly | https://github.com/mwien/CIfly/pull/18 | opened |  |
| crc32c | https://github.com/eddelbuettel/crc32c |  | skip | fixed upstream in 5590503 (2026-07-30), not yet on CRAN |
| dada2 | https://github.com/benjjneb/dada2 | https://github.com/benjjneb/dada2/pull/2209 | merged |  |
| delta.sharing | https://github.com/zacdav-db/delta-sharing-r | https://github.com/zacdav-db/delta-sharing-r/pull/48 | opened |  |
| fcl | https://github.com/shrektan/fcl | https://github.com/shrektan/fcl/pull/8 | opened |  |
| fio | https://github.com/albersonmiranda/fio | https://github.com/albersonmiranda/fio/pull/191 | merged |  |
| gadjid | https://github.com/CausalDisco/gadjid | https://github.com/CausalDisco/gadjid/pull/20 | opened |  |
| GeneticsPed |  |  | skip | no GitHub repo (Bioc git only); maintainer David Henderson <DNADavenator@GMail.Com> |
| gtfsrealtime | https://github.com/mattwigway/gtfsrealtime-r | https://github.com/mattwigway/gtfsrealtime-r/pull/42 | opened |  |
| h3o | https://github.com/extendr/h3o | https://github.com/extendr/h3o/pull/24 | merged |  |
| hdtg | https://github.com/suchard-group/hdtg | https://github.com/suchard-group/hdtg/pull/13 | opened |  |
| HEM |  |  | skip | no GitHub repo (Bioc git only); maintainer HyungJun Cho <hcho@virginia.edu> |
| iCARE |  |  | skip | no GitHub repo (Bioc git only); maintainer Parichoy Pal Choudhury <Parichoy.PalChoudhury@cancer.org> |
| icebergr | https://github.com/PursuitOfDataScience/icebergr |  | skip | prepared but held: the upstream fix (in tools/vendor.R) differs from the tested patch (vendoring off) |
| ironseed | https://github.com/reedacartwright/ironseed | https://github.com/reedacartwright/ironseed/pull/7 | opened |  |
| ISoLDE | https://github.com/ChristelleReynes/ISoLDE |  | skip | GitHub repo stale since 2020; maintainer Christelle Reynès <christelle.reynes@igf.cnrs.fr> |
| ldt | https://github.com/rmojab63/LDT |  | skip | GitHub repo behind CRAN (0.5.2 vs 0.5.3), R package unchanged since 2023 |
| libipldr | https://github.com/JBGruber/libipldr | https://github.com/JBGruber/libipldr/pull/2 | merged |  |
| lpsymphony | https://github.com/Huber-group-EMBL/lpsymphony | https://github.com/Huber-group-EMBL/lpsymphony/pull/1 | opened |  |
| mdbx | https://github.com/pedrobtz/mdbx | https://github.com/pedrobtz/mdbx/pull/29 | opened |  |
| myTAI | https://github.com/drostlab/myTAI | https://github.com/drostlab/myTAI/pull/79 | opened |  |
| nlmixr2est | https://github.com/nlmixr2/nlmixr2est |  | skip | patch works, but the failing run was caused by rxode2 (same omp.h issue); need a run that shows the nlmixr2est error itself |
| pense | https://github.com/dakep/pense-rpkg | https://github.com/dakep/pense-rpkg/pull/11 | opened |  |
| prqlr | https://github.com/PRQL/prqlc-r | https://github.com/PRQL/prqlc-r/pull/389 | opened |  |
| R3CPET | https://github.com/sirusb/R3CPET |  | skip | GitHub repo stale since 2020; maintainer Mohamed Nadhir Djekidel <djek.nad@gmail.com> |
| Rbeast | https://github.com/zhaokg/Rbeast |  | skip | GitHub R/ is behind CRAN (1.0.1 vs 1.0.2); missing declarations also in Source/, maybe later |
| Rbec | https://github.com/PengfanZhang/Rbec |  | skip | GitHub repo stale since 2023; maintainer Pengfan Zhang <pzhang@mpipz.mpg.de> |
| roxigraph | https://github.com/cboettig/roxigraph | https://github.com/cboettig/roxigraph/pull/4 | opened |  |
| rshift | https://github.com/alexhroom/rshift | https://github.com/alexhroom/rshift/pull/35 | merged |  |
| Rtinycc | https://github.com/sounkou-bioinfo/Rtinycc | https://github.com/sounkou-bioinfo/Rtinycc/pull/13 | merged |  |
| scellpam |  |  | skip | no repository found |
| scider | https://github.com/ChenLaboratory/scider | https://github.com/ChenLaboratory/scider/pull/7 | opened |  |
| slalom |  |  | skip | no GitHub repo for the R package (Bioc git only); maintainer Davis McCarthy <davis@ebi.ac.uk> |
| socratadata | https://github.com/ryanzomorrodi/socratadata | https://github.com/ryanzomorrodi/socratadata/pull/7 | opened |  |
| speakeasyR | https://github.com/SpeakEasy-2/speakeasyR | https://github.com/SpeakEasy-2/speakeasyR/pull/2 | opened |  |
| spopt | https://github.com/walkerke/spopt-r | https://github.com/walkerke/spopt-r/pull/12 | opened |  |
| tergo | https://github.com/kpagacz/tergo |  | skip | tracks vendor.tar.xz but not Cargo.lock; bump needs full re-vendor; no commits since 2025-09 |
| tinyimg | https://github.com/yihui/tinyimg | https://github.com/yihui/tinyimg/pull/44 | merged |  |
| toonlite | https://github.com/aljrico/toonlite |  | skip | upstream reworked the code (toon_charconv.h) in a way that likely still fails on mingw; needs a new untested fix |
| transite | https://github.com/kkrismer/transite | https://github.com/kkrismer/transite/pull/9 | opened |  |
| uuidx | https://github.com/tbrycekelly/uuidx | https://github.com/tbrycekelly/uuidx/pull/1 | opened |  |
| waysign | https://github.com/thomasp85/waysign | https://github.com/thomasp85/waysign/pull/4 | merged |  |
| WebGestaltR | https://github.com/bzhanglab/WebGestaltR | https://github.com/bzhanglab/WebGestaltR/pull/72 | merged | covers the configure check; waiting for CRAN |
| wnominate |  |  | skip | no repository found |
| x13binary | https://github.com/x13org/x13binary | https://github.com/x13org/x13binary/pull/92 | merged | also #93 (linker fix for llvm). R-devel arm64 still fails on a toolchain issue (-lgcc), see CLAUDE.md |
| xgboost | https://github.com/dmlc/xgboost | https://github.com/dmlc/xgboost/pull/12352 | merged |  |
