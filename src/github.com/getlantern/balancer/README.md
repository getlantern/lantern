balancer [![Travis CI Status](https://travis-ci.org/getlantern/balancer.svg?branch=master)](https://travis-ci.org/getlantern/balancer)&nbsp;[![Coverage Status](https://coveralls.io/repos/getlantern/balancer/badge.png)](https://coveralls.io/r/getlantern/balancer)&nbsp;[![GoDoc](https://godoc.org/github.com/getlantern/balancer?status.png)](http://godoc.org/github.com/getlantern/balancer)
==========
Connection balancer library for Go

To install:

`go get github.com/getlantern/balancer`

For docs:

`godoc github.com/getlantern/balancer`

===Benchmark

To evaluate performance of different strategy to pick dialer, run below
command. The 20s `benchtime` is to simulate network latency in real world.
`Sticky` and `QualityFirst` strategy seems has better result at this moment.

```
go test -bench . -benchtime 20s
```

Example output:
```
BenchmarkSticky-4           1000      23855693 ns/op
--- BENCH: BenchmarkSticky-4
    benchmark_test.go:89: 'Fail 1% 10ms ± 0 dialer': 11
    benchmark_test.go:89: 'Fail 10% 10ms ± 0 dialer': 12
    benchmark_test.go:89: 'Fail 50% 10ms ± 0 dialer': 10
    benchmark_test.go:92: - Failed dial attempts: 33 out of 1000
    benchmark_test.go:89: 'Fail 1% 10ms ± 8ms dialer': 12
    benchmark_test.go:89: 'Fail 10% 10ms ± 8ms dialer': 12
    benchmark_test.go:89: 'Fail 50% 10ms ± 8ms dialer': 8
    benchmark_test.go:92: - Failed dial attempts: 32 out of 1000
```
