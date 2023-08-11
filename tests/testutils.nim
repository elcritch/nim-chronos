#                Chronos Test Suite
#            (c) Copyright 2020-Present
#         Status Research & Development GmbH
#
#              Licensed under either of
#  Apache License, version 2.0, (LICENSE-APACHEv2)
#              MIT license (LICENSE-MIT)
import unittest2
import ../chronos, ../chronos/config
import std/[tables, os] 

{.used.}

suite "Asynchronous utilities test suite":
  when chronosFutureTracking:
    proc getCount(): uint =
      # This procedure counts number of Future[T] in double-linked list via list
      # iteration.
      var res = 0'u
      for item in pendingFutures():
        inc(res)
      res

  test "Future clean and leaks test":
    when chronosFutureTracking:
      if pendingFuturesCount(WithoutCompleted) == 0'u:
        if pendingFuturesCount(OnlyCompleted) > 0'u:
          poll()
        check pendingFuturesCount() == 0'u
      else:
        echo dumpPendingFutures()
        check false
    else:
      skip()

  test "FutureList basics test":
    when chronosFutureTracking:
      var fut1 = newFuture[void]()
      check:
        getCount() == 1'u
        pendingFuturesCount() == 1'u
      var fut2 = newFuture[void]()
      check:
        getCount() == 2'u
        pendingFuturesCount() == 2'u
      var fut3 = newFuture[void]()
      check:
        getCount() == 3'u
        pendingFuturesCount() == 3'u
      fut1.complete()
      poll()
      check:
        getCount() == 2'u
        pendingFuturesCount() == 2'u
      fut2.fail(newException(ValueError, ""))
      poll()
      check:
        getCount() == 1'u
        pendingFuturesCount() == 1'u
      fut3.cancel()
      poll()
      check:
        getCount() == 0'u
        pendingFuturesCount() == 0'u
    else:
      skip()

  test "FutureList async procedure test":
    when chronosFutureTracking:
      proc simpleProc() {.async.} =
        await sleepAsync(10.milliseconds)

      var fut = simpleProc()
      check:
        getCount() == 2'u
        pendingFuturesCount() == 2'u

      waitFor fut
      check:
        getCount() == 1'u
        pendingFuturesCount() == 1'u

      poll()
      check:
        getCount() == 0'u
        pendingFuturesCount() == 0'u
    else:
      skip()


  test "Test Closure During Metrics":
    when chronosClosureDurationMetric:
      proc simpleAsync1() {.async.} =
        os.sleep(50)
      
      waitFor(simpleAsync1())

      let metrics = getCallbackDurations()
      for (k,v) in metrics.pairs():
        let count = v.count
        let totalDuration = v.totalDuration
        if count > 0:
          echo ""
          echo "metric: ", $k
          echo "count: ", count
          echo "total: ", totalDuration
          echo "avg: ", totalDuration div count
        if k.procedure == "simpleAsync1":
          check v.totalDuration <= 60.milliseconds()
          check v.totalDuration >= 50.milliseconds()

    else:
      skip()

  test "Test Closure During Metrics await":
    when chronosClosureDurationMetric:
      proc simpleAsync2() {.async.} =
        os.sleep(50)
        await sleepAsync(50.milliseconds)
        os.sleep(50)
      
      waitFor(simpleAsync2())

      let metrics = getCallbackDurations()
      for (k,v) in metrics.pairs():
        let count = v.count
        let totalDuration = v.totalDuration
        if count > 0:
          echo ""
          echo "metric: ", $k
          echo "count: ", count
          echo "total: ", totalDuration
          echo "min: ", v.minSingleTime
          echo "max: ", v.maxSingleTime
          echo "avg: ", totalDuration div count
        if k.procedure == "simpleAsync2":
          check v.totalDuration <= 120.milliseconds()
          check v.totalDuration >= 100.milliseconds()

    else:
      skip()