import sequtils, macros, tables, options, strformat, sugar, strutils,
       parseutils

# import hpprint

# import ../types/colorstring
import ../helpers
import iflet
import ../hexceptions

template `->`(a, b: bool): bool = (if a: b else: true)

func parseEnumField*(fld: NimNode): string =
  case fld.kind:
    of nnkEnumFieldDef:
      fld[0].strVal
    of nnkSym:
      fld.strVal
    else:
      raiseAssert(&"#[ IMPLEMENT {fld.kind} ]#")

func parseEnumImpl*(en: NimNode): seq[string] =
  case en.kind:
    of nnkSym:
      let impl = en.getTypeImpl()
      case impl.kind:
        of nnkBracketExpr:
          return parseEnumImpl(impl.getTypeInst()[1].getImpl())
        of nnkEnumTy:
          result = parseEnumImpl(impl)
        else:
          raiseAssert(&"#[ IMPLEMENT {impl.kind} ]#")
    of nnkTypeDef:
      result = parseEnumImpl(en[2])
    of nnkEnumTy:
      for fld in en[1..^1]:
        result.add parseEnumField(fld)
    of nnkTypeSection:
      result = parseEnumImpl(en[0])
    else:
      raiseAssert(&"#[ IMPLEMENT {en.kind} ]#")


func pref*(name: string): string =
  discard name.parseUntil(result, {'A' .. 'Z', '0' .. '9'})

func newInfix(s: string, a, b: NimNode): NimNode =
  nnkInfix.newTree(ident s, a, b)

func newPrefix(s: string, a: NimNode): NimNode =
  nnkPrefix.newTree(ident s, a)

func foldInfix(s: seq[NimNode],
               inf: string, start: seq[NimNode] = @[]): NimNode =
  ( start & s ).mapIt(it.newPar().newPar()).foldl(newInfix(inf, a, b))


macro hasKindImpl*(head: typed, kind: untyped): untyped =
  let
    impl = head.getTypeImpl().parseEnumImpl()
    pref = impl.commonPrefix().pref()
    names = impl.dropPrefix(pref)

  kind.assertNodeKind({nnkIdent, nnkCurly})
  if kind.kind == nnkCurly:
    var idents: seq[NimNode]
    var setadds: seq[NimNode]

    for it in kind:
      if it.kind == nnkIdent:
        idents.add ident(it.toStrLit().strVal().addPrefix(pref))
      elif it.kind == nnkPrefix:
        assertNodeKind(it[1], {nnkIdent})
        setadds.add it[1]

    setadds.add nnkCurly.newTree(idents)

    result = newInfix("in", head, newPar(setadds.foldInfix("+")))

  else:
    let kind = ident(kind.toStrLit().strVal().addPrefix(pref))
    result = nnkInfix.newTree(ident "==", head, kind)


template hasKind*(head, kindExpr: untyped): untyped =
  hasKindImpl(head.kind, kindExpr)

type
  EStructKind = enum
    kItem
    kList
    kTuple
    kPairs
    kObject
    kSet
    kAlt

  ListKeyword = enum
    lkAny = "any" ## Any element from list
    lkAll = "all" ## All elements from list
    lkNone = "none"
    lkOpt = "opt"
    lkUntil = "until" ## All elements until
    lkPref = "pref" ## All elements while
    lkPos ## Exact position
    lkSlice ## Subrange slice
    lkTrail

  ListStructure = object
    decl: NimNode
    bindVar: Option[NimNode]
    case kind: ListKeyword
      of lkSlice:
        slice: NimNode
      else:
        patt: Match

  ItemMatchKind = enum
    imkInfixEq
    imkSubpatt
    imkPredicate

  KVPair = tuple[key: NimNode, patt: Match]
  Match = ref object
    bindVar: Option[NimNode]
    declNode {.requiresinit.}: NimNode
    isOptional: bool
    case kind: EStructKind
      of kItem:
        case itemMatch: ItemMatchKind
          of imkInfixEq:
            infix: string
            rhsNode: NimNode
            isPlaceholder: bool
          of imkSubpatt:
            rhsPatt: Match
          of imkPredicate:
            isCall: bool
            predBody: NimNode

      of kAlt:
        altElems: seq[Match]
      of kList:
        listElems: seq[ListStructure]
      of kTuple:
        tupleElems: seq[Match]
      of kPairs:
        pairElems: seq[KVPair]

      of kSet:
        setElems: seq[Match]
      of kObject:
        kindCall: Option[NimNode]
        fldElems: seq[tuple[
          name: string,
          patt: Match
        ]]

        kvMatches: Option[Match]
        listMatches: Option[Match]

  AccsElem = object
    isVariadic: bool
    case inStruct: EStructKind
      of kList:
        pos: NimNode
      of kTuple:
        idx: int
      of kObject:
        fld: string
      of kPairs:
        parentKey: bool
        key: NimNode
        nocheck: bool
      of kSet, kAlt:
        discard
      of kItem:
        isOpt: bool

  Path = seq[AccsElem]

  VarKind = enum
    vkRegular
    vkSequence
    vkOption
    vkSet
    vkAlt

  VarSpec = object
    decl {.requiresinit.}: NimNode
    varKind: VarKind
    typePath: Path

  VarTable = Table[string, VarSpec]

func isNamedTuple(node: NimNode): bool =
  # if node.allOfIt(it.kind == nnkIdent and it.strVal == "_"):
  #   # Special case for match-all tuples - `(_, _, _)`
  #   false
  # else:
  node.allOfIt(it.kind in {
    nnkExprColonExpr, # `(fld: )`
    nnkBracket, # `([])`
    nnkTableConstr # `{key: val}`
  }) and
  node.allOfIt((it.kind == nnkIdent) -> (it.strVal == "_"))

func isInfixPatt(node: NimNode): bool =
  node.kind == nnkInfix and node[0].strVal() in ["|"]

func makeVarSet(v: NimNode, expr: NimNode): NimNode =
  v.assertNodeKind({nnkIdent})
  newCall(ident "varset", v, expr)

func toAccs(path: Path, name: string): NimNode =
  func aux(prefix: NimNode, top: Path): NimNode =
    let head = top[0]
    result = case head.inStruct:
      of kList:
        nnkBracketExpr.newTree(prefix, top[0].pos)
      of kTuple:
        nnkBracketExpr.newTree(prefix, newLit(top[0].idx))
      of kObject:
        nnkDotExpr.newTree(prefix, ident head.fld)
      of kPairs:
        nnkBracketExpr.newTree(prefix, head.key)
      of kItem, kAlt:
        prefix
      of kSet:
        raiseAssert("#[ IMPLEMENT ]#")

    if top.len > 1:
      result = result.aux(top[1 ..^ 1])


  result =
    if path.len > 0:
      (ident name).aux(path)
    else:
      ident name


func parseMatchExpr(n: NimNode): Match

func parseKVTuple(n: NimNode): Match =
  if n[0].eqIdent("Some"):
    n.assertNodeIt(n.len <= 2, "Expected `Some(@varBind)`")
    n[1].assertNodeKind({nnkPrefix})
    n[1][0].assertNodeKind({nnkIdent})

    return Match(kind: kObject, declNode: n, fldElems: @{
      "isSome": Match(kind: kItem, itemMatch: imkInfixEq, declNode: n[0],
                      rhsNode: newLit(true), infix: "=="),
      "get": Match(kind: kItem, itemMatch: imkInfixEq,
                   declNode: n[1], isPlaceholder: true,
                   bindVar: some(n[1][1])),
    })


  result = Match(kind: kObject, declNode: n)
  var start = 0
  if n.kind in {nnkCall, nnkObjConstr}:
    start = 1
    result.kindCall = some(n[0])

  for elem in n[start .. ^1]:
    case elem.kind:
      of nnkExprColonExpr:
        elem[0].assertNodeKind({nnkIdent})
        result.fldElems.add((
          elem[0].strVal(),
          elem[1].parseMatchExpr()))
      of nnkBracket:
        result.listMatches = some(elem.parseMatchExpr())
      of nnkTableConstr:
        result.kvMatches = some(elem.parseMatchExpr())
      else:
        elem.assertNodeKind({
          nnkExprColonExpr
        })

func contains(kwds: openarray[ListKeyword], str: string): bool =
  for kwd in kwds:
    if eqIdent($kwd, str):
      return true

func parseListMatch(n: NimNode): seq[ListStructure] =
  func ok(n: NimNode): bool =
    (n.kind == nnkInfix) and
    (n[1].kind == nnkInfix) and
    n[1][0].strVal().startsWith("..")

  if n.anyOfIt(it.ok):
    iflet (err = n.findItFirstOpt(not it.ok)):
      raiseCodeError(err, "Not all elements in array are slice patterns")

    for elem in n:
      elem[2].assertNodeKind({nnkPrefix})
      elem[2][1].assertNodeKind({nnkIdent})
      result.add ListStructure(
        slice: elem[1], bindVar: some(elem[2][1]), kind: lkSlice)

  else:
    for elem in n:
      if elem.kind == nnkPrefix and elem[0].eqIdent(".."):
        result.add ListStructure(kind: lkTrail, patt: Match(
          declNode: elem
        ))
      else:
        let (elem, opKind) =
          if elem.kind in {nnkCall, nnkCommand} and elem[0].strVal() in [
            lkAny, lkAll, lkNone, lkOpt, lkUntil, lkPref]:
            var kwd: ListKeyword
            for (key, val) in {
              "any" : lkAny,
              "all" : lkAll,
              "opt" : lkOpt,
              "until" : lkUntil,
              "none" : lkNone,
              "pref" : lkPref
                }:
              if elem[0].eqIdent(key):
                kwd = val
                break


            (elem[1], kwd)
          else:
            (elem, lkPos)

        var
          match = parseMatchExpr(elem)
          bindv = match.bindVar

        match.bindVar = none(NimNode)
        match.isOptional = opKind in {lkOpt}

        result.add ListStructure(bindVar: bindv, kind: opKind).withIt do:
            it.patt = match
            # it.patt.isOptional = opKind in {lkOpt}

func parseTableMatch(n: NimNode): seq[KVPair] =
  for elem in n:
    result.add((elem[0], elem[1].parseMatchExpr()))

func parseAltMatch(n: NimNode): Match =
  let
    lhs = n[1].parseMatchExpr()
    rhs = n[2].parseMatchExpr()

  var alts: seq[Match]
  if lhs.kind == kAlt: alts.add lhs.altElems else: alts.add lhs
  if rhs.kind == kAlt: alts.add rhs.altElems else: alts.add rhs
  result = Match(kind: kAlt, altElems: alts, declNode: n)

func nodeStr(n: NimNode): string =
  case n.kind:
    of nnkIdent: n.strVal()
    of nnkOpenSymChoice: n[0].strVal()
    else: raiseAssert(&"#[ IMPLEMENT for kind {n.kind} ]#")

func parseMatchExpr(n: NimNode): Match =
  case n.kind:
    of nnkIdent, nnkSym, nnkIntLit, nnkStrLit, nnkCharLit:
      result = Match(kind: kItem, itemMatch: imkInfixEq, declNode: n)
      if n == ident "_":
        result.isPlaceholder = true
      else:
        result.rhsNode = n
        result.infix = "=="
    of nnkPar:
      if n.isNamedTuple():
        result = parseKVTuple(n)
      elif n[0].isInfixPatt():
        result = parseAltMatch(n[0])
      else:
        result = Match(kind: kTuple, declNode: n)
        for elem in n:
          result.tupleElems.add parseMatchExpr(elem)
    of nnkPrefix:
      echov n
      echov n.lispRepr()
      if n[0].nodeStr() == "is":
        result = Match(
          kind: kItem, itemMatch: imkSubpatt,
          rhsPatt: parseMatchExpr(n[1]), declNode: n)

      elif n[0].nodeStr() == "@":
        n[1].assertNodeKind({nnkIdent})
        result = Match(
          kind: kItem, itemMatch: imkInfixEq, isPlaceholder: true,
          bindVar: some(n[1]), declNode: n)

      else:
        result = Match(
          kind: kItem, itemMatch: imkInfixEq, infix: n[0].strVal(),
          rhsNode: n[1], declNode: n
        )

    of nnkBracket:
      result = Match(
        kind: kList, listElems: parseListMatch(n), declNode: n)
    of nnkTableConstr:
      result = Match(
        kind: kPairs, pairElems: parseTableMatch(n), declNode: n)
    of nnkCurly:
      result = Match(kind: kSet, declNode: n)
      for node in n:
        node.assertNodeKindNot({nnkExprColonExpr})
        result.setElems.add parseMatchExpr(node)
    of nnkObjConstr, nnkCall:
      if n[0].kind == nnkPrefix:
        assertNodeKind(n[0][1], {nnkIdent})
        result = Match(
          kind: kItem,
          itemMatch: imkPredicate,
          bindVar: some(n[0][1]),
          declNode: n,
          predBody: n[1]
        )
      else:
        result = parseKVTuple(n)
    elif n.isInfixPatt():
      result = parseAltMatch(n)
    elif n.kind == nnkInfix:
      n[1].assertNodeKind({nnkPrefix})
      n[1][1].assertNodeKind({nnkIdent})
      if n[0].strVal() == "is":
        result = Match(
          kind: kItem, itemMatch: imkSubpatt,
          rhsPatt: parseMatchExpr(n[2]), declNode: n)

      else:
        result = Match(
          kind: kItem, itemMatch: imkInfixEq,
          rhsNode: n[2],
          infix: n[0].strVal(), declNode: n)

        if result.infix == "or":
          result.isOptional = true

      result.bindVar = some(n[1][1])
    else:
      raiseAssert(&"#[ IMPLEMENT for kind {n.kind} ]#")

func isVariadic(p: Path): bool = p.anyOfIt(it.isVariadic)

func isAlt(p: Path): bool = p.anyOfIt(it.inStruct == kAlt)

func isOption(p: Path): bool =
  p.anyOfIt(it.inStruct == kItem and it.isOpt)

func classifyPath(path: Path): VarKind =
  if path.isVariadic:
    vkSequence
  elif path.isAlt:
    vkAlt
  elif path.isOption:
    vkOption
  else:
    vkRegular

func addvar(tbl: var VarTable, vsym: NimNode, path: Path): void =
  let vs = vsym.strVal()
  if vs notin tbl:
    tbl[vs] = VarSpec(
      decl: vsym,
      varKind: path.classifyPath(),
      typePath: path
    )
  else:
    let class = path.classifyPath()
    var update = false
    case class:
      of vkSequence:
        update = true

      of vkOption:
        if tbl[vs].varKind in {vkRegular}:
          update = true

      else:
        discard

    if update:
      tbl[vs].varKind = class
      tbl[vs].typePath = path



func makeMatchExpr(
  m: Match, vt: var VarTable, path: Path, mainExpr: string): NimNode

template makeElemMatch(): untyped {.dirty.} =
  case elem.kind:
    of lkPos:
      inc minLen
      inc maxLen
      iflet (bindv = elem.bindVar):
        result.add makeVarSet(bindv, parent.toAccs(mainExpr))
        vt.addvar(bindv, parent)

      if elem.patt.kind == kItem and
         elem.patt.itemMatch == imkInfixEq and
         elem.patt.isPlaceholder:
        result.add newCall(ident "inc", posid)
      else:
        result.add quote do:
          if `expr`:
            inc `posid`
          else:
            `failBreak`

    else:
      maxLen = 5000
      var varset = newEmptyNode()

      # if elem.kind notin {lkOpt}:
      iflet (bindv = elem.bindVar):
        varset = makeVarSet(bindv, parent.toAccs(mainExpr))
        vt.addvar(bindv, parent)

      case elem.kind:
        of lkAll:
          result.add quote do:
            block:
              var allOk: bool = true
              while `posid` < `getLen` and allOk:
                if not `expr`:
                  allOk = false
                else:
                  `varset`
                  inc `posid`

              if not allOk:
                break `failBlock`

        of lkUntil:
          result.add quote do:
            while (`posid` < `getLen`) and (not `expr`):
              `varset`
              inc `posid`

          if idx == list.listElems.len - 1:
            result.add quote do:
              if (`posid` < `getLen`): ## Not full match
                break `failBlock`

        of lkAny:
          result.add quote do:
            block:
              var foundOk: bool = false
              while `posid` < `getLen`:
                if `expr`:
                  foundOk = true
                  `varset`
                  inc `posid`

              if not foundOk:
                break `failBlock`
        of lkPref:
          result.add quote do:
            while `posid` < `getLen` and `expr`:
              `varset`
              inc `posid`
        of lkOpt:
          var default = nnkDiscardStmt.newTree(newEmptyNode())
          if elem.patt.isOptional:
            iflet (bindv = elem.bindVar):
              if elem.patt.rhsNode != nil:
                default = makeVarSet(bindv, elem.patt.rhsNode)
                vt.addvar(bindv, path & @[
                  AccsElem(inStruct: kList, pos: posid),
                  AccsElem(inStruct: kItem)
                ])
              else:
                vt.addvar(bindv, path & @[
                  AccsElem(inStruct: kList, pos: posid),
                  AccsElem(inStruct: kItem, isOpt: true)
                ])

          result.add quote do:
            if `posid` < `getLen`:
              `varset`
              inc `posid`
            else:
              `default`
        else:
          if true:
            raiseAssert(&"#[ IMPLEMENT for kind {elem.kind} ]#")



func makeListMatch(
  list: Match, vt: var VarTable, path: Path,
  mainExpr: string): NimNode =
  var idx = 1
  while idx < list.listElems.len:
    if list.listElems[idx - 1].kind notin {lkUntil, lkPos, lkOpt, lkPref}:
      raise ({
        list.listElems[idx - 1].decl : "Greedy list match pattern",
        list.listElems[idx].decl : "Must be last in sequence but found"
      }).toCodeError("Greedy list match must be last element in pattern")

    inc idx

  let
    posid = genSym(nskVar, "pos")
    matched = genSym(nskVar, "matched")
    failBlock = ident("failBlock")
    failBreak = nnkBreakStmt.newTree(failBlock)
    getLen = newCall("len", path.toAccs(mainExpr))


  result = newStmtList()
  var minLen = 0
  var maxLen = 0
  for idx, elem in list.listElems:
    if elem.kind == lkSlice:
      let
        parent = path & @[AccsElem(
          inStruct: kPairs, key: elem.slice, nocheck: true)]

      result.add makeVarSet(elem.bindVar.get(), parent.toAccs(mainExpr))
      vt.addvar(elem.bindVar.get(), parent)
      maxLen = 5000
    elif elem.kind == lkTrail:
      maxLen = 5000
    else:
      let
        parent = path & @[AccsElem(
          inStruct: kList, pos: posid,
          isVariadic: elem.kind notin {lkPos, lkOpt})]

        expr = elem.patt.makeMatchExpr(vt, parent, mainExpr)


      result.add newCommentStmtNode(
        $elem.kind & " " & elem.patt.declNode.repr)

      makeElemMatch()

  let
    comment = newCommentStmtNode(list.declNode.repr)
    minNode = newLit(minLen)
    maxNode = newLit(maxLen)
    setCheck =
      if maxLen >= 5000:
        quote do:
          `getLen` < `minNode`
      else:
        quote do:
          `getLen` notin {`minNode` .. `maxNode`}

  result = quote do:
    `comment`
    var `matched` = false
    block `failBlock`:
      var `posid` = 0 ## Start list match

      if `setCheck`:
        ## fail on seq len
        break `failBlock`

      `result`

      `matched` = true ## List match ok

    `matched`

  result = result.newPar().newPar()




func makeMatchExpr(
  m: Match, vt: var VarTable, path: Path, mainExpr: string): NimNode =
  # echov pstring m
  case m.kind:
    of kItem:
      let parent = path.toAccs(mainExpr)
      case m.itemMatch:
        of imkInfixEq, imkSubpatt:
          let inf =
            if m.itemMatch == imkInfixEq:
              if m.isPlaceholder:
                newLit(true)
              else:
                newInfix(m.infix, parent, m.rhsNode)
             else:
               makeMatchExpr(m.rhsPatt, vt, path, mainExpr)

          iflet (vname = m.bindVar):
            vt.addvar(vname, path)
            let bindVar = makeVarSet(vname, parent)
            if inf == newLit(true):
              return quote do:
                (`bindVar`; true)
            else:
              return quote do:
                block:
                  if `inf`:
                    `bindVar`
                    true
                  else:
                    false
          else:
            return inf
        of imkPredicate:
          let pred = m.predBody
          var bindVar = newEmptyNode()
          iflet (vname = m.bindVar):
            vt.addvar(vname, path)
            bindVar = makeVarSet(vname, parent)

          result = quote do:
            let it {.inject.} = `parent`
            if `pred`:
              `bindVar`
              true
            else:
              false


    of kList:
      return makeListMatch(m, vt, path, mainExpr)
    of kTuple:
      let conds = collect(newSeq):
        for idx, it in m.tupleElems:
          it.makeMatchExpr(vt, path & @[
            AccsElem(inStruct: kTuple, idx: idx)
          ],  mainExpr)

      return conds.foldInfix("and")
    of kObject:
      var conds: seq[NimNode]
      for (fld, patt) in m.fldElems:
        conds.add patt.makeMatchExpr(vt, path & @[
          AccsElem(inStruct: kObject, fld: fld)],  mainExpr)

      iflet (list = m.listMatches):
        conds.add list.makeMatchExpr(vt, path,  mainExpr)

      iflet (kv = m.kvMatches):
        conds.add kv.makeMatchExpr(vt, path,  mainExpr)

      iflet (kc = m.kindCall):
        conds.add newCall(ident "hasKind", path.toAccs(mainExpr), kc)

      return conds.foldInfix("and")

    of kPairs:
      var conds: seq[NimNode]
      for (key, val) in m.pairElems:
        conds.add newInfix(
          "and",
          newInfix("in", key, path.toAccs(mainExpr)),
          val.makeMatchExpr(vt, path & @[
            AccsElem(inStruct: kPairs, key: key)],  mainExpr))

      return conds.foldInfix("and")
    of kAlt:
      let conds = collect(newSeq):
        for alt in m.altElems:
          alt.makeMatchExpr(
            vt, path & @[AccsElem(inStruct: kAlt)],  mainExpr)

      return conds.foldInfix("or")
    else:
      raiseAssert("#[ IMPLEMENT ]#")




func makeMatchExpr(m: Match, mainExpr: string): tuple[
    expr: NimNode, vtable: VarTable] =
  result.expr = makeMatchExpr(m, result.vtable, @[],  mainExpr)

func updateTypeof(nn: NimNode): void =
  for idx, node in nn:
    if node.kind == nnkSym and node.strVal[^"pos"]:
      nn[idx] = newLit(0)
    else:
      nn[idx].updateTypeof()

func updateVarSet(nn: NimNode, vtable: VarTable): void =
  ## Recursively walk generate pattern match and replace dummy
  ## variable assignments with correct code
  for idx, node in nn:
    if node.kind == nnkCall and
       node[0] == ident "varset":
      let
        varn = node[1]
        expr = node[2]

      case vtable[varn.strVal()].varKind:
        of vkSequence:
          nn[idx] = quote do:
            `varn`.add `expr` ## Append item to sequence

        of vkOption:
          nn[idx] = quote do:
            `varn` = some(`expr`) ## Set optional value

        of vkSet:
          nn[idx] = quote do:
            `varn`.incl some(`expr`) ## Add element to set

        of vkRegular:
          nn[idx] = nnkAsgn.newTree(varn, expr)

        of vkAlt:
          raiseAssert("#[ IMPLEMENT ]#")

    elif node.kind == nnkIfStmt and
         node[0][0].kind in {nnkSym, nnkIdent} and
         node[0][0].strVal == "true":
        nn[idx] = nn[idx][0][1]
        updateVarSet(nn[idx], vtable)
    else:
      updateVarSet(nn[idx], vtable)

func toNode(
  input: tuple[expr: NimNode, vtable: VarTable], mainExpr: string): NimNode =
  var (expr, vtable) = input

  var exprNew = nnkStmtList.newTree()
  for name, spec in vtable:
    let vname = ident(name)
    # debugecho vname.lispRepr()
    var typeExpr = toAccs(spec.typePath, mainExpr)
    typeExpr = quote do:
      ((let tmp = `typeExpr`; tmp))

    updateTypeof(typeExpr)
    case spec.varKind:
      of vkSequence:
        exprNew.add quote do:
          var `vname`: seq[typeof(`typeExpr`)]

      of vkOption:
        exprNew.add quote do:
          var `vname`: Option[typeof(`typeExpr`)]

      of vkSet, vkRegular:
        exprNew.add quote do:
          var `vname`: typeof(`typeExpr`)

      of vkAlt:
        if true: raiseAssert("#[ IMPLEMENT ]#")

  # debugecho expr.repr
  updateVarSet(expr, vtable)
  return quote do:
    `exprNew`
    `expr`


macro match*(
  n: tuple | object | ref object | seq | array | set): untyped =
  var matchcase = nnkIfStmt.newTree()
  for elem in n[1 .. ^1]:
    case elem.kind:
      of nnkOfBranch:
        if elem[0] == ident "_":
          elem[0].raiseCodeError(
            "To create catch-all match use `else` clause",
            "Replace `_` with `else` here")


        matchcase.add nnkElifBranch.newTree(
          elem[0].parseMatchExpr().makeMatchExpr( "expr").
            toNode("expr").newPar().newPar(),
          elem[1]
        )

      of nnkElifBranch, nnkElse:
        matchcase.add elem
      else:
        discard
        # raiseAssert(&"#[ IMPLEMENT for kind {elem.kind} ]#")

  let head = n[0]

  result = quote do:
    block:
      let expr {.inject.} = `head`
      let pos {.inject.}: int = 0
      `matchcase`

  # echov result



macro assertMatch*(input: typed, pattern: untyped): untyped =
  let
    expr = ident genSym(nskLet, "expr").repr
    matched = pattern.parseMatchExpr().
      makeMatchExpr(expr.repr).toNode(expr.repr)


  let patt = newLit(pattern.repr)
  result = quote do:
    let `expr` = `input`
    let ok = `matched`

    if not ok:
      raiseAssert("Pattern match failed `" & `patt` & "`")

  # echov result


macro matches*(input: typed, pattern: untyped): untyped =
  let
    expr = ident genSym(nskLet, "expr").repr
    matched = pattern.parseMatchExpr().
      makeMatchExpr(expr.repr).toNode(expr.repr)

  return quote do:
    let `expr` = `input`
    `matched`

template `:=`*(lhs, rhs: untyped): untyped =
  assertMatch(rhs, lhs)

template `?=`*(lhs, rhs: untyped): untyped =
  matches(rhs, lhs)
