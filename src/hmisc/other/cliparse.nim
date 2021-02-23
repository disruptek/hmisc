import ../algo/hstring_algo
import ../hexceptions
import ../hdebug_misc
import std/[options, strutils, strscans, strformat, macros]
import ../macros/introspection
import hjson

type
  CliOptKind* = enum
    coFlag ## `--flag`
    coDotFlag ## `--help.json`
    coBracketFlag ## `--warn[Relocate]`

    coOpt ## `--opt:value`
    coDotOpt ## `--clang.exe:/bin/clang10`
    coBracketOpt ## `--warn[Noinit]:true`

    coArgument
    coSpecial

  CliAddKind* = enum
    caEqual ## `--key=value`
    caPlusEqual ## `--key+=value`
    caColon ## `--key:value`
    caMinusEqual ## `--key-=value`
    caNoSep ## `-kvalue`
    caCarentEqual ## `--key^=value`
    caEqualNone ## `--key=`

  CliOpt* = object
    rawStr*: string
    kind*: CliOptKind
    shortDash*: bool
    keyPath: seq[string] ## Hello
    keySelect*: string
    valStr*: string
    addKind*: CliAddKind
    optKind*: CliOptKind

  CliErrPolicy* = enum
    ceColorDiagnostics
    ceJsonDiagnostics

  CliParseConfig* = object
    shortOpts*: set[char]
    specialStart*: seq[string]
    blockedAddKinds*: set[CliAddKind]
    errPolicy*: set[CliErrPolicy]
    hasValue*: proc(arg: CliOpt): bool {.noSideEffect.}
    seqSeparator*: string

  CliFailKind* = enum
    cfNoSuchOption
    cfBadCliSyntax
    cfBadCliValue
    cfMissingValue

  CliFail* = object
    argStr*: string
    kind*: CliFailKind
    jsonMsg*: JsonNode
    strMsg*: string


macro scanpFull*(str: string, start: int, pattern: varargs[untyped]): untyped =
  result = nnkStmtList.newTree()
  let tmp = genSym(nskVar, "tmp")
  result.add newVarStmt(tmp, start)
  result.add newCall("scanp", str, tmp)
  for patt in pattern:
    result[^1].add patt

  result = nnkInfix.newTree(
    ident("and"),
    nnkStmtListExpr.newTree(result[0], result[1]),
    nnkInfix.newTree(ident("=="), tmp, newCall("len", str))
  )


macro scanpFull*(str: string, pattern: varargs[untyped]): untyped =
  result = nnkStmtList.newTree()
  let tmp = genSym(nskVar, "tmp")
  result.add newVarStmt(tmp, newLit(0))
  result.add newCall("scanpFull", str, tmp)
  for patt in pattern:
    result[^1].add patt


func classifyCliArg*(arg: string, config: CliParseConfig): CliOptKind =
  var start = 0
  if scanp(arg, start, '-'{1, 2}):
    if start == 1 and arg[start] in config.shortOpts:
      if start == arg.high:
        result = coFlag

      else:
        result = coOpt

    elif scanpFull(arg, start, +`IdentChars`):
      result = coFlag

    elif scanpFull(arg, start, +`IdentChars` ^+ '.'):
      result = coDotFlag

    elif scanpFull(arg, start, +`IdentChars` ^* '.', '[', +`IdentChars`, ']'):
      result = coBracketFlag

    elif scanpFull(arg, start, +`IdentChars`, {':', '='}, +`AllChars`):
      result = coOpt

    elif scanpFull(arg, start, +`IdentChars` ^+ '.', {':', '='}, +`AllChars`):
      result = coDotOpt

    elif scanpFull(arg, start,
                   +`IdentChars` ^* '.', '[', +`IdentChars`, ']',
                   {':', '='}, +`AllChars`
    ):
      result = coBracketOpt

    else:
      debugecho "fail", start, " -> ", arg[start .. ^1]

  else:
    result = coArgument

func splitCliArgs*(args: seq[string], config: CliParseConfig): seq[string] =
  for arg in args:
    if arg["--"] or not arg["-"]:
      result.add arg

    else:
      var pos: int = 1
      while arg[pos] in config.shortOpts:
        result.add &"-{arg[pos]}"
        inc pos

      result[^1] &= arg[pos .. ^1]

func splitFlag*(arg: string, config: CliParseConfig): tuple[
    keyPath: seq[string], keySelector: string, value: string, dashes: string
  ] =

  var
    pos = 0
    prefix: string

  discard scanp(arg, pos, '-'{1, 2} -> result.dashes.add($_))
  discard scanp(arg, pos, (+`IdentChars` ^* '.') -> prefix.add($_))
  result.keyPath = split(prefix, ".")

  if result.dashes.len == 1 and prefix[0] in config.shortOpts:
    result.value = prefix[1 .. ^1]
    result.keyPath = @[$prefix[0]]

  else:
    discard scanp(arg, pos, '[', +`IdentChars` -> result.keySelector.add($_), ']')
    discard scanp(arg, pos, {':', '='})
    if pos < arg.len:
      discard scanp(arg, pos, +`AllChars` -> result.value.add($_))

  result.value = result.value.strip(chars = {'\''})

func parseFlag*(arg: string, config: CliParseConfig): CliOpt =
  let (path, selector, _, dashes) = splitFlag(arg, config)
  result = CliOpt(keyPath: path, shortDash: dashes.len == 1, rawStr: arg)

  if selector.len == 0:
    if path.len == 1:
      result.kind = coFlag

    else:
      result.kind = coDotFlag

  else:
    result.kind = coBracketFlag
    result.keySelect = selector



func parseOpt*(arg: string, config: CliParseConfig): CliOpt =
  result = parseFlag(arg, config)
  let (_, _, value, _) = splitFlag(arg, config)
  case result.kind:
    of coFlag: result.kind = coOpt
    of coDotFlag: result.kind = coDotOpt
    of coBracketFlag: result.kind = coBracketOpt
    else: discard

  result.valStr = value

func parseArgument*(arg: string, config: CliParseConfig): CliOpt =
  result = CliOpt(kind: coArgument, rawStr: arg, valStr: arg)

func parseSpecial*(arg: string, config: CliParseConfig): CliOpt =
  result = CliOpt(kind: coSpecial, rawStr: arg)

func parseCliOpts*(args: seq[string], config: CliParseConfig): tuple[
  parsed: seq[CliOpt], failed: seq[CliFail]
] =

  let args = splitCliArgs(args, config)
  var pos: int = 0
  while pos < args.len:
    case classifyCliArg(args[pos], config):
      of coFlag, coDotFlag, coBracketFlag:
        var flag = parseFlag(args[pos], config)
        if not isNil(config.hasValue) and config.hasValue(flag):
          # FIXME classify next value, switch flag
          flag.valStr = args[pos + 1]
          inc pos

        result.parsed.add flag

      of coOpt, coDotOpt, coBracketOpt:
        result.parsed.add parseOpt(args[pos], config)

      of coArgument:
        result.parsed.add parseArgument(args[pos], config)

      of coSpecial:
        result.parsed.add parseSpecial(args[pos], config)

    inc pos

func cliParse*(
  arg: string, res: var int, config: CliParseConfig): Option[CliFail] =

  try:
    res = parseInt(arg)

  except ValueError as e:
    result = some CliFail(strMsg: e.msg, kind: cfBadCliValue)

func cliParse*(
  arg: string, res: var float, config: CliParseConfig): Option[CliFail] =

  try:
    res = parseFloat(arg)

  except ValueError as e:
    result = some CliFail(strMsg: e.msg, kind: cfBadCliValue)

func cliParse*[En: enum](
  arg: string, res: var En, config: CliParseConfig): Option[CliFail] =

  const map = enumNamesTable(En)
  let arg = arg
  var found = false

  block mainSearch:
    for (names, val) in map:
      for name in names:
        if name == arg:
          res = val
          found = true
          break mainSearch


  if not found:
    var allnames: seq[string]
    for (names, _) in map:
      allnames &= names

    result = some CliFail(
      strMsg: stringMismatchMessage(arg, allnames)
    )

when isMainModule:
  let conf = CliParseConfig(shortOpts: {'W', 'q'})
  type
    Test = enum
      tNone
      tFirst = "ovewrite"
      tSecond = "overwrite2"

  var res: Test
  let err = cliParse("First", res, conf)

  let strs = @[
    "--flag",
    "--flag.sub",
    "--flag[Bracket]",
    "--opt=value",
    "--opt:123",
    "--opt.sub=val",
    "--opt.sub[Selector]=value",
    "--top[Switch1]:argument",
    "Sub1",
    "--field1:'str-argument'",
    "--field2:0.3",
    "/tmp/test.txt",
    "-Wnone",
    "-qWnone"
  ]

  for arg in strs:
    echo &"{arg:<30}{classifyCliArg(arg, conf)}"

  startHax()
  for opt in parseCliOpts(strs, conf).parsed:
    echo &"{opt.keyPath:<20}{opt.keySelect:<10}{opt.valStr:20} [{opt.rawStr}]"
