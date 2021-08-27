import
  std/[macros, sequtils, strutils, parseutils]

import ../macros/argpass

import ../core/[all, code_errors]

macro closureToCdeclImpl(c: typed): untyped =
  discard

func closureToCdecl*[C: proc {.closure.}](c: C): auto =
  closureToCdeclImpl(c)

func splitClosure*[C: proc {.closure.}](c: C): auto =
  return (impl: cast[typeof(closureToCdecl(c))](rawProc(c)), env: rawEnv(c))

type
  cchar16* = uint16
  cchar32* = uint32
  cwchar* = uint32
  nullptr_t* = typeof(nil)



type
  UArray*[T] = UncheckedArray[T]
  PUarray*[T] = ptr UncheckedArray[T]

template `+`*[T](p: ptr T, offset: SomeInteger): ptr T =
  cast[ptr type(p[])](cast[ByteAddress](p) +% int(offset) * sizeof(p[]))

template `+=`*[T](p: ptr T, offset: SomeInteger) =
  p = p + offset

template `-`*[T](p: ptr T, offset: SomeInteger): ptr T =
  cast[ptr type(p[])](cast[ByteAddress](p) -% int(offset) * sizeof(p[]))

template `-=`*[T](p: ptr T, offset: SomeInteger) =
  p = p - offset

template `[]`*[T](p: ptr T, offset: SomeInteger): T =
  (p + offset)[]

template `[]=`*[T](p: ptr T, offset: SomeInteger, val: T) =
  (p + offset)[] = val

proc allocPUarray*[T](size: Natural): PUarray[T] =
  cast[PUarray[T]](alloc(size * sizeof(T)))

proc allocPUarray*[T, R](elements: array[R, T]): PUarray[T] =
  discard # TODO

proc deallocPUarray*[T](arr: PUarray[T]) =
  dealloc(cast[pointer](arr))

template toPUarray*[T](p: ptr T): PUarray[T] = cast[PUarray[T]](p)
template toPtr*[T](p: PUArray[T]): ptr T = cast[ptr T](p)

template toPtr*[T](r: ref T): ptr T = cast[ptr T](r)
template toPUarray*[T](r: ref T): PUarray[T] = cast[PUarray[T]](r)

iterator items*[T](arr: PUarray[T], size: int): T =
  var idx = 0
  while idx < size:
    yield arr[][idx]
    inc idx

iterator pairs*[T](arr: PUarray[T], size: int): (int, T) =
  var idx = 0
  while idx < size:
    yield (idx, arr[][idx])
    inc idx

template subArrayPtr*[T](arr: PUArray[T], idx: SomeInteger): PUarray[T] =
  toPUarray(toPtr(arr) + idx)










type
  WrapCtx = object
    namespace: seq[string]
    inClass: bool
    nimClassName: NimNode
    cxxClassName: string
    header: string

func getIcpp(ctx: WrapCtx, name: string, isType: bool): string =
  if ctx.inClass:
    if isType:
      join(ctx.namespace & name, "::")

    else:
      "#." & name

  else:
    join(ctx.namespace & name, "::")

func procDeclAux(entry: NimNode, ctx: WrapCtx): NimNode =
  let name =
    if entry.body.kind == nnkEmpty:
      entry.name().strVal()

    else:
      assertNodeKind(entry.body()[0], {nnkCall})
      entry.body()[0][0].strVal()

  var
    hasConst = false
    isConstructor = false
    filter: seq[NimNode]

  for pr in entry.pragma:
    if pr.eqIdent("const"):
      hasConst = true

    elif pr.eqIdent("constructor"):
      isConstructor = true
      filter.add pr

    else:
      filter.add pr


  entry.pragma = nnkPragma.newTree(filter)

  result = entry
  result.body = newEmptyNode()

  if ctx.inClass and not isConstructor:
    let thisTy =
      if hasConst:
        ctx.nimClassName

      else:
        nnkVarTy.newTree(ctx.nimClassName)

    result.params.insert(1, nnkIdentDefs.newTree(
      ident("this"), thisTy, newEmptyNode()))

  var icpp: string
  if isConstructor:
    if entry.params[0].kind == nnkPtrTy:
      icpp = "new " & ctx.getIcpp(ctx.cxxClassName, true) & "(@)"

    else:
      icpp = ctx.getIcpp(ctx.cxxClassName, true) & "(@)"

  else:
    if allIt(name, it in IdentChars):
      icpp = ctx.getIcpp(name & "(@)", false)

    else:
      icpp = ctx.getIcpp("operator" & name & "(@)", false)


  result.addPragma newEcE(ident("importcpp"), newLit(icpp))


func stmtAux(entry: NimNode, ctx: WrapCtx): NimNode

func headerAux(name: string, body: seq[NimNode], ctx: WrapCtx): NimNode =
  var ctx = ctx
  ctx.header = name
  result = newStmtList()
  for node in body:
    result.add stmtAux(node, ctx)

func namespaceAux(name: string, body: seq[NimNode], ctx: WrapCtx): NimNode =
  var ctx = ctx
  ctx.namespace.add name
  result = newStmtList()
  for node in body:
    result.add stmtAux(node, ctx)

func splitClassName(name: NimNode):
  tuple[nimName: NimNode, cxxName: string, super: Option[NimNode]] =

  case name.kind:
    of nnkStrLit, nnkIdent:
      result.cxxName = name.strVal()
      result.nimName = ident(name.strVal())

    of nnkInfix:
      case name[0].strVal():
        of "as":
          result.cxxName = name[1].strVal()
          result.nimName = name[2]

        of "of":
          result.super = some name[2]
          let (nim, cxx, _) = splitClassName(name[1])
          result.nimName = nim
          result.cxxName = cxx

        else:
          raise newImplementError()

    else:
      raise newUnexpectedKindError(name)



func classAux(name: NimNode, body: seq[NimNode], ctx: WrapCtx): NimNode =
  var resList: seq[NimNode]
  var fieldList = nnkRecList.newTree()
  var ctx = ctx
  let (nim, cxx, super) = splitClassName(name)
  ctx.inClass = true
  ctx.nimClassName = nim
  ctx.cxxClassName = cxx

  var isByref: bool = false

  for entry in body:
    case entry.kind:
      of nnkProcDef:
        resList.add procDeclAux(entry, ctx)

      of nnkStmtList:
        for stmt in entry:
          resList.add stmtAux(stmt, ctx)

      else:
        raise newImplementKindError(entry)

  result = newStmtList(
    nnkTypeSection.newTree(
      nnkTypeDef.newTree(
        nnkPragmaExpr.newTree(
          nnkPostfix.newTree(ident"*", nim),
          nnkPragma.newTree(
            newEcE("importcpp", newLit(ctx.getIcpp(ctx.cxxClassName, true))),
            (if isByref: ident"byref" else: ident"bycopy"),
            ident("inheritable"),
            newEcE("header", newLit(ctx.header)))),
        newEmptyNode(),
        nnkObjectTy.newTree(
          newEmptyNode(),
          (if super.isSome(): nnkOfInherit.newTree(super.get()) else: newEmptyNode()),
          fieldList))) & resList)



func stmtAux(entry: NimNode, ctx: WrapCtx): NimNode =
  case entry.kind:
    of nnkProcDef:
      result = procDeclAux(entry, ctx)

    of nnkCommand:
      let kind = entry[0].strVal()

      case kind:
        of "namespace":
          result = namespaceAux(entry[1].strVal(), entry[2..^1], ctx)

        of "class":
          result = classAux(entry[1], entry[2..^1], ctx)

        of "static", "struct", "enum", "var", "let", "const":
          raise newImplementError(kind)


        else:
          raise newImplementKindError(kind)

    of nnkStmtList:
      result = newStmtList()
      for stmt in entry:
        result.add stmtAux(stmt, ctx)

    else:
      raise newUnexpectedKindError(entry, treeRepr(entry))

macro wrapheader*(name: static[string], body: untyped): untyped =
  result = headerAux(name, toSeq(body), WrapCtx())
  echo result.repr()
