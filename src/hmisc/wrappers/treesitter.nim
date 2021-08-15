import std/[unicode, sequtils, options, strformat, tables]
export options
export unicode

import
  ../core/all,
  ../algo/clformat,
  ../types/colorstring

{.pragma: apiStruct, importc, incompleteStruct,
  header: "<tree_sitter/api.h>".}

{.pragma: apiProc, importc, cdecl,
  header: "<tree_sitter/api.h>".}

{.pragma: apiEnum, importc,
  header: "<tree_sitter/api.h>".}

{.pragma: parserStruct, importc, incompleteStruct,
  header: "<tree_sitter/parser.h>".}

{.pragma: parserProc, importc, cdecl,
  header: "<tree_sitter/parser.h>".}

type
  TSTree* {.apiStruct.} = object

  PtsTree* = ptr TSTree

  TSLanguage* {.apiStruct.} = object
    version*: uint32
    symbol_count*: uint32
    alias_count*: uint32
    token_count*: uint32
    external_token_count*: uint32
    state_count*: uint32
    large_state_count*: uint32
    production_id_count*: uint32
    field_count*: uint32
    max_alias_sequence_length*: uint16
    parse_table*: ptr uint16
    small_parse_table*: ptr uint16
    small_parse_table_map*: ptr uint32
    # parse_actions*: ptr TSParseActionEntry
    symbol_names*: cstringArray
    field_names*: cstringArray
    field_map_slices*: ptr UncheckedArray[TSFieldMapSlice]
    field_map_entries*: ptr UncheckedArray[TSFieldMapEntry]
    symbol_metadata*: ptr TSSymbolMetadata
    public_symbol_map*: ptr TSSymbol
    alias_map*: ptr uint16
    alias_sequences*: ptr TSSymbol
    # lex_modes*: ptr TSLexMode
    # lex_fn*: proc (a1: ptr TSLexer; a2: TSStateId): bool
    # keyword_lex_fn*: proc (a1: ptr TSLexer; a2: TSStateId): bool
    # keyword_capture_token*: TSSymbol

  PtsLanguage* = ptr TSLanguage

  TSParser* {.apiStruct.} = object
  PtsParser* = ptr TSParser

  TSInput* {.apiStruct.} = object
  PtsInput* = ptr TSInput
  TSFieldId* = distinct uint16
  TSSymbol* = distinct uint16

  PTsTreeCursor* = ptr TsTreeCursor
  TSTreeCursor* {.apiStruct, importc: "TSTreeCursor".} = object
    tree*: pointer
    id*: pointer
    context*: array[2, uint32]

  TSNode* {.apiStruct.} = object
    context*: array[4, uint32]
    id*: pointer
    tree*: PtsTree

  PtsRange* = ptr TSRange
  TSRange* {.apiStruct.} = object
    start_point*: TSPoint
    end_point*: TSPoint
    start_byte*: uint32
    end_byte*: uint32

  TSInputEncoding* {.apiEnum.} = enum
    TSInputEncodingUTF8
    TSInputEncodingUTF16


  TSPoint* {.apiStruct.} = object
    row*: uint32
    column*: uint32

  TSLexer* {.parserStruct.} = object
    lookahead: cint
    result_symbol: TSSymbol
    advance: proc(lex: ptr TSLexer, skip: bool) {.cdecl.}
    mark_end: proc(lex: ptr TSLexer) {.cdecl.}
    get_column: proc(lex: ptr TSLexer): cuint {.cdecl.}
    is_at_included_range_start: proc(lex: ptr TSLexer) {.cdecl.}

  TSLogType {.apiEnum.} = enum
    TSLogTypeParse
    TSLogTypeLex

  TSLogger* {.apiStruct.} = object
    payload*: pointer
    log*: proc(payload: pointer, logType: TSLogType, text: cstring) {.cdecl.}

  TSInputEdit* {.apiStruct.} = object
    start_byte*: uint32
    old_end_byte*: uint32
    new_end_byte*: uint32
    start_point*: TSPoint
    old_end_point*: TSPoint
    new_end_point*: TSPoint

  TSQueryCapture* {.apiStruct.} = object
    node*: TSNode
    index*: uint32


  TSQuery* {.apiStruct.} = object
  TSQueryCursor* {.apiStruct.} = object
  TSQueryMatch* {.apiStruct.} = object
    id*: uint32
    pattern_index*: uint16
    capture_count*: uint16
    captures*: UncheckedArray[TSQueryCapture]
    # const TSQueryCapture *captures;

  TSSymbolType* {.apiEnum.} = enum
    TSSymbolTypeRegular
    TSSymbolTypeAnonymous
    TSSymbolTypeAuxiliary

  TSQueryPredicateStepType* {.apiEnum.} = enum
    TSQueryPredicateStepTypeDone
    TSQueryPredicateStepTypeCapture
    TSQueryPredicateStepTypeString

  TSQueryPredicateStep* {.apiStruct.} = object
    stepType* {.importc: "type".}: TSQueryPredicateStepType
    value_id*: uint32

  TSQueryError* {.apiEnum.} = enum
    TSQueryErrorNone
    TSQueryErrorSyntax
    TSQueryErrorNodeType
    TSQueryErrorField
    TSQueryErrorCapture
    TSQueryErrorStructure

  TSFieldMapEntry* {.parserStruct.} = object
    field_id*: TSFieldId
    child_index*: uint8
    inherited*: bool

  TSFieldMapSlice* {.parserStruct.} = object
    index*: uint16
    length*: uint16

  TSSymbolMetadata* {.parserStruct.} = object
    visible*: bool
    named*: bool
    supertype*: bool


proc currRune*(lex: var TsLexer): Rune =
  Rune(lex.lookahead)

proc `[]`*(lex: var TSLexer): Rune =
  Rune(lex.lookahead)

proc `[]`*(lex: var TSLexer, ch: char): bool =
  lex.lookahead.int16 == ch.int16

# proc `[]`*(lex: TSLexer): Rune = Rune(lex.lookahead)


proc advance*(lex: var TsLexer) =
  lex.advance(addr lex, false)

proc skip*(lex: var TSLexer) =
  lex.advance(addr lex, true)

proc markEnd*(lex: var TsLexer) =
  lex.mark_end(addr lex)

proc setTokenKind*(lex: var TsLexer, kind: enum) =
  lex.result_symbol = cast[TSSymbol](kind)

proc finished*(lex: var TsLexer): bool =
  lex.lookahead == 0

proc column*(lex: var TSLexer): int =
  lex.get_column(addr lex).int

proc `==`*(rune: Rune, ch: char): bool =
  rune.int16 == ch.int16


proc ts_parser_parse(
  self: PtsParser, oldTree: PtsTree, input: PtsInput): PtsTree {.apiProc.}

proc ts_parser_new*(): PtsParser {.apiProc.}
proc ts_parser_delete*(parser: PtsParser) {.apiProc.}
proc ts_parser_set_language*(
  self: PtsParser; language: PtsLanguage): bool {.apiProc.}

proc ts_parser_language*(self: PtsParser): PtsLanguage {.apiProc.}
proc ts_parser_set_included_ranges*(
  self: PtsParser; ranges: PtsRange; length: uint32) {.apiProc.}

proc ts_parser_included_ranges*(
  self: PtsParser; length: ptr uint32): ptr TSRange {.apiProc.}

proc ts_parser_parse*(
  self: PtsParser; old_tree: PtsTree; input: TSInput): TSTree {.apiProc.}

proc ts_parser_parse_string*(
  self: PtsParser; old_tree: PtsTree;
  inString: cstring; length: uint32): PtsTree {.apiProc.}

proc ts_parser_parse_string_encoding*(
  self: PtsParser; old_tree: PtsTree;
  string: cstring; length: uint32; encoding: TSInputEncoding): PtsTree {.apiProc.}
proc ts_parser_reset*(self: PtsParser) {.apiProc.}
proc ts_parser_set_timeout_micros*(self: PtsParser; timeout: uint64) {.apiProc.}
proc ts_parser_timeout_micros*(self: PtsParser): uint64 {.apiProc.}
proc ts_parser_cancellation_flag*(self: PtsParser): ptr uint {.apiProc.}
proc ts_parser_set_logger*(self: PtsParser; logger: TSLogger) {.apiProc.}
proc ts_parser_logger*(self: PtsParser): TSLogger {.apiProc.}
proc ts_parser_print_dot_graphs*(self: PtsParser; file: cint) {.apiProc.}
proc ts_parser_halt_on_error*(self: PtsParser; halt: bool) {.apiProc.}
proc ts_tree_copy*(self: PtsTree): PtsTree {.apiProc.}
proc ts_tree_delete*(self: PtsTree) {.apiProc.}
proc ts_tree_root_node*(self: PtsTree): TSNode {.apiProc.}
proc ts_tree_language*(a1: PtsTree): ptr TSLanguage {.apiProc.}
proc ts_tree_edit*(self: PtsTree; edit: ptr TSInputEdit) {.apiProc.}
proc ts_tree_get_changed_ranges*(old_tree: PtsTree; new_tree: PtsTree;
                                length: ptr uint32): ptr TSRange {.apiProc.}

proc ts_tree_print_dot_graph*(a1: PtsTree; a2: File) {.apiProc.}
proc ts_node_type*(a1: TSNode): cstring {.apiProc.}
proc ts_node_symbol*(a1: TSNode): TSSymbol {.apiProc.}
proc ts_node_start_byte*(a1: TSNode): uint32 {.apiProc.}
proc ts_node_start_point*(a1: TSNode): TSPoint {.apiProc.}
proc ts_node_end_byte*(a1: TSNode): uint32 {.apiProc.}
proc ts_node_end_point*(a1: TSNode): TSPoint {.apiProc.}
proc ts_node_string*(a1: TSNode): cstring {.apiProc.}
proc ts_node_is_null*(a1: TSNode): bool {.apiProc.}
proc ts_node_is_named*(a1: TSNode): bool {.apiProc.}
proc ts_node_is_missing*(a1: TSNode): bool {.apiProc.}
proc ts_node_is_extra*(a1: TSNode): bool {.apiProc.}
proc ts_node_has_changes*(a1: TSNode): bool {.apiProc.}
proc ts_node_has_error*(a1: TSNode): bool {.apiProc.}
proc ts_node_parent*(a1: TSNode): TSNode {.apiProc.}
proc ts_node_child*(a1: TSNode; a2: uint32): TSNode {.apiProc.}
proc ts_node_child_count*(a1: TSNode): uint32 {.apiProc.}
proc ts_node_named_child*(a1: TSNode; a2: uint32): TSNode {.apiProc.}
proc ts_node_named_child_count*(a1: TSNode): uint32 {.apiProc.}
proc ts_node_child_by_field_name*(
  self: TSNode; field_name: cstring;
  field_name_length: uint32): TSNode {.apiProc.}

proc ts_node_child_by_field_id*(
  a1: TSNode; a2: TSFieldId): TSNode {.apiProc.}

proc ts_node_field_name_for_child*(
    node: TSNode, idx: uint32): cstring {.apiProc.}

proc ts_node_next_sibling*(a1: TSNode): TSNode {.apiProc.}
proc ts_node_prev_sibling*(a1: TSNode): TSNode {.apiProc.}
proc ts_node_next_named_sibling*(a1: TSNode): TSNode {.apiProc.}
proc ts_node_prev_named_sibling*(a1: TSNode): TSNode {.apiProc.}

proc ts_node_first_child_for_byte*(
  a1: TSNode; a2: uint32): TSNode {.apiProc.}

proc ts_node_first_named_child_for_byte*(
  a1: TSNode; a2: uint32): TSNode {.apiProc.}

proc ts_node_descendant_for_byte_range*(
  a1: TSNode; a2: uint32; a3: uint32): TSNode {.apiProc.}

proc ts_node_descendant_for_point_range*(
  a1: TSNode; a2: TSPoint; a3: TSPoint): TSNode {.apiProc.}

proc ts_node_named_descendant_for_byte_range*(
  a1: TSNode; a2: uint32; a3: uint32): TSNode {.apiProc.}

proc ts_node_named_descendant_for_point_range*(
  a1: TSNode; a2: TSPoint; a3: TSPoint): TSNode {.apiProc.}


proc ts_node_edit*(
  a1: ptr TSNode; a2: ptr TSInputEdit) {.apiProc.}

proc ts_node_eq*(
  a1: TSNode; a2: TSNode): bool {.apiProc.}

proc ts_tree_cursor_new*(
  a1: TSNode): TSTreeCursor {.apiProc.}

proc ts_tree_cursor_delete*(
  a1: PtsTreeCursor) {.apiProc.}

proc ts_tree_cursor_reset*(
  a1: PtsTreeCursor; a2: TSNode) {.apiProc.}

proc ts_tree_cursor_current_node*(
  a1: PtsTreeCursor): TSNode {.apiProc.}

proc ts_tree_cursor_current_field_name*(
  a1: PtsTreeCursor): cstring {.apiProc.}

proc ts_tree_cursor_current_field_id*(
  a1: PtsTreeCursor): TSFieldId {.apiProc.}

proc ts_tree_cursor_goto_parent*(
  a1: PtsTreeCursor): bool {.apiProc.}

proc ts_tree_cursor_goto_next_sibling*(
  a1: PtsTreeCursor): bool {.apiProc.}


proc ts_tree_cursor_goto_first_child*(
  a1: PtsTreeCursor): bool {.apiProc.}

proc ts_tree_cursor_goto_first_child_for_byte*(
  a1: PtsTreeCursor; a2: uint32): int64 {.apiProc.}

proc ts_tree_cursor_copy*(
  a1: PtsTreeCursor): TSTreeCursor {.apiProc.}

type
  Cursor*[N] = ref object
    d: TsTreeCursor

proc cursor*[N](node: N): Cursor[N] =
  Cursor[N](d: ts_tree_cursor_new(TsNode(node)))

proc node*[N](cursor: Cursor[N]): N =
  N(ts_tree_cursor_current_node(addr cursor.d))

proc next*[N](cursor: Cursor[N]): bool =
  ts_tree_cursor_goto_next_sibling(addr cursor.d)

iterator items*[N](cursor: Cursor[N]): int =
  var idx = 0
  yield idx
  while next(cursor):
    inc idx
    yield idx

proc down*[N](cursor: Cursor[N]): bool =
  ts_tree_cursor_goto_first_child(addr cursor.d)

proc up*[N](cursor: Cursor[N]): bool =
  ts_tree_cursor_goto_parent(addr cursor.d)

proc fieldName*[N](cursor: Cursor[N]): string =
  let name = ts_tree_cursor_current_field_name(addr cursor.d)

  if not isNil(name):
    result = $name

proc isField*[N](cursor: Cursor[N]): bool =
  not isNil(ts_tree_cursor_current_field_name(addr cursor.d))

proc ts_query_new*(

  language: ptr TSLanguage; source: cstring;
  source_len: uint32; error_offset: ptr uint32;
  error_type: ptr TSQueryError): ptr TSQuery {.apiProc.}

proc ts_query_delete*(
  a1: ptr TSQuery) {.apiProc.}

proc ts_query_pattern_count*(
  a1: ptr TSQuery): uint32 {.apiProc.}

proc ts_query_capture_count*(
  a1: ptr TSQuery): uint32 {.apiProc.}

proc ts_query_string_count*(
  a1: ptr TSQuery): uint32 {.apiProc.}

proc ts_query_start_byte_for_pattern*(
  a1: ptr TSQuery; a2: uint32): uint32 {.apiProc.}

proc ts_query_predicates_for_pattern*(
  self: ptr TSQuery; pattern_index: uint32;
  length: ptr uint32): ptr TSQueryPredicateStep {.apiProc.}

proc ts_query_capture_name_for_id*(
  a1: ptr TSQuery; id: uint32; length: ptr uint32): cstring {.apiProc.}

proc ts_query_string_value_for_id*(
  a1: ptr TSQuery; id: uint32; length: ptr uint32): cstring {.apiProc.}

proc ts_query_disable_capture*(
  a1: ptr TSQuery; a2: cstring; a3: uint32) {.apiProc.}

proc ts_query_cursor_new*(): ptr TSQueryCursor {.apiProc.}

proc ts_query_cursor_delete*(
  a1: ptr TSQueryCursor) {.apiProc.}

proc ts_query_cursor_exec*(
  a1: ptr TSQueryCursor; a2: ptr TSQuery; a3: TSNode) {.apiProc.}

proc ts_query_cursor_set_byte_range*(
  a1: ptr TSQueryCursor; a2: uint32; a3: uint32) {.apiProc.}


proc ts_query_cursor_set_point_range*(
  a1: ptr TSQueryCursor; a2: TSPoint; a3: TSPoint) {.apiProc.}

proc ts_query_cursor_next_match*(
  a1: ptr TSQueryCursor; match: ptr TSQueryMatch): bool {.apiProc.}

proc ts_query_cursor_remove_match*(
  a1: ptr TSQueryCursor; id: uint32) {.apiProc.}

proc ts_query_cursor_next_capture*(
  a1: ptr TSQueryCursor; match: ptr TSQueryMatch;
  capture_index: ptr uint32): bool {.apiProc.}

proc ts_language_symbol_count*(
  a1: ptr TSLanguage): uint32 {.apiProc.}

proc ts_language_symbol_name*(
  a1: ptr TSLanguage; a2: TSSymbol): cstring {.apiProc.}

proc ts_language_symbol_for_name*(
  self: ptr TSLanguage; string: cstring;
  length: uint32; is_named: bool): TSSymbol {.apiProc.}

proc ts_language_field_count*(
  a1: ptr TSLanguage): uint32 {.apiProc.}

proc ts_language_field_name_for_id*(
  a1: ptr TSLanguage; a2: TSFieldId): cstring {.apiProc.}

proc ts_language_field_id_for_name*(
  a1: ptr TSLanguage; a2: cstring; a3: uint32): TSFieldId {.apiProc.}

proc ts_language_symbol_type*(
  a1: ptr TSLanguage; a2: TSSymbol): TSSymbolType {.apiProc.}

proc ts_language_version*(
  a1: ptr TSLanguage): uint32 {.apiProc.}

func nodeString*[N: distinct](node: N): string =
  $ts_node_string(TSNode(node))


func isNamed*[N: distinct](node: N): bool =
  ts_node_is_named(TSNode(node))

func isMissing*[N: distinct](node: N): bool =
  ts_node_is_missing(TSNode(node))

func isExtra*[N: distinct](node: N): bool =
  ts_node_is_extra(TSNode(node))

func hasChanges*[N: distinct](node: N): bool =
  ts_node_has_changes(TSNode(node))

func hasError*[N: distinct](node: N): bool =
  ts_node_has_error(TSNode(node))

func parent*[N: distinct](node: N): N =
  N(ts_node_parent(TSNode(node)))

func child*[N: distinct](node: N; a2: int): N =
  N(ts_node_child(TSNode(node), a2.uint32))

func childCount*[N: distinct](node: N): int =
  ## Number of subnodes (including tokens) for a tree
  ts_node_child_count(TSNode(node)).int

func namedChild*[N: distinct](node: N; a2: int): N =
  ## named child at index
  N(ts_node_named_child(TSNode(node), a2.uint32))

func namedChildCount*[N: distinct](node: N): int =
  ## Number of named (non-token) subnodes for a triee
  assertRef node
  ts_node_named_child_count(TSNode(node)).int

func startPoint*[N: distinct](node: N): TSPoint =
  ## Return start point for AST node (line and column)
  assertRef node
  ts_node_start_point(TSNode(node))

func startByte*[N: distinct](node: N): int =
  ## Return start point for AST node (line and column)
  assertRef node
  ts_node_start_byte(TsNode(node)).int

func endByte*[N: distinct](node: N): int =
  ## Return start point for AST node (line and column)
  assertRef node
  ts_node_end_byte(TsNode(node)).int

func slice*[N: distinct](node: N): Slice[int] =
  assertRef node
  {.cast(noSideEffect).}:
    ## Get range of source code **bytes** for the node
    startByte(node) ..< endByte(node)

func endPoint*[N: distinct](node: N): TSPoint =
  ## Return end point for AST node (line and column)
  assertRef node
  ts_node_end_point(TSNode(node))

func startLine*[N: distinct](node: N): int =
  assertRef node
  node.startPoint().row.int

func endLine*[N: distinct](node: N): int =
  node.endPoint().row.int

func startColumn*[N: distinct](node: N): int =
  node.startPoint().column.int

func endColumn*[N: distinct](node: N): int =
  node.endPoint().column.int


proc childName*[N: distinct](node: N, idx: int): string =
  if idx.uint32 <= ts_node_child_count(node.TsNode()):
    let name = ts_node_field_name_for_child(node.TsNode(), idx.uint32)
    if not isNil(name):
      result = $name

proc fieldNames*[N: distinct](node: N): seq[string] =
  for idx in 0 ..< ts_node_child_count(node.TsNode()):
    result.add childName(node, idx.int)


func `[]`*[N: distinct](
    node: N,
    idx: int | BackwardsIndex, unnamed: bool = false
  ): N =

  when idx is BackwardsIndex:
    let idx = node.len(unnamed = unnamed) - idx.int + 1

  assert 0 <= idx and idx < node.len(unnamed = unnamed),
    "Cannot get subnode at index " & $idx & " - len is " &
      $node.len(unnamed = unnamed)


  if unnamed:
    N(ts_node_child(TSNode(node), uint32(idx)))
  else:
    N(ts_node_named_child(TSNode(node), uint32(idx)))

func `[]`*[N: distinct](
  node: N, slice: Slice[int],
  unnamed: bool = false): seq[N] =

  for i in slice:
    result.add node[i, unnamed]

func `[]`*[N: distinct](
  node: N, slice: HSlice[int, BackwardsIndex],
  unnamed: bool = false): seq[N] =

  let maxIdx = node.len() - slice.b.int
  for i in slice.a .. maxIdx:
    result.add node[i, unnamed]

func `{}`*[N: distinct](node: N, idx: int): N =
  ## Retun node positioned at `idx` - count includes unnamed (token)
  ## subnodes.
  assert 0 <= idx and idx < node.len(unnamed = true)
  N(ts_node_child(TSNode(node), uint32(idx)))


func `[]`*[N: distinct](
    node: N, name: string, check: bool = true): N =
  result = N(ts_node_child_by_field_name(
    TsNode(node), name.cstring, name.len.uint32))

  if check and isNil(result):
    raise newArgumentError(
      "No field named '" & name & "' for AST node type",
      typeof(N), ", kind",
      $node.kind() & ". Possible field names:",
      $fieldNames(node)
    )

func has*[N: distinct](node: N, name: string): bool =
  ## Check if node contains field with `name`
  not(ts_node_is_null(TsNode(node[name, false])))

func contains*[N: distinct](node: N, name: string): bool =
  ## Check if node contains field with `name`
  not(ts_node_is_null(TsNode(node[name, check = false])))


iterator items*[N: distinct](node: N,
               unnamed: bool = false): N =
  ## Iterate over subnodes. `unnamed` - also iterate over unnamed
  ## nodes (usually things like punctuation, braces and so on).
  for i in 0 ..< node.len(unnamed):
    yield node[i, unnamed]

iterator pairs*[N: distinct](node: N, unnamed: bool = false): (int, N) =
  ## Iterate over subnodes. `unnamed` - also iterate over unnamed
  ## nodes.
  for i in 0 ..< node.len(unnamed):
    yield (i, node[i, unnamed])

func `[]`*[N: distinct](s: string, node: N): string =
  s[node.slice()]

func childByFieldName*[N: distinct](
  self: N; fieldName: string; fieldNameLength: int
): TSNode =
  ts_node_child_by_field_name(
    TSNode(self), fieldName.cstring, fieldNameLength.uint32)



import ./wraphelp

type
  TsFieldMap = object
    fieldArray*: ptr UncheckedArray[TsFieldMapEntry]
    maxIdx*: int



proc fieldMap*(lang: PtsLanguage, productionId: uint32): TsFieldMap =
  TsFieldMap(
    fieldArray: lang.fieldMapEntries.subArrayPtr(productionId),
    maxIdx: lang.fieldMapSlices[productionId].length.int)

iterator pairs*(map: TsFieldMap): (int, TsFieldMapEntry) =
  var idx = 0
  while idx < map.maxIdx:
    yield (idx, map.fieldArray[idx])


iterator items*(map: TsFieldMap): TsFieldMapEntry =
  for _, it in pairs(map):
    yield it

import std/[macros, options, unicode, strutils]
export options

macro tsInitScanner*(
  langname: untyped, scannerType: typed = void): untyped =
  result = newStmtList()

  var scannerType = scannerType

  if scannerType.repr == "void":
    scannerType = ident("int8")

  let
    initCall = ident("init" & scannerType.repr)
    kindType = ident(langname.strVal().capitalizeAscii() & "ExternalTok")

  result.add quote do:
    when `scannerType` is int8:
      var scanner {.inject.}: int8

    else:
      var scanner {.inject.} = `initCall`()

  let
    scanCreate = ident(
      "tree_sitter_" & langname.strVal() & "_external_scanner_create")
    scanDestroy = ident(
      "tree_sitter_" & langname.strVal() & "_external_scanner_destroy")
    scanScan = ident(
      "tree_sitter_" & langname.strVal() & "_external_scanner_scan")
    scanSerialize = ident(
      "tree_sitter_" & langname.strVal() & "_external_scanner_serialize")
    scanDeserialize = ident(
        "tree_sitter_" & langname.strVal() & "_external_scanner_deserialize")

  result.add quote do:
    proc `scanCreate`(): pointer {.exportc.} =
      addr scanner

  result.add quote do:
    proc `scanDestroy`(inScanner: `scannerType`) {.exportc.} =
      discard

  result.add quote do:
    proc `scanScan`(
        payload: pointer, lexer: ptr TsLexer, valid_symbols: ptr bool
      ): bool {.exportc.} =

      let res = scan(
        cast[ptr `scannerType`](payload)[],
        lexer[],
        cast[ptr UncheckedArray[bool]](valid_symbols)
      )

      when res isnot Option:
        static:
          error "`scan` must return `Option[<external token kind>]`"

      if res.isSome():
        lexer[].setTokenKind(res.get())
        return true

      else:
        return false

  result.add quote do:
    proc `scanSerialize`(payload: pointer, buffer: cstring) {.exportc.} =
      discard

  result.add quote do:
    proc `scanDeserialize`(payload: pointer, buffer: cstring, length: cuint) {.exportc.} =
      discard

  result = quote do:
    block:
      `result`
      scanner

import
  ../types/colorstring,
  ../algo/halgorithm

type
  TsBaseNodeKind* = enum
    tskDefault
    tskKeyword
    tskComment
    tskIdent
    tskPrefixOp
    tskInfixOp
    tskPrimitiveType

  TsKindMap*[TsKind: enum] = array[TsKind, TsBaseNodeKind]
  TsColorMap* = array[TsBaseNodeKind, PrintStyling]

let baseColorMap* = toMapArray {
  tskKeyword: bgDefault + fgCyan,
  tskComment: bgDefault + fgBlue,
  tskIdent, tskPrefixOp: bgDefault + styleItalic,
  tskPrimitiveType: bgDefault + fgBlue
}

import std/[with]

type
  # FIXME FIXME FIXME making this node a regular `object` causes misterious
  # crashes due to `original` field being incorrectly copied - it is always
  # `null`. Tree-sitter checks for that using `.id == 0`, so I assume nim's
  # zero-initialization gets to it somewhere, and thigs start to fall
  # apart.
  HtsNode*[N: distinct, K: enum] = ref object
    base: ptr string
    case isGenerated*: bool
      of true:
        original: Option[N]
        origNamed: bool
        nodeKind: K
        subnodes: seq[HtsNode[N, K]]
        tokenStr: string
        names: Table[string, int]

      of false:
        node: N

func kind*[N, K](node: HtsNode[N, K]): K =
  if node.isGenerated:
    node.nodeKind

  else:
    node.node.kind

func strVal*[N, K](node: HtsNode[N, K]): string =
  if node.isGenerated:
    node.tokenStr

  else:
    node.base[][node.node.slice()]


func toHtsNode*[N, K](
    node: N, base: ptr string,
    generated: bool = false,
    storePtr: bool  = true
  ): HtsNode[N, K] =
  ## Convert single tree-sitter node to HtsNode
  assertRef node
  if generated:
    result = HtsNode[N, K](
      isGenerated: true,
      original: some node,
      nodeKind: node.kind)

    if node.len == 0:
      assertRef base,
       "Attempt to convert Ts token (`node.len == 0`) to wrapped Ts tree " &
         "using `nil` base string."

      result.tokenStr = base[][node.slice()]

    assertRef result.original.get()

    result.origNamed = node.isNamed()

  else:
    result = HtsNode[N, K](
      isGenerated: false, node: node, base: base)

  if storePtr:
    assertRef base,
     "Attempt to save `nil` base string pointer to conveted Ts tree"

    result.base = base


func isNamed*[N, K](node: HtsNode[N, K]): bool =
  if node.isGenerated:
    node.origNamed

  else:
    node.node.isNamed()

template htsWrap(inNode: untyped, expr: untyped): untyped =
  if inNode.isGenerated:
    assertOption inNode.original,
     "Node does not contain reference to the original tree-sitter node"

    inNode.original.get().`expr`

  else:
    inNode.node.`expr`


func startPoint*[N, K](node: HtsNode[N, K]): TsPoint = htsWrap(node, startPoint)
func endPoint*[N, K](node: HtsNode[N, K]): TsPoint = htsWrap(node, endPoint)
func startByte*[N, K](node: HtsNode[N, K]): int = htsWrap(node, startByte)
func endByte*[N, K](node: HtsNode[N, K]): int = htsWrap(node, endByte)
func slice*[N, K](node: HtsNode[N, K]): Slice[int] =
  startByte(node) ..< endByte(node)

func `[]`*[N, K](str: string, node: HtsNode[N, K]): string =
  str[node.slice()]

func childName*[N, K](node: HtsNode[N, K], idx: int): string =
  if node.isGenerated:
    for name, fieldIdx in pairs(node.names):
      if idx == fieldIdx:
        return name

  else:
    result = node.node.childName(idx)

func contains*[N, K](node: HtsNode[N, K], name: string): bool =
  name in node.names

func toGenerated*[N, K](
    node: HtsNode[N, K], doConvert: bool = true): HtsNode[N, K] =

  if node.isGenerated or not doConvert:
    node

  else:
    toHtsNode[N, K](node.node, node.base, generated = true)

# func toHtsNode*[N, K](
#     node: N, base: var string, generated: bool = false): HtsNode[N, K] =
#   toHtsNode[N, K](node, addr base, generated)


func newTree*[N, K](
    kind: K, subnodes: varargs[HtsNode[N, K]]): HtsNode[N, K] =

  HtsNode[N, K](
    isGenerated: true,
    nodeKind: kind,
    subnodes: toSeq(subnodes))

func `$`*[N, K](node: HtsNode[N, K]): string =
  if node.isGenerated:
    if node.tokenStr.len > 0:
      node.tokenStr

    elif notNil(node.base) and node.original.isSome():
      node.base[][node.original.get()]

    else:
      ""

  elif notNil(node.base):
    node.base[][node.node.slice()]

  else:
    node.node.nodeString()


func isNil*[N, K](node: HtsNode[N, K]): bool = false

func zzzz*[N, K](node: HtsNode[N, K]): string =
  proc aux(res: var string, node: HtsNode[N, K], level: int) =
    res.add "  ".repeat(level)
    res.add &"[{node.kind}] "
    if node.original.isSome():
      res.add $node.original.get()

    for sub in node.subnodes:
      res.add "\n"
      aux(res, sub, level + 1)

  aux(result, node, 0)

func asgn[T](target: var T, other: T) =
  copyMem(
    cast[pointer](addr target),
    cast[pointer](unsafeAddr other),
    sizeof(other)
  )

func asgn*(target: var Option[TsNode], other: Option[TsNode]) =
  if other.isSome():
    asgn(target, other)

func add*[N, K](
    node: var HtsNode[N, K],
    other: HtsNode[N, K] | seq[HtsNode[N, K]]) =
  # echov "adding ... ", zzzz(other)
  node.subnodes.add other
  if other.original.isSome():
    # echov other.original.get().isNil()
    node.subnodes[^1].original.asgn other.original
    # echov other.original.get().isNil()
    # echov node.subnodes[^1].original.get().isNil()
    # echov node.subnodes[^1].original.unsafeGet().isNil()
    # node.subnodes[^1].original.get() = other.original.get()

  # var base = node.subnodes[^1]
  # echov base.original.get().isNil()
  # base = other
  # echov other.original.get().isNil()
  # echov base.original.get().isNil()

  # base.original.get() = other.original.get()
  # echov other.original.get().isNil()
  # echov base.original.get().isNil()

  # echov "after add ... ", zzzz(node)
  # echov "----------------"

func getTs*[N, K](node: HtsNode[N, K]): N =
  if node.isGenerated:
    node.original.get()

  else:
    node.node

func getBase*[N, K](node: HtsNode[N, K]): string =
  assertRef node.base
  node.base[]

func len*[N, K](
    node: HtsNode[N, K], unnamed: bool = false): int =

  if node.isGenerated:
    node.subnodes.len

  else:
    node.node.len(unnamed)

func has*[N, K](node: HtsNode[N, K], idx: int): bool =
  0 <= idx and idx < node.len()

func has*[N, K](node: HtsNode[N, K], name: string): bool =
  if node.isGenerated:
    name in node.names

  else:
    node.node.has(name)

func high*[N, K](node: HtsNode[N, K], unnamed: bool = false): int =
  node.len() - 1

func `[]`*[N, K](
    node: HtsNode[N, K],
    idx: IndexTypes,
    unnamed: bool = false,
    generated: bool = false
  ): HtsNode[N, K] =

  if node.isGenerated:
    if unnamed:
      assertRef node.base,
       "Converted tree must contain pointer to the underlying string in " &
         "order to be able to create new wrapped nodes. Construct base tree " &
         "with `storePtr` enabled. See [[code:toHtsTree]]"

      toHtsNode[N, K](node.getTs()[idx, true], node.base)

    else:
      node.subnodes[idx].toGenerated(generated)

  else:
    toHtsNode[N, K](
      node.node[idx, unnamed], node.base, generated = generated)

func `[]`*[N, K](
    node: var HtsNode[N, K], slice: SliceTypes): var seq[HtsNode[N, K]] =
  node.subnodes[slice]

func `[]`*[N, K](
    node: HtsNode[N, K],
    slice: SliceTypes,
    generated: bool = false,
    unnamed: bool = false
  ): seq[HtsNode[N, K]] =

  if node.isGenerated:
    assertOption node.original,
     "Cannot get unnamed subnodes index without origina tree-sitter node"

    if node.len > 0:
      for idx in clamp(slice, node.high):
        result.add node[idx, unnamed].toGenerated(generated)

  else:
    if node.len > 0:
      for idx in clamp(slice, node.high(unnamed)):
        result.add toHtsNode[N, K](
          node.node[idx, unnamed], node.base, generated)

func `[]`*[N, K](
    node: HtsNode[N, K], name: string, generated: bool = false
  ): HtsNode[N, K] =

  if node.isGenerated:
    if name notin node.names:
      var msg = "No subnode named '" & name & "' for node kind '" &
        $node.kind & "'. Available names - "

      for name, _ in pairs(node.names):
        msg.add " '" & name & "'"


      raise newGetterError(msg)

    else:
      result = node[node.names[name]]

  else:
    assert node.node.has(name)
    result = toHtsNode[N, K](
      node.node[name], node.base, generated = generated)


func `[]`*[N, K](
    node: HtsNode[N, K], idx: int, kind: K | set[K]): HtsNode[N, K] =

  assert 0 <= idx and idx < node.len
  result = node[idx]
  assertKind(
    result, kind,
    "Child node at index " & $idx & " for node kind " & $node.kind)

func `{}`*[N, K](node: HtsNode[N, K], idx: IndexTypes): HtsNode[N, K] =
  `[]`(node, idx, unnamed = true)

func `{}`*[N, K](node: HtsNode[N, K], idx: SliceTypes): seq[HtsNode[N, K]] =
  `[]`(node, idx, unnamed = true)

func `[]=`*[N, K](
    node: var HtsNode[N, K], idx: IndexTypes, other: HtsNode[N, K]) =
  node.subnodes[idx] = other


func lineIInfo(node: NimNode): NimNode =
  ## Create tuple literal for `{.line: .}` pragma
  let iinfo = node.lineInfoObj()
  newLit((filename: iinfo.filename, line: iinfo.line))

macro instFramed*(decl: untyped): untyped =
  ## Wrap iterator/procedure implementation in `{line: }` and emit
  ## additional strack trace information. This allows to have correct
  ## stacktrace information in the inlined iterators.
  decl.expectKind {
    nnkProcDef, nnkFuncDef, nnkIteratorDef, nnkMethodDef,
    nnkConverterDef
  }

  let
    body = decl.body()
    name = decl.name()
    i = body.lineInfoObj()
    (file, line, column) = (i.filename, i.line, i.column)

  let
    start = newLit(&"nimfr_(\"{name}\", \"{file}\")")
    nimln = newLit(&"nimln_({line + 1}, \"{file}\")")
    lineinfo = body.lineIInfo()

  result = decl

  # TODO check for stack tace, check for different backends
  result.body = quote do:
    {.line: instantiationInfo(fullpaths = true)}:
      {.emit: "/* Additional stack trace for `instFramed` */"}
      {.emit: `start`.}
      {.emit: `nimln`.}
      `body`
      {.emit: "popFrame();"}
      {.emit: "/* Pop of the additional stack frame */"}


iterator pairs*[N, K](
    node: HtsNode[N, K],
    slice: SliceTypes = 0 .. high(int),
    generated: bool = false,
    unnamed: bool = false
  ): (int, HtsNode[N, K]) =

  if node.isGenerated:
    if node.subnodes.len > 0:
      for idx in clamp(slice, node.high):
        yield (idx, node.subnodes[idx].toGenerated(generated))

  else:
    if node.len(unnamed) > 0:
      for idx in clamp(slice, node.high):
        yield (idx, toHtsNode[N, K](
          node.node[idx, unnamed], base = node.base, generated = generated))

iterator items*[N, K](
    node: HtsNode[N, K],
    slice: SliceTypes = 0 .. high(int),
    generated: bool = false,
    unnamed: bool = false
  ): HtsNode[N, K] =

  for _, node in pairs(node, slice, generated, unnamed):
    yield node



func toHtsTree*[N, K](
    node: N, base: ptr string,
    unnamed: bool = false,
    storePtr: bool = true
  ): HtsNode[N, K] =

  proc aux(cursor: Cursor[N]): HtsNode[N, K] =
    ## Fully convert tree-sitter tree to `HtsNode[N, K]`.
    result = toHtsNode[N, K](
      cursor.node(), base, generated = true, storePtr = storePtr)

    if down(cursor):
      var nodeIdx = 0
      for idx in items(cursor):
        if cursor.node().isNamed() or unnamed:
          let subConv = aux(cursor)
          result.add subConv
          if cursor.isField():
            result.names[cursor.fieldName()] = nodeIdx

          inc nodeIdx

      discard up(cursor)

  let cursor = node.cursor()
  return aux(cursor)


func newHtsTree*[N, K](kind: K, val: string): HtsNode[N, K] =
  HtsNode[N, K](isGenerated: true, nodeKind: kind, tokenStr: val)

proc treeRepr*[N, K](
    node: N,
    base: string = "",
    langLen: int = 0,
    kindMap: TsKindMap[K] = default(array[K, TsBaseNodeKind]),
    unnamed: bool = false,
    opts: HDisplayOpts = defaultHDisplay
  ): ColoredText =

  let
    pathIndexed = opts.pathIndexed()
    indexed = opts.positionIndexed()
    maxdepth = opts.maxDepth
    maxLen = opts.maxLen

  when node is distinct:
    let ts = TsNode(node)
    let tree = ts.tree
    let lang = tree.ts_tree_language()

  mixin kind, isNil
  const
    numStyle = tcDefault.bg + tcGrey54.fg
    isHts = node is HtsNode

  coloredResult()

  proc aux(
      node: N,
      level: int,
      name: string,
      idx: int,
      path: seq[int],
      nodeIdx: int
    ) =

    when isHts:
      if node.isGenerated and
         node.original.isSome():
        assertRef node.original.get(), $node.kind

    if node.isNil():
      add "  ".repeat(level)
      add "<nil>".toRed()

    else:
      if pathIndexed:
        for item in path:
          add "["
          add $item
          add "]"

        add " "

      else:
        add "  ".repeat(level)

        if indexed:
          if level > 0:
            add "["
            add $idx
            add "] "

          else:
            add "   "

        add ($node.kind())[langLen ..^ 1], tern(
          node.isNamed(),
          fgGreen + bgDefault,
          fgYellow + bgDefault
        )

        add " "

        if name.len > 0:
          add "<"
          add name, fgCyan + bgDefault
          add "("
          add $nodeIdx
          add ")> "


        let hasRange =
          when isHts:
            node.isGenerated and node.original.isSome()

          else:
            true

        if hasRange:
          let
            startPoint = startPoint(node)
            endPoint = endPoint(node)

          add $startPoint.row, numStyle
          add ":"
          add $startPoint.column, numStyle

          if endPoint.row == startPoint.row:
            add ".."
            add $endPoint.column, numStyle
            add " "

          else:
            add "-"
            add $endPoint.row, numStyle
            add ":"
            add $endPoint.column, numStyle


        if node.len(unnamed) == 0:
          let
            text =
              when isHts:
                node.strVal().split("\n")

              else:
                base[node.slice()].split("\n")

            style = baseColorMap[`kindMap`[node.kind]]

          if text.len > 1:
            for idx, line in text:
              add "\n"
              add getIndent(level + 1)
              add line, style

          else:
            add $text[0], style


        else:
          if level + 1 < `maxDepth`:
            var namedIdx = 0
            for idx, subn in pairs(node, unnamed = true):
              if idx < opts.maxlen:
                if subn.isNamed() or unnamed:
                  add "\n"
                  subn.aux(
                    level + 1, node.childName(idx),
                    idx = namedIdx, path & namedIdx, nodeIdx = idx)

                  inc namedIdx

              else:
                add "\n"
                add getIndent(level + 1)
                add " + ("
                add toPluralNoun(
                  toColoredText("hidden node"),
                  node.len(unnamed = true) - opts.maxLen)
                add ")"

                break

          else:
            add " ... ("
            add toPluralNoun(toColoredText("subnode"), node.len())
            add ")"

  aux(node, 0, "", 0, @[], 0)