import sugar, strutils, sequtils, strformat
import ../src/hmisc/helpers
import ../src/hmisc/other/[hshell, oswrap, pathwrap]

#===========================  implementation  ============================#

#================================  tests  ================================#

import unittest

suite "Pathwrap":
  test "test":
    assertEq AbsDir("/a/b/c") /../ 2 /../ RelDir("hello"), AbsDir("/hello")

  test "A":
    echo getNewTempDir()

    for path in toAbsDir("/tmp").walkDir():
      case path.kind:
        of pcDir:
          echo path
        else:
          discard

  test "dirs":
    for dir in parentDirs(cwd()):
      echo dir

  test "Os errros":
    try:
      discard newPathError(toAbsDir("/tmp"), pekExpectedRel):
        "Expected relative directory"

      let path = "12"
      raise newPathError(AbsFile("12"), pekExpectedAbs): fmtJoin:
        "Input path {path} has type {$typeof(path)}, but contains"
        "invalid string - expected absolute path"
    except:
      discard

  test "Extension parts":
    check RelFile("hello").withExt("nim") == RelFile("hello.nim")
    check AbsFile("/tmp/test.nim").withoutPrefix(
      AbsDir("/tmp")) == RelFile("test.nim")

  test "Relative directories":
    check AbsDir("/a/b/c/d").relativePath(AbsDir("/a/b/c")) == RelDir("d")

  test "Mkdir structure":
    let name = "hello"
    proc generateText(): string = "input text test"
    withTempDir(false):
      mkdirStructure:
        file "hello", "content"
        file "test-1", generateText()
        file &"{name}.nimble":
          "author = haxscramper"

        dir "src":
          file &"{name}.nim"
          dir &"{name}":
            file "make_wrap.nim"
            file "make_build.nim"

        dir "tests":
          file "multiline-test":
            """
Multiline string as file content
Not that is looks particulatly pretty though
"""

          file "config.nims":
            """switch("path", "$projectDir/../src")"""

            doAssert currentFile() == "config.nims"


      try:
        execShell(ShelLExpr "ls -R")

      except ShellError:
        discard

      doAssert readFile(&"{name}.nimble") == "author = haxscramper"


suite "Shell":
  test "shell":
    expect ShellError:
      discard runShell(ShellExpr "hello")

  test "Options":
    var cmd = makeGnuShellCmd("cat")
    # cmd["hello"] = "world"
    # cmd["nice"]

  test "OS":
    echo getCurrentOs()
    static:
      echo getCurrentOs()

    # when not isPackageInstalled("hunspell"):
    #   echo "Install hunspell using ", getInstallCmd("hunspell")

    # static:
    #   let missing = getMissingDependencies({
    #     { Distribution.ArchLinux } : @["hunspell-12"]
    #   })

    #   for (pkg, cmd) in missing:
    #     echo "Missing ", pkg, ", install it using ", cmd


suite "User directories":
  test "xdg":
    echo getUserConfigDir()
    echo getAppConfigDir()

    echo getUserCacheDir()
    echo getAppCacheDir()

    echo getUserDataDir()
    echo getAppDataDir()

    echo getUserRuntimeDir()
    echo getAppRuntimeDir()

suite "Env wrap":
  test "get/set/exists":
    let env = $$TEST_ENV1

    doAssert not exists(env)
    set(env, "hello")
    doAssert get(env) == "hello"
    del(env)

  test "Getting typed vars":
    let env = $$TEST_ENV2
    env.put(false)
    doAssert not env.get(bool)

    env.put(100)
    doAssert env.get(int) == 100

    del(env)

  test "Equality comparison for variables":
    discard $$CI == true
    discard $$CI == 1
    discard $$IC == "1"

  test "Assign variables":
    static:
      put($$ZZZ, false)

      doAssert $$ZZZ == false
      doAssert get($$ZZZ, string) == "false"


    when $$ZZZ == true:
      fail()

    else:
      discard

    put($$CI, true)
    if $$CI == true:
      discard

    else:
      fail()
