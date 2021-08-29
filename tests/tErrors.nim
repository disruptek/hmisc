import hmisc/preludes/unittest

testFileStarted()

import
  hmisc/core/[all, code_errors]


suite "Exception from string":
  startHax()
  test "Single annotation":
    try:
      raise toCodeError("ABCDE", 2, 1, "Hello", "Use world")
    except CodeError as e:
      echo e.msg

  # test "Single annotation":
  #   try:
  #     raise toCodeError("12345", 6, 1,
  #                       "Missing second part of 'hello world'",
  #                       "Add 'world'")

  #   except CodeError as e:
  #     echo e.msg

testFileEnded()