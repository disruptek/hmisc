# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import std/[unittest, terminal, strformat, strutils, colors]
import hmisc/hasts/[html_ast, graphviz_ast]
import hmisc/types/colorstring
import hmisc/hdebug_misc
import hmisc/algo/halgorithm

startHax()

func cs(str: string, fg: ForegroundColor): ColoredString =
  initColoredString(str, fg = fg)

func cs(str: ColoredString, bg: BackgroundColor): ColoredString =
  str.withIt:
    it.styling.bg = bg

func cs(str: ColoredString, ss: Style): ColoredString =
  str.withIt: it.styling.style.incl ss

let styling = """
div.termline { display:flex; }
span.term { display:inline-block; }
span.term-fgred { color: red; }
span.term-fggreen { color: green; }
span.term-bgblue { background-color: blue; }
"""


suite "HTML ast":
  test "Convert from colored string chunks":
    let strs = @[
      "Hello world".cs(fgRed),
      "Hello world 2".cs(fgGreen),
      "Hello world 2".cs(fgYellow).cs(styleBright),
      "Hello world 2".cs(fgGreen).cs(styleItalic),
    ]

    let doc = @[
      strs.toHTML(),
      newHtmlText("--- === ---").wrap("p"),
      strs.toHtml(false)
    ].toDocument(styling)

    # echo doc
    # "/tmp/page.html".writeFile(doc)

  test "Convert colored chuinks":
      let text = &"""
   hello
wer asdf {"werwer".toRed()} 2
      as
asd
  fa
sdfas
"""
      # echo text
      let colored = text.splitSGR_sep()
      let doc = colored.toHTML(false).toDocument(styling)

      # echo doc
      "/tmp/page.html".writeFile(doc)


suite "Graphviz generation":
  var topGraph = makeDotGraph()

  test "Colored note text":
    var graph = makeDotGraph()
    graph.idshift = 1

    for color in ForegroundColor:
      var str = splitCamel($color)
        .toUpperAscii()
        .join("-")
        .center(20)
        .wrap("<<<<", ">>>>")
        .initColoredString()

      str.fg = color
      str.style.incl styleItalic

      graph.add makeColoredDotNode(
        color.int, $str,
        tableAttrs = {"bgcolor" : $colLightSlateGray}
      )

      if color != low(ForegroundColor):
        graph.add makeDotEdge(color.int, pred(color).int)

    try:
      graph.toPng("/tmp/res.png")

    except:
      discard

    topGraph.addSubgraph(graph)

  test "Record nodes":
    var record = makeDotGraph()
    record.idshift = 2
    record.add makeRecordDotNode(0, @[
      makeDotRecord(1, "test-0:1"),
      makeDotRecord(2, "test-0:2", @[
        makeDotRecord(3, "test-0:3"),
        makeDotRecord(4, "test-0:4")
      ]),
    ])
    record.add makeRecordDotNode(1, @[
      makeDotRecord(1, "test-1:1"),
      makeDotRecord(2, "test-1:2", @[
        makeDotRecord(3, "test-1:3"),
        makeDotRecord(4, "test-1:4"),
        makeDotRecord(5, "test-1:5", @[
          makeDotRecord(6, "test-1:6"),
          makeDotRecord(7, "test-1:7")
        ])
      ]),
    ])

    record.add makeDotEdge(toDotPath(0, 1), toDotPath(1, 1))
    record.add makeDotEdge(
      toDotPath(0, 3, dppRight),
      toDotPath(1, 4, dppRight)
    )

    record.add makeDotEdge(
      toDotPath(0, 3, dppRight),
      toDotPath(1, 7, dppRight)
    )


    topGraph.addSubgraph(record)

  try:
    topGraph.toPng("/tmp/res.png", tmpfile = "/tmp/dot-1.dot")

  except:
    discard

suite "graphiz terminal node styling":
  test "All color combinations":
    var topGraph = makeDotGraph()
    topGraph["bgcolor"] = "\"#27212E\""

    type
      F = ForegroundColor
      B = BackgroundColor

    proc toId(fg: F, bg: B): DotNodeId =
      toDotNodeId(int(fg) * 100 + int(bg))

    proc hasSucc(c: F | B): bool =
      c < high(typeof(c))

    for fg in F:
      for bg in B:
        topGraph.add makeDotNode(
          int(fg) * 100 + int(bg), $fg & "-" & $bg, fg, bg)

    for fg in F:
      for bg in B:
        if hasSucc(fg):
          topGraph.add makeDotEdge(toId(fg, bg), toId(succ(fg), bg))

        if hasSucc(bg):
          topGraph.add makeDotEdge(toId(fg, bg), toId(fg, succ(bg)))



    try:
      topGraph.toPng("/tmp/res-1.png", tmpfile = "/tmp/dot-2.dot")

    except:
      discard

suite "SQL schema visualization":
import
    hmisc/hasts/graphviz_ast,
    hmisc/other/[oswrap, hshell, hjson],
    hmisc/[helpers, hdebug_misc],
    std/[strformat, parsesql, hashes],
    fusion/matching


let code = RelFile("haxdoc.sql").readFile() & "\n" & """
SELECT * FROM sqlite_master;
"""

let dump = runShell(shellCmd(sqlite3, -json), stdin = code).stdout.parseJson()

var graph = makeDotGraph(dgpRecords)

iterator items*(sql: SqlNode): SqlNode =
  for i in 0 ..< sql.len:
    yield sql[i]

for record in dump:
  if record.matches({
    "type": (getStr: "table"),
    "sql": @expr
  }):
    let parsed = expr.asStr().parseSql()
    parsed[0].assertMatch(CreateTable[
      (strVal: @tableName),
      all @columns
    ])

    let name = &"[[<b> {tableName} </b>]]"

    var record = makeTableDotNode(hash(tableName), name)

    let w = name.len

    for col in columns:
      var id = col[0].strVal.hash()
      record.add makeDotNode(
        id,
        RawHtml(
          alignLeft(
            col[0].strVal & ":",
            w - col[1].strVal.len - 1,
          ) & &"<i>{col[1].strVal}</i>"
        )
      )

      for sub in col:
        if sub.kind == nkReferences:
          graph.add makeDotEdge(
            (hash(tableName), id),
            (hash(sub[0][0].strVal), hash(sub[0][1].strVal))
          )

    graph.add record


graph.toPng(AbsFile("/tmp/schema.png"))
