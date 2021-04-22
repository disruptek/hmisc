import std/[strutils, strformat, parseutils,
            options, segfaults]
import ../base_errors, ../hdebug_misc
import ./hlex_base, ./hstring_algo, ./hseq_mapping, ./halgorithm

type
  HsTokTree*[Rule, Tok] = object
    case isToken*: bool
      of true:
        token*: Tok

      of false:
        rule*: Rule
        subnodes*: seq[HsTokTree[Rule, Tok]]

  HsTok*[K: enum] = object
    kind*: K
    str*: string

  HsLexer*[Tok] = object
    tokens*: seq[Tok]
    cb*: HsLexCallback[Tok]
    pos*: int
    str*: ptr PosStr

  HsLexCallback*[T] = proc(str: var PosStr): Option[T]
  HsTokPredicate*[T] = proc(tok: T): bool

  ParseError = object

  ParseResult[Val] = object
    case ok*: bool
      of true:
        value*: Val

      of false:
        fail*: ParseError

  HsParseCallback*[T, Val] = proc(toks: var HsLexer[T]): ParseResult[Val]

proc initTok*[K](str: var PosStr, kind: K): HsTok[K] =
  HsTok[K](str: str.popRange(), kind: kind)

proc initTok*[K](kind: K): HsTok[K] = HsTok[K](kind: kind)

proc initTok*[K](str: char | string, kind: K): HsTok[K] =
  HsTok[K](str: $str, kind: kind)

func strVal*[K: enum](tok: HsTok[K]): string = tok.str

proc initCharTok*[Cat: enum](
    str: var PosStr,
    map: static[openarray[tuple[key: char, val: Cat]]]
  ): HsTok[Cat] =
  let ch = str.popChar()
  initTok(ch, mapChar(ch, map))

func isFail*[T](parse: ParseResult[T]): bool = not parse.ok
func isOk*[T](parse: ParseResult[T]): bool = parse.ok
func initParseResult*[T](value: T): ParseResult[T] =
  ParseResult[T](ok: true, value: value)

func initParseResult*[T](value: seq[T]): ParseResult[seq[T]] =
  ParseResult[T](ok: true, value: value)


func initParseResult*[Tfrom, Tto](res: ParseResult[Tfrom]): ParseResult[Tto] =
  if res.isFail():
    ParseResult[Tto](ok: false, fail: res.fail)

  else:
    initParseResult[Tto](res.value)

func initParseResult*[T](fail: ParseError): ParseResult[T] =
  ParseResult[T](ok: false, fail: fail)

func add*[T](res: var ParseResult[seq[T]], value: seq[T] | T) =
  res.value.add value

func add*[T](res: var ParseResult[seq[T]], value: ParseResult[T]) =
  res.value.add value.value

proc get*[V](parseResult: ParseResult[V]): V =
  return parseResult.value

func `$`*[K](tok: HsTok[K]): string =
  var kindStr = $tok.kind
  kindStr = kindStr[kindStr.skipWhile(LowerAsciiLetters) .. ^1]

  var str = tok.str
  if not(str['"'] and str[^'"']):
    str = str.wrap('"', '"')

  return &"({kindStr} {str})"

func `@`*[T](lex: HSLexer[T]): seq[T] = lex.tokens[lex.pos .. ^1]
func `$`*[T](lex: HSLexer[T]): string =
  result = &"[{lex.pos}: "
  for idx, token in pairs(lex.tokens[lex.pos .. ^1]):
    if idx > 0:
      result &= ", "

    result &= $token

  result &= "]"

func resetBuffer*[T](lex: var HSLexer[T]) =
  lex.pos = 0
  lex.tokens.setLen(0)

func nextToken*[T](lex: var HSLexer[T]): T =
  var tok: Option[T]
  while tok.isNone():
    tok = lex.cb(lex.str[])

  return tok.get()

func fillNext*[T](lex: var HSLexer[T], chars: int) =
  let needed = chars - (lex.tokens.len - lex.pos - 1)
  if needed > 0:
    for _ in 0 ..< needed:
      lex.tokens.add nextToken(lex)

func haxNxt*[T](lex: HsLexer[T], offset: int): bool =
  lex.pos + offset < lex.tokens.len

proc finished*[T](lex: HsLexer[T]): bool =
  not haxNxt(lex, 0) and lex.str[].finished()

proc `[]`*[T](lex: var HSlexer[T], offset: int = 0): T =
  if not haxNxt(lex, offset):
    fillNext(lex, offset)

  lex.tokens[lex.pos + offset]


proc `[]`*[T](lex: var HsLexer[T], slice: Slice[int]): seq[T] =
  for i in slice:
    result.add lex[i]

proc `[]`*[K](tokens: seq[HsTok[K]], offset: int, kind: set[K]|K): bool =
  when kind is set:
    tokens[offset].kind in kind

  else:
    tokens[offset].kind == kind

proc `[]`*[T, K](lex: var HsLexer[T], kind: set[K] | K): bool =
  when kind is set: return lex[].kind in kind
  else:             return lex[].kind == kind


proc `[]`*[T, K](lex: var HsLexer[T], offset: int, kind: set[K] | K): bool =
  when kind is set: return lex[offset].kind in kind
  else:             return lex[offset].kind == kind


proc `[]`*[K](lex: var HsLexer[HsTok[K]], kind: set[K]|K): bool =
  lex[0, kind]

proc `[]`*[K](lex: var HsLexer[HsTok[K]], kind1, kind2: set[K]|K): bool =
  lex[0, kind1] and lex[1, kind2]

proc `[]`*[K](lex: var HsLexer[HsTok[K]], kind1, kind2, kind3: set[K]|K): bool =
  lex[0, kind1] and lex[1, kind2] and lex[2, kind3]



func `[]`*[K](tokens: seq[HsTok[K]], kind: set[K]|K): bool =
  tokens[0, kind]

func `[]`*[K](tokens: seq[HsTok[K]], kind1, kind2: set[K]|K): bool =
  tokens[0, kind1] and tokens[1, kind2]

func `[]`*[K](tokens: seq[HsTok[K]], kind1, kind2, kind3: set[K]|K): bool =
  tokens[0, kind1] and tokens[1, kind2] and tokens[2, kind3]

func returnTo*[T](lex: var HsLexer[T], position: int) =
  lex.pos = position

func getPosition*[T](lex: var HsLexer[T]): int = lex.pos

func advance*[T](lex: var HSlexer[T], step: int = 1) =
  inc(lex.pos, step)

func pop*[T](lex: var HsLexer[T]): T =
  result = lex[]
  lex.advance()


func pop*[K](lex: var HsLexer[HsTok[K]], kind: K): HsTok[K] =
  result = lex[]
  assertKind(lex[], kind)
  lex.advance()

func initLexer*[T](str: var PosStr, lexCb: HsLexCallback[T]): HsLexer[T] =
  HsLexer[T](str: addr str, cb: lexCb)

func skip*[T, En](lexer: var HsLexer[T], kind: En) =
  assertKind(lexer[], kind)
  lexer.advance()

proc skipTo*[T](lex: var HsLexer[T], chars: set[char]) =
  lex.str[].skipWhile(AllChars - chars)

func parseIdent*[R, T](lex: var HsLexer[T], rule: R):
  HsTokTree[R, T] = HsTokTree[R, T](isToken: true, token: lex.pop())

proc insideBalanced*[T, K](
    lex: var HsLexer[T], openKinds, closeKinds: set[K],
    withWrap: bool = false
  ): seq[T] =

  if lex.finished():
    return

  var cnt: int

  if lex[openKinds]:
    inc cnt
    if withWrap:
      result.add lex.pop()

    else:
      lex.advance()

    while cnt > 0:
      if lex[openKinds]:
        inc cnt

      elif lex[closeKinds]:
        dec cnt

      if cnt > 0 or withWrap:
        result.add lex.pop()

      else:
        lex.advance()

func splitSep*[T, K](tokens: seq[T], sep: set[K]): seq[seq[T]] =
  result.add @[]
  for tok in tokens:
    if tok.kind in sep:
      result.add @[]

    else:
      result[^1].add tok

func splitKeyValue*[T, K](
    tokens: seq[T], kvDelimiter: set[K], itemSep: set[K]):
  seq[tuple[key, value: seq[T]]] =

  var init = (newSeq[T](), newSeq[T]())
  result.add init

  var inKey: bool = true
  for tok in tokens:
    if tok.kind in itemSep:
      inKey = true
      result.add init

    if tok.kind in kvDelimiter:
      inKey = false

    else:
      if inKey:
        result[^1].key.add tok

      else:
        result[^1].value.add tok

func getInsideBalanced*[T, K](
  tokens: seq[T], openKinds, closeKinds: set[K], withWrap: bool = false):
  seq[T] =

  var pos = 0
  var cnt: int
  if tokens[pos].kind in openKinds:
    inc cnt
    if withWrap:
      result.add tokens[pos]
      inc pos

    else:
      inc pos

    while cnt > 0 and pos < tokens.len:
      if tokens[pos].kind in openKinds:
        inc cnt

      elif tokens[pos].kind in closeKinds:
        dec cnt

      if cnt > 0 or withWrap:
        result.add tokens[pos]
        inc pos

      else:
        inc pos

func foldNested*[T, K](
    tokens: seq[T],
    openKinds, closeKinds, delimiterKinds: set[K]
  ): seq[HsTokTree[T, T]] =

  proc aux(idx: var int): HsTokTree[T, T] =
    if (idx + 1 < tokens.len) and
       (tokens[idx + 1].kind in openKinds):

      result = HsTokTree[T, T](isToken: false, rule: tokens[idx])

    else:
      result = HsTokTree[T, T](isToken: true, token: tokens[idx])

    inc idx
    if tokens[idx].kind in openKinds:
      inc idx
      while idx < tokens.len:
        if tokens[idx].kind in openKinds:
          result.subnodes.add aux(idx)

        elif tokens[idx].kind in delimiterKinds:
          inc idx

        elif tokens[idx].kind in closeKinds:
          inc idx
          break

        else:
          result.subnodes.add aux(idx)

  var idx: int
  while idx < tokens.len:
    result.add aux(idx)
    if idx < tokens.len and
       tokens[idx].kind in delimiterKinds:
      inc idx


func expectKind*[T, K](lex: var HsLexer[T], kind: set[K]) =
  lex[].assertKind(kind)

func pushRange*[T](lex: var HsLexer[T]) =
  lex.str[].pushRange()

func popRange*[T](lex: var HsLexer[T]): string =
  lex.str[].popRange()

func parsePlus*[T, V](parser: HsParseCallback[T, V]):
  HsParseCallback[T, seq[V]] =

  return proc(toks: var HsLexer[T]): ParseResult[seq[V]] =
    var item = parser(toks)
    if item.isFail():
      return initParseResult[seq[T]](item.fail)

    else:
      result = initParseResult(@[item])
      var position = toks.getPosition()
      while item.isOk():
        item = parser(toks)
        if not item.isOk():
          toks.returnTo(position)

        else:
          result.value.add item


func parseDelimitedStar*[T, V](
  itemParse, delimiterParse: HsParseCallback[T, V]):
  HsParseCallback[T, seq[V]] =

  return proc(toks: var HsLexer[T]): ParseResult[seq[V]] =
    var position = toks.getPosition()

    var item: ParseResult[V] = itemParse(toks)
    if item.isFail():
      return initParseResult[seq[V]](item.fail)

    else:
      result = initParseResult[seq[V]](@[item.get()])
      var position = toks.getPosition()
      # var delimiter = delimiterParse(toks)
      if delimiterParse(toks).isFail():
        toks.returnTo(position)

      else:
        while item.isOk():
          item = itemParse(toks)
          if not item.isOk():
            toks.returnTo(position)

          else:
            result.add item

            position = toks.getPosition()
            if delimiterParse(toks).isFail():
              toks.returnTo(position)
              break

func `^*`*[T, V](itemParse, delimiterParse: HsParseCallback[T, V]):
  HsParseCallback[T, seq[V]] =

  ## Shortcut version for [[code:parseDelimitedStar()]]

  parseDelimitedStar(itemParse, delimiterParse)

func parseToken*[T](token: T): HsParseCallback[T, T] =
  return proc(toks: var HsLexer[T]): ParseResult[T] =
    if toks[] == token:
      toks.advance()
      initParseResult(toks[])

    else:
      initParseResult[T](ParseError())


func parseTokenKind*[K](kind: K): HsParseCallback[HsTok[K], HsTok[K]] =
  return proc(toks: var HsLexer[HsTok[K]]): ParseResult[HsTok[K]] =
    if toks[].kind == kind:
      result = initParseResult(toks[])
      toks.advance()

    else:
      result = initParseResult[HsTok[K]](ParseError())

func parseLongestMatch*[T, V](parsers: seq[HsParseCallback[T, V]]):
  HsParseCallback[T, V] =

  return proc(toks: var HsLexer[T]): ParseResult[T] =
    var position = toks.getPosition()
    var matches: seq[tuple[match: ParseResult[T], endPosition: int]]
    for parser in parsers:
      toks.returnTo(position)
      let match = parser(toks)
      matches.add (match, toks.getPosition())


    sortIt(matches, it.endPosition)
    for (match, position) in matches:
      if match.ok:
        toks.returnTo(position)
        return match

    # IMPLEMENT better error reporting? This is a main source of unreadable
    # error messages from parser combinators (choice operator)
    return matches[0].match

func parseFirstMatch*[T, V](parsers: seq[HsParseCallback[T, V]]):
  HsParseCallback[T, V] =

  return proc(toks: var HsLexer[T]): ParseResult[T] =
    var position = toks.getPosition()
    var lastFail: ParseResult[T]
    for parser in parsers:
      toks.returnTo(position)
      let match = parser(toks)
      if match.ok:
        return match

      else:
        lastFail = match

    return lastFail
