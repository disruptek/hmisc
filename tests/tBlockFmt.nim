import std/[sugar, strutils, sequtils, strformat, options]
import hmisc/helpers
import hmisc/hdebug_misc

#===========================  implementation  ============================#

#================================  tests  ================================#

import unittest
import hmisc/other/blockfmt

suite "Block formatting":
  let
    txb = makeTextBlock
    vsb = makeStackBlock
    hsb = makeLineBlock
    ind = makeIndentBlock
    verb = makeVerbBlock
    wrap = makeWrapBlock
    choice = makeChoiceBlock
    nl = makeForceLinebreak


  proc lyt(bl: Block, m1: int = 40): string =
    var bl = bl
    let ops = defaultFormatOpts.withIt do:
      it.rightMargin = m1

    let sln = none(Solution).withResIt do:
      bl.doOptLayout(it, ops).get()

    # echo "\e[41m*==========\e[49m  -  \e[41m===========*\e[49m"
    for l in sln.layouts:
      # echo "----"
      var c = Console()
      l.printOn(c)
      # echo c.text


    var c = Console()
    sln.layouts[0].printOn(c)
    return c.text

  let str = lyt

  test "Vertical layouts":
    assertEq @["a".txb, "b".txb].vsb().lyt(), "a\nb"
    assertEq @["-".txb, "-".txb, "-".txb].vsb().lyt(), "-\n-\n-"

    assertEq @[
      "*".txb, @["a".txb, "b".txb].choice()
    ].vsb().lyt(), "*\na"

  test "Choice":
    assertEq @["0000".txb, "00".txb].choice().lyt(3), "00"

    let bl = @[
      @["hello".txb, " ".txb, "world".txb].vsb,
      @["hello".txb, " ".txb, "world".txb].hsb
    ]

    assertEq choice(bl).lyt(), "hello world"

  test "Wrap blocks":
    assertEq makeTextBlocks(@["1", "2", "3"]).wrapBlocks(margin = 2), "12\n3"

  test "Python implementation conmparison":
    assertEq(str(txb("hello")), "hello")
    assertEq(str(vsb([txb("he"), txb("llo")])), "he\nllo")

    echo str(hsb([txb("proc"), txb("hello*"), nl(), txb("world")]))

    echo str(hsb([
      txb("proc"),
      txb("nice*"),
      txb("("),
      ind(wrap([
        hsb([txb("arg:"), txb("Type"), txb(", ")]),
        hsb([txb("arg:"), txb("Type")]),
      ]), 4),
      txb(")")
    ]))

  test "Function argument wrap":
    echo str hsb([
      txb("    "),
      hsb([
        txb("similarityTreshold"),
        txb(": "),
        txb("ScoreCmpProc"),
        txb(",")
      ])
    ])

    echo str(hsb([
      txb("proc "),
      txb("hello*"),
      txb("("),
      choice([
        hsb([
          hsb([
            hsb([
              txb("similarityTreshold"),
              txb(": "),
              txb("ScoreCmpProc"),
              txb(",")
            ])
          ]),
          hsb([
            hsb([
              txb("secondArgument"),
              txb(": "),
              txb("StdCxx11BasicStringSizeType"),
              txb(",")
            ])
          ]),
          txb(")")
        ])
      ])
    ]))
