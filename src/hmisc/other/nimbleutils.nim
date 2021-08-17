#!/usr/bin/env nim

import
  std/[strformat, strutils, sugar, sequtils, xmltree, macros]

import
  ./hshell,
  ./oswrap,
  ./hlogger,
  ../core/all,
  ../algo/hseq_distance,
  ../types/colorstring


func format*(str: string, kvalues: openarray[(string, string)]): string =
  str % kvalues.mapIt(@[it[0], it[1]]).concat()

# export AbsDir, RelDir, AbsFile, RelFile, ShellExpr, ShellVar
# export get, set, del, exists, `&&`
# export info, warn, fatal, error, notice, startColorLogger
export oswrap, hshell

import ../algo/[htemplates, hstring_algo]

## Helper utilities for running nimble tasks

type
  TaskRunConfig* = object
    hrefPref*: string
    outDir*: AbsDir
    nimdocCss*: AbsFile
    testRun*: bool

    logFile*: AbsFile

    projectDir*: AbsDir

    packageName*: string
    version*: string
    author*: string
    description*: string
    license*: string
    srcDir*: string
    binDir*: string
    cmdOptions*: seq[ShellCmdPart]
    logger*: HLogger

loggerField(TaskRunConfig, logger)

func switch*(conf: var TaskRunConfig, val: string) =
  conf.cmdOptions.add initCmdFlag(val)

func switch*(conf: var TaskRunConfig, key, val: string) =
  conf.cmdOptions.add initCmdOption(key, val)

proc envOrParm*(
  conf: var TaskRunConfig, key: string, env: ShellVar,
  allowEmpty: bool = false) =
  if env.exists and (env.get.len > 0 or allowEmpty):
    conf.cmdOptions.add initCmdOption(key, env.get)
  else:
    try:
      conf.cmdOptions.add initCmdOption(key, paramVal(key)[0])
    except KeyError:
      raise newException(
        KeyError, &"No variable '${env.string}' is defined " &
        &"and CLI parameter '{key}' was not supplied.")

proc envOrParam*(
  conf: var TaskRunConfig, key: string, interpol: ShellExpr,
  allowEmpty: bool = false) =
  let interp = interpolateShell(interpol)
  if interp.isSome():
    conf.cmdOptions.add initCmdOption(key, interp.get())
  else:
    try:
      conf.cmdOptions.add initCmdOption(key, paramVal(key)[0])
    except KeyError:
      raise newException(
        KeyError, &"Interpolation for '{interpol.string}' has failed " &
        &"and CLI parameter '{key}' was not supplied.")

proc configureCI*(conf: var TaskRunConfig) =
  if ShellVar("CI").exists() and
     ShellVar("CI").toBool() == true and
     not defined(hunittestMerge):
    conf.info "Using CI configuration"
    conf.envOrParam(
      "git.url",
      ShellExpr "https://github.com/$GITHUB_REPOSITORY")

    conf.envOrParam("git.commit", ShellExpr "$GITHUB_SHA")
    conf.switch("git.devel", ShellVar("GITHUB_REF").get().split("/")[^1])

  else:
    conf.info "Using local file configuration"
    conf.hrefPref = "file://" & $(conf.projectDir / "docs")





func makeBodyToc*(linkList: string): string =
  """
  <div class="row">
    <div class="three columns">
    <div class="theme-switch-wrapper">
      <label class="theme-switch" for="checkbox">
        <input type="checkbox" id="checkbox" />
        <div class="slider round"></div>
      </label>
     &nbsp;&nbsp;&nbsp; <em>Dark Mode</em>
    </div>
    <div id="global-links">
  """ &
    linklist &
  """
    </div>
    <div id="searchInputDiv">
      Search: <input type="text" id="searchInput"
        onkeyup="search()" />
    </div>
    $tableofcontents
    </div>
    <div class="nine columns" id="content">
    <div id="tocRoot"></div>
    $deprecationMsg
    <p class="module-desc">$moduledesc</p>
    $content
    </div>
  </div>
  """

func wrap3QuoteNL*(str: string): string =
  "\"\"\"" & str & "\"\"\"\n\n"

func newTree*(tag: string,
             subitems: openarray[XmlNode],
             attrs: openarray[(string, string)] = @[]): XmlNode =

  result = newElement(tag)
  for it in subitems:
    result.add it

  # for attr in attrs:
  result.attrs = attrs.toXmlAttributes()



func newTree*(subitems: seq[XmlNode], tag: string): XmlNode =
  newTree(tag, subitems)

func toHtmlList*(tree: FsTree,
                 hrefPref: string,
                 dropnref: int = 0,
                 dropnames: seq[string] = @[]): XmlNode =
  if tree.isDir:
    if tree.basename notin dropnames:
      let sub = tree.sub.mapIt(it.toHtmlList(
        hrefPref = hrefPref,
        dropnref = dropnref,
        dropnames = dropnames
      )).filterIt(it != nil)
      if sub.len > 0:
        return newTree("li", @[newText(tree.basename), newTree("ol", sub)])
  else:
    let url = hrefPref & "/" &
      tree.parent[min(tree.parent.len, dropnref) .. ^1].join("/") & "/" &
        &"{tree.basename}.html"

    return newTree(
      "li",
      @[ newTree("a", @[newText(tree.basename)], {"href" : url}) ])


proc makeDocConf*(linklist: string): string =
  &"""
--hints:off
--verbosity:0
doc.body_toc = {makeBodyToc(linklist).wrap3QuoteNL()}
doc.body_toc_group = {makeBodyToc(linkList).wrap3QuoteNL()}
"""


proc docgenBuild(conf: TaskRunConfig, ignored: seq[GitGlob]) =
  let curr = conf.projectDir.toFsTree()
  var rstfiles: seq[FsTree]
  var errMsg: seq[string]


  let
    files = buildFsTree(allowExts = @["nim", "rst"])
    docConf = cwd() /. "nimdoc.cfg"
    tree = $files.mapIt(it.toHtmlList(
      dropnref = curr.pathLen(),
      dropnames = @["tests"],
      hrefPref = conf.hrefPref
    )).filterIt(it != nil).newTree("ol")

  if not conf.testRun:
    docConf.writeFile makeDocConf(tree)

  conf.notice "Wrote nimdoc configuration to", docConf

  for glob in ignored:
    conf.debug "ignoring: ", glob

  var commands: seq[ShellCmd]
  for file in files.mapIt(it.flatFiles()).concat():
    if not ignored.accept($file):
      conf.notice "Ignoring", $file
      continue

    let dir = conf.outdir / file.parent[curr.pathLen() .. ^1]
    conf.logger.execCode mkDir(dir), conf.testRun

    let outfile = dir /. $file.withoutParent().withExt("html")
    # conf.trace outfile
    if (file.ext in ["nim", "rst"]) and ("tests" notin $file):
      var cmd: ShellCmd
      case file.ext:
        of "rst":
          cmd = makeNimShellCmd("nim").withIt do:
            it.cmd "rst2html"
            it - ("o", outfile)
            it.arg file

        of "nim":
          cmd = makeNimShellCmd("nim").withIt do:
            it.cmd "doc"
            # it - ("cc", "tcc")
            it - ("o", outfile)
            it - ("hints", "off")
            it.arg file

      if not cmd.isEmpty():
        commands.add cmd

  conf.logger.wait "Executing", commands.len, "docgen commands in parallel"
  conf.logger.indented:
    for (res, cmd) in runShellResult(commands.mapIt((it,it))):
      conf.info cmd.prettyShellCmd()

  conf.done()

  if (errMsg.len > 0) and (conf.logFile.len > 0):
    discard

  else:
    conf.notice "Documentation buid ok, no errors detected"
    conf.info &"Saved documentation at path {conf.outdir}"

when cbackend:
  import parsecfg, streams, tables

  func `[]`*(conf: Config, section, key: string): string =
    conf.getSectionValue(section, key)

  proc parseConfig*(str: string, filename: string): Config =
    var s = newStringStream(str)
    loadConfig(s, filename)

  proc parsePackageConf*(): TaskRunConfig =
    let stats = runShell(ShellExpr "nimble dump").stdout
    let conf = parseConfig(stats, "XXX.nimble")
    # echo "conf: ", conf
    return TaskRunConfig(
      author:      conf["", "author"],
      license:     conf["", "license"],
      description: conf["", "desc"],
      packageName: conf["", "name"],
      version:     conf["", "version"],
      srcDir:      conf["", "srcDir"],
      binDir:      conf["", "binDir"],
      projectDir:  cwd()
    )



template initBuildConf*(): TaskRunConfig {.dirty.} =
  block:
    when compiles(thisDir()):
      var tmp = TaskRunConfig(
        packageName: packageName,
        version: version,
        author: author,
        description: description,
        license: license,
        srcDir: srcDir,
        binDir: binDir,
        projectDir: AbsDir thisDir(),
      )
    else:
      var tmp = parsePackageConf()

    tmp.hrefPref = ("https://" & tmp.author & ".github.io/" & tmp.packageName)
    tmp.outdir = AbsDir(tmp.projectDir / "docs")

    tmp

proc runDocGen*(conf: TaskRunConfig, ignored: seq[GitGlob] = @[]): void =
  conf.logger.indented:
    docgenBuild(conf, ignored)



func makeSeparator*(msg: string, col: string): string =
  "\e[" & col & "m" & (
    "  " & msg.alignLeft(46, ' ') & "  ").center(80, '~') & "\e[39m"

proc thisAbsDir*(): AbsDir =
  when compiles(thisDir()):
    AbsDir thisDir()
  else:
    cwd()

const cdMainProject* = ShellExpr("cd /project/main")

proc runDockerTest*(
    projDir, tmpDir: AbsDir,
    cmd: ShellAst,
    logger: HLogger,
    runCb: proc() = (proc() = discard),
    envpass: openarray[tuple[key: ShellVar, val: string]] = @[]
  ): void =
  ## Copy project directory `projDir` into temporary `tmpDir` and
  ## execute command `cmd` inside new docker container based on
  ## `nim-base` image.
  var cmd = cmd
  logger.execCode mkDir(tmpDir)

  for (v, val) in envpass:
    logger.notice &"Passing shell varaible {v.string}={val}"
    cmd = ShellExpr(&"export {v.string}={val}") && cmd

  logger.info cmd.toStr()
  logger.info tmpDir
  let mainDir = tmpDir / "main"
  if mainDir.dirExists:
    rmDir(tmpDir / "main")

  cpDir projDir, (tmpDir / "main")
  logger.notice "copied", projDir, "to", mainDir
  withDir tmpDir / "main":
    runCb()

  let dockerCmd = makeGnuShellCmd("docker").withIt do:
    it.cmd "run"
    it - "i"
    it - "t"
    it - "rm"
    it - ("v", "", $tmpDir & ":/project")
    it.arg "nim-base"
    it.arg "sh"
    it - "c"
    it.expr cmd


  logger.info "Command for docker container"
  logger.debug dockerCmd.toStr().wrapShell()
  logger.notice "Started docker container"
  logger.execShell(dockerCmd)
  logger.notice "Docker container finished run"

proc pkgVersion*(pkg: string): string =
  let res = runShell(ShellExpr "nimble dump " & pkg)
  for line in res.stdout.split("\n"):
    if line.startsWith("version: "):
      return line["version: \"".len() .. ^2]


when cbackend:
  proc getNimbleDump*(pkg: string): Config =
    let stats = runShell(ShellExpr "nimble dump " & pkg).stdout
    return parseConfig(stats, pkg & ".nimble")


  proc makeLocalDevel*(
      testDir: AbsDir, pkgs: seq[string], l: HLogger): ShellAst =
    ## Copy local packages from host to docker container. Useful if you
    ## want to avoid redownloading all packages each time or want to
    ## test something with local version of the package *before* pushing
    ## it to github.
    ##
    ## # Parameters
    ## :testDir: Path to temporary directory, mounted in docker container
    ## :pkgs: List of packages (by name) that will be copied to docker
    # TODO support nimble package syntax to explicitly specify version
    # to be copied to docker.
    if pkgs.len == 0:
      l.debug "Empy list of local development packages; no setup"
      return makeGnuShellCmd("true").toShellAst

    l.info "Copying local development versions"
    l.thisScope("copy local development version for a package")
    let home = getHomeDir()
    for pkg in pkgs:
      let version = getNimbleDump(pkg)["", "version"]

      if dirExists(~&".nimble/pkgs/{pkg}-#head"):
        l.info "Using #head version for", pkg

      elif dirExists(~&".nimble/pkgs/{pkg}-{version}"):
        l.info "Using", version, "for", pkg

      else:
        raise newEnvironmentAssertionError(
          &"Could not find {pkg} in local installations - either run ",
          "`nimble develop` to make it available or install ",
          &"via `nimble install {pkg}`")

    mkDir testDir
    for pkg in pkgs:
      let
        version = getNimbleDump(pkg)["", "version"]
        versionedInstall = home / &".nimble/pkgs/{pkg}-{version}"
        headInstall = home / RelFile(
          &".nimble/pkgs/{pkg}-#head/{pkg}.nimble-link")

      if headInstall.fileExists():
        for nimble in headInstall.readFile().split("\n"):
          let nimble = AbsDir nimble
          if nimble.endsWith(&"{pkg}.nimble"): # XXX
            let dir = parentDir(nimble)
            l.info pkg, "is developed locally, copying from", dir
            cpDir dir, (testDir / pkg)

      elif versionedInstall.dirExists():
        l.info pkg, "is installed locally, copying from", versionedInstall
        cpDir versionedInstall, (testDir / pkg)

      else:
        raise newEnvironmentAssertionError(
          "Neither versioned installation nor #head point to ",
          "existing file. Please make sure that package can is properly ",
          "installed and can be globally imported. Git submodules and ",
          "local installations are not currently supported.")

      result = shAnd(
        result,
        shellCmd(cd, &"/project/{pkg}"),
        shellCmd(nimble, develop, -y)
      )

    result &&= cdMainProject

  proc runDockerTestDevel*(
      startDir, testDir: AbsDir,
      localDevel: seq[string],
      cmd: ShellAst,
      cb: proc(),
      logger: HLogger
    ) =

    let develCmd = makeLocalDevel(testDir, localDevel, logger)
    let cmd = develCmd && ShellExpr("cd " & " /project/main") && cmd

    logger.info "executing docker container"
    logger.trace cmd

    runDockerTest(thisAbsDir(), testDir, cmd, logger) do:
      cb()


proc writeTestConfig*(str: string): void =
  "tests/nim.cfg".writeFile(str.unindent())

proc testAllImpl*(logger: HLogger): void =
  try:
    execShell(ShellExpr "choosenim stable")
    execShell(ShellExpr "nimble test")
    logger.info "Stable test passed"
  except:
    logger.err "Stable test failed"

  try:
    execShell(ShellExpr "choosenim devel")
    execShell(ShellExpr "nimble test")
    logger.info "Devel test passed"

  except:
    logger.err "Devel test failed"

  finally:
    execShell(ShellExpr "choosenim stable")

  try:
    execShell(ShellExpr "nimble install")
    logger.info "Installation on stable OK"

  except:
    logger.err "Installation on stable failed"
