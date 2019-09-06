balancer [![Travis CI Status](https://travis-ci.org/getlantern/balancer.svg?branch=master)](https://travis-ci.org/getlantern/balancer)&nbsp;[![Coverage Status](https://coveralls.io/repos/getlantern/balancer/badge.png)](https://coveralls.io/r/getlantern/balancer)&nbsp;[![GoDoc](https://godoc.org/github.com/getlantern/balancer?status.png)](http://godoc.org/github.com/getlantern/balancer)
==========
Connection balancer library for Go

To install:

`go get github.com/getlantern/balancer`

For docs:

`godoc github.com/getlantern/balancer`

===Benchmark

`go test -bench .` to evaluate performance of different strategy to pick
dialer. `Sticky` and `QualityFirst` strategy seems has better result at this
moment.

Example output:
```
BenchmarkQualityFirst-4   100000         23222 ns/op
--- BENCH: BenchmarkQualityFirst-4
    benchmark_test.go:98: '1%': 83/16850, '10%': 199/3596, '99%': 228/524,  fail/total = 510/20970 (2.4%) in 10000 runs
    benchmark_test.go:98: '1% 10ns±8ns': 85/18319, '10% 10ns±8ns': 86/1982, '50% 10ns±8ns': 85/457,  fail/total = 256/20758 (1.2%) in 10000 runs
    benchmark_test.go:98: '1%': 843/169828, '10%': 1784/35104, '99%': 3074/6879,  fail/total = 5701/211811 (2.7%) in 100000 runs
    benchmark_test.go:98: '1% 10ns±8ns': 955/184247, '10% 10ns±8ns': 954/19488, '50% 10ns±8ns': 954/4734,  fail/total = 2863/208469 (1.4%) in 100000 runs
```
