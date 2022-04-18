import
  std/[macros]

import ../core/[all]

macro closureToCdeclImpl(c: typed, addEnv: static[bool]): untyped =
  var ty = c.getTypeImpl()
  if addEnv:
    ty[0].add nnkIdentDefs.newTree(
      ident"env",
      ident"pointer",
      newEmptyNode()
    )

  if ty[^1].kind == nnkEmpty:
    ty[^1] = nnkPragma.newTree(ident"cdecl")

  elif ty[^1].kind == nnkPragma:
    ty[^1].add ident"cdecl"

  else:
    error(ty.treeRepr(), ty)

  # echo ty.repr()
  return ty

func closureToCdecl*[C: proc {.closure.}](c: C): auto =
  var tmp: closureToCdeclImpl(c, true)
  return tmp

func nimcallToCdecl*[C: proc](c: C): auto =
  var tmp: closureToCdeclImpl(c, false)
  return tmp

func splitClosure*[C: proc {.closure.}](c: C): auto =
  return (impl: cast[typeof(closureToCdecl(c))](rawProc(c)), env: rawEnv(c))

type
  cchar16* = uint16
  cchar32* = uint32
  cwchar* = uint32
  nullptr_t* = typeof(nil)

# QUESTION argument might contain fully namespaced entry identifier, with
# all arguments specified, like `main(const*[char],int): void`? This could
# be used by other tools. Or should I generate full name directly?
# `static[HcIdent]`.

template hcgen*(arg: static[string]) {.pragma.}
  ## Entries annotated with this pragma are automatically generated by
  ## external tooling. This pragma itself does not do anything, but hcparse
  ## should use it to intellegently override generated sources, without
  ## breaking manually added code.

template hcedit*(arg: static[string]) {.pragma.}
  ## Similar to [[code:hcgen]], but used to anotate entries that were
  ## originally generated by hcparse, but then manually modified, and no
  ## longer need to be auto-updated when new source is generated.

type
  UArray*[T] = UncheckedArray[T]
  PUarray*[T] = ptr UncheckedArray[T]

proc `or`*[T: enum](lhs: T, rhs: T): uint = lhs.ord() or rhs.ord()
proc `and`*[T: enum](lhs: T, rhs: T): uint = lhs.ord() and rhs.ord()
proc `not`*[T: enum](lhs: T): uint = not lhs.ord()


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

func inc*[T](p: var ptr T, count: int = 1) =
  p = p + (sizeof(T) * count)

func dec*[T](p: var ptr T, count: int = 1) =
  p = p - (sizeof(T) * count)



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


proc setcast*[I: uint8 | uint16 | uint32 | uint64; E](s: set[E]): I =
  static:
    assert sizeof(s) <= sizeof(I),
     "Set cast integer size mismatch - sizeof(" & $I & ") was " & $sizeof(I) &
       ", while size of the " & $set[E] & " is " & $sizeof(s) &
       ". Correct target type for the set would be " & (
         case sizeof(s):
           of 1: "uint8 or more"
           of 2: "uint16 or more"
           of 3: "uint32 or more"
           of 4: "uint64 or more"
           else: "byte array array[" & $(sizeof(s) div 8) & ", uint8]"
       )

  return cast[I](s)
