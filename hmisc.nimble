version       = "0.11.19"
author        = "haxscramper"
description   = "Collection of helper utilities"
license       = "Apache-2.0"
srcDir        = "src"
packageName   = "hmisc"
bin           = @["hmisc/scripts/hmisc_putils"]
installExt    = @["nim"]
binDir        = "bin"

when (1, 2, 2) < (NimMajor, NimMinor, NimPatch):
  namedBin      = {
    "hmisc/scripts/hmisc_putils" : "hmisc-putils"
  }.toTable()

requires "nim >= 1.4.0"
requires "fusion"
requires "benchy >= 0.0.1"
requires "jsony >= 1.0.4"
# requires "https://github.com/haxscramper/fusion.git#matching-fixup"

task docgen, "Generate documentation":
  if not fileExists("bin/hmisc-putils"):
    exec("nimble build")

  exec("""
hmisc-putils docgen \
  --ignore='**/treediff/*.nim' \
  --ignore='**/hcligen.nim'
""")

  # --ignore='**/zs_matcher.nim' \
  # --ignore='**/similarity_metrics.nim' \
  # --ignore='**/treediff_main.nim' \


task dockertest, "Run tests in docker container":
  exec("hmisc-putils dockertest --projectDir:" & thisDir())

# after test:
#   exec("nim c --hints:off --verbosity:0 src/hmisc/scripts/hmisc_putils.nim")
