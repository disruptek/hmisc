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


  proc lyt(bl: LytBlock, m1: int = 40): string =
    var bl = bl
    let ops = defaultFormatOpts.withIt do:
      it.rightMargin = m1

    let sln = none(LytSolution).withResIt do:
      bl.doOptLayout(it, ops).get()

    sln.layouts[0].printOn(result)

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

initBlockFmtDSL()

suite "Edge case layouts":
  test "Stack of lines in braces":
    let bl = H[
      T["proc ("],
      V[
        T["line 1"],
        T["line 2"],
        T["line 3"],
      ],
      T[" = "],
      V[
        T["line 4"],
        T["line 5"],
        T["line 6"],
      ],
      T[")"]
    ]

    echo toString(deepCopy(bl), fixLyt = false)
    echo toString(bl)


  test "Choice stack vs line":

    if true:
      echo toString(
        H[
          T["proc ("],
          V[T["arg1: int"], T["arg2: int"], T["arg3: int"]].join(T[", "]),
          T[")"]
        ]
      )

    if true:
      echo toString(
        H[
          T["proc ("],
          C[
            V[@[T["arg1: int"], T["arg2: int"],]].join(T[", "])
          ],
          T[")"]
        ]
      )


    if true:
      echo toString(
        H[
          T["proc ("],
          C[
            H[@[T["arg1: int"], T["arg2: int"],]].join(T[", "]),
            V[@[T["arg1: int"], T["arg2: int"],]].join(T[", "]),
          ],
          T[")"]
        ],
        40
      )

    if true:
      for i in [1, 5, 10]:
        var blocks = mapIt(0 .. i, T["arg: int" & $i])
        let bl = H[
          T["proc ("],
          C[
            H[blocks].join(T[", "]),
            V[blocks].join(T[", "])
          ],
          T[")"]
        ]

        echo toString(bl)
