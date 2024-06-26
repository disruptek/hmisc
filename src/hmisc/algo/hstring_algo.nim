import std/[
  sequtils, strformat, strutils,
  parseutils, macros, algorithm, tables, random
]

import
  ../core/[exceptions, gold],
  ./hseq_distance




type
  StrBackIndex* = distinct string
  CharBackIndex* = distinct char
  StrPartKind* = enum
    spkSet
    spkSubstr

  IdentStyle* = enum
    idsNone

    idsSnake
    idsCamel

  StringAlignDirection* = enum
    sadLeft
    sadRight
    sadCenter


  StrPart* = object
    case kind: StrPartKind
      of spkSet:
        chars*: set[char]
      of spkSubstr:
        strs*: seq[string]

  StrPartTuple* = tuple[lhs, rhs: StrPart]
  StrPartConv* = char | set[char] | string | seq[string] |
    openarray[string]

converter toStrPart*(c: char): StrPart =
  StrPart(kind: spkSet, chars: {c})

converter toStrPart*(s: string): StrPart =
  StrPart(kind: spkSubstr, strs: @[s])

converter toStrPart*(s: openarray[string]): StrPart =
  StrPart(kind: spkSubstr, strs: toSeq(s))

converter toStrPart*(cs: set[char]): StrPart =
  StrPart(kind: spkSet, chars: cs)

converter toStrPartTuple*[A: StrPartConv, B: StrPartConv](
  indata: (A, B)): StrPartTuple =

  (
    lhs: toStrPart(indata[0]),
    rhs: toStrPart(indata[1])
  )


func startsWith*(s: string, part: StrPart): bool =
  case part.kind:
    of spkSet:
      return (s.len > 0) and (s[0] in part.chars)
    else:
      for elem in part.strs:
        if s.startsWith(elem):
          return true


      return false

func skip1*(s: string, part: StrPart): int =
  case part.kind:
    of spkSet:
      if s.len > 0 and s[0] in part.chars:
        result = 1

      else:
        result = 0

    else:
      for elem in part.strs:
        if s.startsWith(elem):
          return elem.len

      result = 0



func endsWith*(s: string, part: Strpart): bool =
  case part.kind:
    of spkSet:
      return (s.len > 0) and (s[^1] in part.chars)
    else:
      for elem in part.strs:
        if s.endsWith(elem):
          return true


      return false

{.push inline.}

func `^`*(s: string): StrBackIndex = StrBackIndex(s)
func `^`*(s: char): CharBackIndex = CharBackIndex(s)

func `[]`*(ins: string, back: StrBackIndex): bool =
  ins.endsWith(back.string)

func `[]`*(ins: string, back: CharBackIndex): bool =
  ins.endsWith(back.char)

func `[]`*(ins: string, forward: string|char): bool =
  ins.startsWith(toStrPart(forward))

func `[]`*(ins: string, strs: openarray[string]): bool =
  ins.startsWith(strs)

func `[]`*(ins: string, beg: StrPart, final: StrPartConv): bool =
  ins.startsWith(beg) and ins.endsWith(toStrPart(final))

func `[]`*(ins: string, beg: StrPart, final: openarray[string]): bool =
  ins[beg, toSeq(final)]


iterator items*(part: StrPart): StrPart =
  case part.kind:
    of spkSet:
      for ch in part.chars:
        yield toStrPart(ch)

    of spkSubstr:
      for s in part.strs:
        yield toStrPart(s)

func len*(part: StrPart): int {.inline.} =
  case part.kind:
    of spkSet:
      if part.chars.len == 0:
        0
      else:
        1
    of spkSubstr:
      if part.strs.len == 1:
        part.strs[0].len
      elif part.strs.len == 0:
        0
      else:
        raise newArgumentError(
          "Cannot get length for string part with more that one substring")


func contains*(str: string, parts: varargs[StrPart, toStrPart]): bool =
  for part in parts:
    case part.kind:
      of spkSet:
        for c in str:
          if c in part.chars:
            return true
      of spkSubstr:
        for sub in part.strs:
          if sub in str:
            return true


func dropPrefix*(str: string, part: StrPart): string =
  for alt in part:
    if str.startsWith(alt):
      return str[min(alt.len, str.len)..^1]

  return str

func dropPrefix*(str: string, alt: string): string =
  if str.startsWith(alt):
    return str[min(alt.len, str.len)..^1]

  return str

func dropNormPrefix*(str: string, prefix: string): string =
  var outStart = 0
  var inPos = 0
  var matches = true
  while outStart < str.len and inPos < prefix.len and matches:
    if str[outStart] in {'_'}:
      inc outStart

    elif prefix[inPos] in {'_'}:
      inc inPos

    elif str[outStart].toLowerAscii() == prefix[inPos].toLowerAscii():
      inc outStart
      inc inPos

    else:
      matches = false

  if inPos == prefix.len:
    while outStart < str.len and str[outStart] in {'_'}: inc outStart

    return str[outStart .. ^1]

  else:
    return str


func dropPrefix*(ss: seq[string], patt: StrPart): seq[string] =
  for s in ss:
    result.add s.dropPrefix(patt)


func dropSuffix*(str: string, part: StrPart): string =
  for alt in part:
    if str.endsWith(alt):
      return str[0 ..^ (alt.len + 1)]

  return str


func toUpperAscii*(strs: seq[string]): seq[string] {.inline.} =
  for str in strs:
    result.add toUpperascii(str)



func startsWith*(str: string; skip: set[char], pref: string): bool =
  ## Return true if string has prefix `<skip*><pref>` - one or more
  ## occurencies of chars in `skip` set, followed by prefix.
  (str.len > 0) and str[str.skipWhile(skip)..^1].startsWith(pref)


func startsWith*(str: string; skip: set[char], pref: set[char]): bool =
  ## Return true if string has prefix `<skip*><pref>` - one or more
  ## occurencies of chars in `skip` set, followed by prefix.
  (str.len > 0) and str[str.skipWhile(skip)..^1].startsWith(pref)

func startsWith*(str: string, pref: varargs[string]): bool =
  ## True if string starts with any of the prefixes
  result = false
  for pr in pref:
    if str.startsWith(pr):
      return true

func endsWith*(str: string, suffixes: varargs[string]): bool =
  ## True if string ends with any of the suffixes
  result = false
  for suff in suffixes:
    if str.endsWith(suff):
      return true


func findEnd*(str: string, sub: string, start: Natural = 0, last = 0): int =
  result = str.find(sub, start, last)
  if result >= 0:
    result += sub.len

func addIndent*(
    res: var string, level: int, sep: int = 2, prefix: char = ' ') =
  if sep == 2 and prefix == ' ':
    case level:
      of 0: res &= ""
      of 1: res &= "  "
      of 2: res &= "    "
      of 3: res &= "      "
      of 4: res &= "        "
      of 5: res &= "          "
      of 6: res &= "            "
      of 7: res &= "              "
      of 8: res &= "                "
      of 9: res &= "                  "
      of 10: res &= "                    "
      else: res &= repeat(prefix, level * sep)

  else:
    res &= repeat(prefix, level * sep)

func getIndent*(level: int, sep: int = 2, prefix: char = ' '): string =
  result.addIndent(level, sep, prefix)

func join*(text: openarray[(string, string)], sep: string = " "): string =
  text.mapIt(it[0] & it[1]).join(sep)

func join*(text: openarray[string], sep: char = ' '): string =
  text.join($sep)


func wrap*(
  str: string,
  delim: tuple[left, right: string]): string =
  ## Check if string starts and ends with strings.
  return delim.left & str & delim.right

func wrap*(str, left, right: string): string =
  wrap(str, (left, right))


func wrap*(str: string, delim: string): string =
  ## Split `delim` in two, use wrap `str` in left and right halves.
  let left = delim.len div 2
  return delim[0 ..< left] & str & delim[left .. ^1]

func wrap*(str: string, left, right: char): string {.inline.} =
  $left & str & $right

func joinl*(inseq: openarray[string]): string =
  ## Join items using newlines
  inseq.join("\n")

func joinql*(
  inseq: openarray[string], ident: int = 1,
  wrap: string = "\"", identStr: string = "  "): string =

  inseq.mapIt(identStr.repeat(ident) & wrap & it & wrap).join("\n")

func joinkv*[K, V](
  t: openarray[(K, V)], eqTok: string = "="): seq[string] =
  ## Join table values as key-value pairs
  for k, v in t:
    result.add &"{k} {eqTok} {v}"

proc joinw*(inseq: openarray[string], sep = " "): string =
  ## Join items using spaces
  inseq.join(sep)

func joinq*(inseq: openarray[string], sep: string = " ", wrap: string = "\""): string =
  ## Join items using spaces and quote each item
  inseq.mapIt(wrap & it & wrap).join(sep)

func join*[T](obj: T, sep: string, wrap: (string, string)): string =
  var first: bool = true
  for elem in obj:
    if not first:
      result &= sep
    else:
      first = false

    result &= wrap[0] & $elem & wrap[1]


proc indentBody*(
    str: string,
    count: int,
    indent: string = " ",
    prefix: string = ""
  ): string =

  let nl = str.find('\n')
  if nl != -1:
    result.add str[0 .. (nl - 1)]
    for line in split(str[nl + 1 .. ^1], {'\n'}):
      result.add "\n"
      result.add repeat(indent, count - prefix.len)
      result.add prefix
      result.add line

  else:
    result = str


proc `|<<`*(str: string, align: int): string = alignLeft(str, align)

proc `|>>`*(str: string, align: int): string = align(str, align)

proc `|<<`*(str: string, align: (int, char)): string =
  alignLeft(str, align[0], align[1])

proc `|>>`*(str: string, align: (int, char)): string =
  align(str, align[0], align[1])

proc `|<>`*(
    str: string, align: tuple[width: int, wrapl, wrapr: char]): string =

  result.add align.wrapl
  result.add center(str, align.width - 2, ' ')
  result.add align.wrapr

proc `|<>`*(
    str: string, align: tuple[width: int, pad, wrapl, wrapr: char]): string =

  result.add align.wrapl
  result.add center(str, align.width - 2, align.pad)
  result.add align.wrapr




func msgjoinImpl*(args: seq[string]): string =
  var openwrap: bool = false
  let max = args.len - 1
  var idx = 0
  const wraps: set[char] = {'_', '`', '\'', '\"', ' '}
  while idx < args.len:
    if args[idx].startsWith(wraps):
      if args[idx].allIt(it in wraps):
        result &= args[idx]
        inc idx

      while idx < args.len:
        result &= args[idx]
        inc idx

        if not idx < args.len: break
        if args[idx].endsWith(wraps):
          if idx < args.len - 1: result &= " "
          break

    else:
      if args[idx].endsWith({'[', '(', '\'', '#', '@'} + wraps):
        # Most likely a `"some text[", var, "] else"`
        # debugecho "22_"
        result &= args[idx]
      elif idx < max and args[idx + 1].startsWith({',', ' ', '.'}):
        # Next argument is `".field"`, `" space"` etc.
        # debugecho "122 _as"
        result &= args[idx]
      else:
        # debugecho "else"
        result &= args[idx]
        if idx < max: result &= " "

      inc idx





func msgjoin*(args: varargs[string, `$`]): string =
  ## Concatenate arguments by adding whitespaces when necessary. When
  ## string ends with `_`, `'`, `"` or other similar characters (used
  ## when wrapping things like in `msgjoin("_", text, "_")`).
  ## Whitespace is omitted when strings *ends with* any of `[('#@` +
  ## wrapper characters or next one *starts with* `, .` + wrapper
  ## characters. Wrapper characters are: `_' "`
  msgjoinImpl(toSeq(args))



































func addSuffix*(str, suff: string): string =
  ## Add suffix `suff` if not already present
  if str.endsWith(suff):
    return str
  else:
    return str & suff

func addPrefix*(str: var string, pref: string): void =
  ## Add prefix to string if it not starts with `pref`
  if not str.startsWith(pref):
    str = pref & str

func addPrefix*(str, pref: string): string =
  ## Add prefix to string if it not starts with `pref`
  if not str.startsWith(pref):
    pref & str
  else:
    str

func addPrefix*(str: seq[string], pref: string): seq[string] =
  for s in str:
    result.add s.addPrefix(pref)

func commonPrefix*(strs: seq[string]): string =
  ## Find common prefix for list of strings
  # TODO implement without sorting
  if strs.len == 0:
    return ""
  else:
    let strs = strs.sorted()
    for i in 0 ..< min(strs[0].len, strs[^1].len):
      if strs[0][i] == strs[^1][i]:
        result.add strs[0][i]
      else:
        return



func delete*(str: string, chars: set[char]): string =
  for c in str:
    if c notin chars:
      result &= c

func delete*(str: var string, chars: set[char]) =
  var tmp: string
  for c in str:
    if c notin chars:
      tmp &= c

  str = tmp






func enclosedIn*(str: string, delim: StrPartTuple): bool =
  ## Check if string starts and ends with strings.
  str.startsWith(delim.lhs) and str.endsWith(delim.rhs)

func enclosedIn*(str: string, delim: StrPart): bool =
  ## Check if string starts and ends with strings.
  return str.startsWith(delim) and str.endsWith(delim)

func filterPrefix*(str: seq[string], pref: StrPart): seq[string] =
  ## Return only strings that have prefix in `pref`
  for s in str:
    if s.startsWith(pref):
      result.add s







macro joinLiteral*(body: untyped): untyped =
  if body.kind == nnkStmtList:
    result = newLit(msgjoin body.mapIt(it.strVal()))

  elif body.kind in {nnkStrLit, nnkTripleStrLit}:
    result = body

  else:
    error(
      "Expected either list of string literals or single literal", body)

template fmtJoin*(body: untyped): untyped =
  fmt(joinLiteral(body))





proc getKeys*[K, V](t: Table[K, V] | TableRef[K, V]): seq[K] =
  for key, value in pairs(t):
    result.add key

func escapeHTML*(input: string): string =
  input.multiReplace([
    (">", "&gt;"),
    ("<", "&lt;"),
    ("&", "&amp;"),
    ("\"", "&quot;")
  ])


func escapeStrLit*(input: string): string =
  input.multiReplace([
    ("\"", "\\\""),
    ("\n", "\\n"),
    ("\\", "\\\\")
  ])

func enclosedIn*(s: string, delim: string): bool =
  s.enclosedIn((delim, delim))

proc getRandomBase64*(length: int): string =
  ## Return random base 64 string with `length` characters
  newSeqWith(
    length,
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".
    sample()).join("")

when (NimMajor, NimMinor, NimPatch) <= (1, 2, 6):
  func dedent*(multiline: string): string =
    ## Uniformly deindent multiline string
    let seplines = multiline.split('\n')
    var indent = 0
    for c in seplines[0]:
      if c == ' ': inc indent
      else: break

    seplines.mapIt(
      if it.len == 0:
        it
      else:
        assert it[0..<indent].allOfIt(it == ' '),
          "Cannot unindent non-whitespace character"

        it[indent..^1]
    ).join("\n")
else:
  export dedent


func dropCommonPrefix*(
  strs: seq[string], dropSingle: bool = true): seq[string] =
  ## Drop common prefix from sequence of strings. If `dropSingle` is
  ## false sequences with `len == 1` are returned as-is.
  if not dropSingle and strs.len == 1:
    return strs

  let pref = strs.commonPrefix()
  for str in strs:
    result.add str.dropPrefix(pref)

func splitTokenize*(str: string, seps: seq[string]): seq[string] =
  var prev = 0
  var curr = 0
  # var cnt = 0
  while curr < str.len:
    # inc cnt
    # if cnt > 20:
    #   break

    # debugecho curr, result, str[prev .. curr]
    block nextSep:
      for sep in seps:
        if str.continuesWith(sep, curr):
          if prev != curr:
            result.add str[prev ..< curr]
            prev = curr

          curr += sep.len
          result.add str[prev ..< curr]
          prev = curr
          break nextSep

      inc curr


func splitTokenize*(str: string, seps: set[char], sweep: bool = false): seq[string] =
  var prev = 0
  var curr = 0
  while curr < str.len:
    if str[curr] in seps:
      if prev != curr:
        result.add str[prev ..< curr]

      if sweep:
        prev = curr
        while curr < str.high and str[curr + 1] == str[curr]:
          inc curr

        result.add str[prev .. curr]
        inc curr
        prev = curr

      else:
        result.add $str[curr]
        inc curr
        prev = curr

    else:
      inc curr

  if prev < curr:
    result.add str[prev ..< curr]


func splitCamel*(
    str: string,
    dropUnderscore: bool = true,
    splitUnderscores: bool = true,
    mergeCapitalized: bool = true,
    adaptiveMerge: bool = true
  ): seq[string] =
  ##[

Split abbreviation as **camelCase** identifier

- @arg{dropUnderscore} :: Drop all `_` characters if found
- @arg{splitUnderscores} :: Split on `_` characters
- @arg{mergeCapitalized} :: Do not split consecutive capitalized
- @arg{adaptiveMerge} :: Employ additional heuristics to make
  capitalized chunk splits more 'logical'. `DBManager -> DB + Manager`,
  but `FILE -> FILE`

  ]##
  # TODO handle `kebab-style-identifiers`
  # TODO Split things like `ABBRName` into either `ABBR, Name` or
  #      `A, B, B ...`
  var pos = 0


  var dropSet: set[char]
  if splitUnderscores:
    dropset.incl '_'

  const capital = {'A' .. 'Z'}

  var splitset = capital + dropset

  while pos < str.len:
    var start = pos
    var next: int
    if  str[pos] in capital and mergeCapitalized:
      next = start + str.skipWhile(capital, start + 1)
      if adaptiveMerge:
        if next == start:
          next = next + str.skipUntil(splitset, next + 1)

        elif next > start + 1 and
             next < str.high and
             str[next + 1] notin splitset:
          dec next

      else:
        next = next + str.skipUntil(splitset, next + 1)

    else:
      next = start + str.skipUntil(splitset, start + 1)

    if str[start] == '_' and dropUnderscore:
      inc start

    # echov str[start..next]
    # echov (start, next)

    if str[start..next].allIt(it in {'_'}) and dropUnderscore:
      discard
    else:
      result.add str[start..next]

    pos = next + 1

func splitSnake*(str: string): seq[string] =
  for part in split(str, '_'):
    if part.len > 0:
      result.add part

func abbrevSnake*(str: string): string =
  for part in splitSnake(str):
    result.add toLowerAscii(part[0])


func fixCapitalizeAscii*(str: string): string =
  ## Capitalize ascii string first character, and lowercase all other.
  result.add toUpperAscii(str[0])
  for ch in str[1..^1]:
    result.add toLowerAscii(ch)

func toSnakeCase*(str: string): string =
  str.splitCamel().mapIt(it.toLowerAscii()).join("_")

func toSnakeCamelCase*(str: string): string {.
    deprecated: "Use `snakeToCamelCase` instead".} =

  str.splitSnake().mapIt(it.fixCapitalizeAscii()).join("")

func toDashedCase*(str: string): string =
  var prevDash = true
  for idx, ch in str:
    case ch:
      of {'a' .. 'z'}:
        result.add ch
        prevDash = false

      of {'A' .. 'Z'}:
        result.add toLowerAscii(ch)
        prevDash = false

      else:
        if prevDash:
          discard

        else:
          result.add '-'





func snakeToCamelCase*(str: string): string =
  for part in splitSnake(str):
    result.add fixCapitalizeAscii(part)

  # str.split("_").filterIt(it.len > 0).mapIt(
  #   it.toLowerAscii().capitalizeAscii()).join("")

func keepNimIdentChars*(str: string): string =
  ## Remove all non-identifier characters and collapse multiple
  ## underscrores into single one. Remove all leading underscores.
  result = str[str.find(AllChars - {'_'}) .. ^1]
  result.delete(AllChars - IdentChars)
  while find(result, "__") != -1:
    result = result.replace("__", "_")

# func snakeToCamel*(str: string): string =
#   var idx = 0
#   for text in str.split("_"):
#     if idx == 0:
#       for ch in text: result.add toLowerAscii(ch)

#     else:
#       if text.len > 0:
#         result.add toUpperAscii(text[0])
#         for ch in text[1..^1]:
#           result.add toLowerAscii(ch)

#     if text.len > 0:
#       inc idx



proc abbrevCamel*(
    abbrSplit: seq[string],
    splitWords: seq[seq[string]],
    getExact: bool = false
  ): seq[string] =
  ## Split abbreviation and all worlds as **camelCase** identifiers.
  ## Find all worlds that contains `abbrev` as subsequence.
  let abbr = abbrSplit.join("")
  for word in splitWords:
    # HACK When I switched to 1.6.0 `longestCommonSubsequence` can no
    # longer be called due to absolutely arbitrary type mismatch error - I
    # passed closure callback to it earlier, but now nim (for some reason)
    # thinks this callback has calling convention `{.inline.}` *even if I
    # move it to the toplevel, annotate with `{.nimcall.}`, or explicitly
    # *cast* to requried signature. There is some unwanted conversion
    # injection going on, but I can' really be sure about that, since I
    # can't just dump typed AST to see what is going on.
    let lcs = longestCommonSubsequenceForStringStartsWith(
      abbrSplit, word)

    if lcs.len > 0:
      if lcs[0].matches.len == abbrSplit.len:
        let word = word.join("")
        if getExact and word == abbr:
          return @[word]
        else:
          result.add word

proc abbrevCamel*(
    abbrev: string,
    words: seq[string],
    getExact: bool = false
  ): seq[string] =
  ## Split abbreviation and all worlds as **camelCase** identifiers.
  ## Find all worlds that contains `abbrev` as subsequence. `getExact`
  ## - if any of the alternatives fully matches input word return it
  ## as only result
  ##
  ## To avoid ambiguous returns on tests like `"Else", @["Else",
  ## "ElseBlock"]`)
  abbrevCamel(abbrev.splitCamel(), words.mapIt(it.splitCamel()))

func posString*(node: NimNode): string =
  let info = node.lineInfoObj()
  return "on line " & $info.line

func mismatchStart*(str1, str2: string): int =
  ## Find position where two strings mismatch first
  # TODO implement mismatch with support for multiple
  # matching/mismatching sections - use larges common subsequence to
  # determine differences

  # NOTE can use annotation highlighter from code error reporting
  # `hmisc/defensive`

  # TODO support multiline strings (as sequence of strigns and as
  # single multiline strings)
  for i in 0 ..< min(str1.len(), str2.len()):
    if str1[i] != str2[i]:
      return i

  if str1.len() != str2.len():
    # Have common prefix but second one is longer
    return min(str1.len(), str2.len()) + 1
  else:
    # No mismatch found
    return -1

func joinCamel*(ins: openarray[string]): string =
  for elem in ins:
    result.add elem.capitalizeAscii()

  result[0] = result[0].toLowerAscii()



func replaceN*(str: string, n: int, subst: char = ' '): string =
  ## Replace first `n` characters in string with `subst`
  result = str
  for i in 0..<min(str.len, n):
    result[i] = subst





func dashedWords*(
  str: string,
  toDash: set[char] = {'-', '_', ' ', '.', ',', ';', ':'},
  toLower: set[char] = {'a'..'z', 'A'..'Z', '0'..'9'}): string =

  for ch in str:
    if ch in toDash:
      result &= '-'
    elif ch in toLower:
      result &= ch.toLowerAscii()

func makeCommentSection*(str: string, level: range[0..2]): string =
  ## Generate separation comment
  case level:
    of 2:
      &"# ~~~~ {str} ~~~~ #"
    of 1:
      "#" & center(" " & str.strip() & " ", 73, '=') & "#"
    of 0:
      "#" & "*".repeat(73) & "#\n" &
      "#" & center(" " & str.strip() & " ", 73, '*') & "#\n" &
      "#" & "*".repeat(73) & "#"

macro lit3*(arg: string{lit}): untyped =
  result = arg
  result.strVal = arg.strVal().dedent()

macro fmt3*(arg: string{lit}): untyped =
  result = arg
  result.strVal = arg.strVal().dedent()
  let fmt = bindSym("fmt")
  result = newCall(fmt, result)


type
  InterpolatedExprKind* = enum
    ## Describes for `interpolatedFragments` which part of the interpolated
    ## string is yielded; for example in "str$$$var${expr}"

    iekStr                  ## ``str`` part of the interpolated string
    iekDollar               ## escaped ``$`` part of the interpolated string
    iekVar                  ## ``var`` part of the interpolated string
    iekExpr                 ## ``expr`` part of the interpolated string
    iekIndex


iterator interpolatedExprs*(s: string):
  tuple[kind: InterpolatedExprKind, value: string] =

  var i = 0
  var kind: InterpolatedExprKind

  while true:
    var j = i
    if j < s.len and s[j] == '$':
      if j+1 < s.len and s[j+1] == '{':
        inc j, 2
        var nesting = 0
        block curlies:
          while j < s.len:
            case s[j]:
              of '{': inc nesting
              of '}':
                if nesting == 0:
                  inc j
                  break curlies
                dec nesting
              else: discard

            inc j
          raise newException(ValueError,
            "Expected closing '}': " & substr(s, i, s.high))
        inc i, 2 # skip ${
        kind = iekExpr
      elif j+1 < s.len and s[j+1] in IdentStartChars:
        inc j, 2
        while j < s.len and s[j] in IdentChars: inc(j)
        inc i # skip $
        kind = iekVar

      elif j+1 < s.len and s[j+1] == '$':
        inc j, 2
        inc i # skip $
        kind = iekDollar

      elif j + 1 < s.len and s[j + 1] in {'0' .. '9'}:
        inc j, 2
        while j < s.len and s[j] in {'0' .. '9'}: inc(j)
        inc i # skip $
        kind = iekIndex

      else:
        raise newException(ValueError,
          "Unable to parse a variable name at " & substr(s, i, s.high))
    else:
      while j < s.len and s[j] != '$': inc j
      kind = iekStr

    if j > i:
      # do not copy the trailing } for iekExpr:
      yield (kind, substr(s, i, j-1-ord(kind == iekExpr)))

    else:
      break
    i = j




func findLineRange*(
    base: string,
    start: Slice[int],
    around: (int, int) = (0, 0)
  ): Slice[int] =
  result = start

  var
    before = around[0]
    after = around[1]

  while result.a > 0 and base[result.a] != '\n':
    dec result.a

  while before > 0:
    dec result.a
    while result.a > 0 and base[result.a] != '\n':
      dec result.a

    dec before

  if result.a < 0: result.a = 0
  if base[result.a] == '\n':
    inc result.a


  while result.b < base.len and base[result.b] != '\n':
    inc result.b

  while after > 0:
    inc result.b
    while result.b < base.len and base[result.b] != '\n':
      inc result.b

    dec after

  if result.b > base.high: result.b = base.high
  if base[result.b] == '\n': dec result.b



func lineTextAround*(
    base: string, charRange: Slice[int], around: (int, int) = (1, 1)):
  tuple[text: string, startPos, endPos: int] =
  var slice = base.findLineRange(charRange, around)
  result.text = base[slice]
  result.startPos = charRange.a - slice.a
  result.endPos = result.startPos + (charRange.b - charRange.a)

func linesAround*(
    base: string, line: int, around: (int, int) = (1, 1)):
  seq[string] =

  var
    currLine = 1
    pos = 0

  while pos < base.len and currLine < line:
    if base[pos] == '\n': inc currLine
    inc pos

  let (text, _, _) = lineTextAround(base, pos .. pos, around)
  if line == 1 and around[0] > 0:
    result &= @[""]

  result &= text.split('\n')

func numerateLines*(text: string): string =
  let split = splitLines(text)
  let ind =
    case split.len:
      of 0 .. 9: 1
      of 10 .. 99: 2
      of 100 .. 999: 3
      of 1000 .. 9999: 4
      of 10000 .. 99999: 5
      else: 7

  for idx, line in split:
    if idx > 0:
      result.add "\n"

    result.add align($(idx + 1), ind)
    result.add line
