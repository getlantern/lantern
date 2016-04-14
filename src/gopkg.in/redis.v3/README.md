# Redis client for Golang [![Build Status](https://travis-ci.org/go-redis/redis.png?branch=master)](https://travis-ci.org/go-redis/redis)

Supports:

- Redis 3 commands except QUIT, MONITOR, SLOWLOG and SYNC.
- [Pub/Sub](http://godoc.org/gopkg.in/redis.v3#PubSub).
- [Transactions](http://godoc.org/gopkg.in/redis.v3#Multi).
- [Pipelining](http://godoc.org/gopkg.in/redis.v3#Client.Pipeline).
- [Scripting](http://godoc.org/gopkg.in/redis.v3#Script).
- [Timeouts](http://godoc.org/gopkg.in/redis.v3#Options).
- [Redis Sentinel](http://godoc.org/gopkg.in/redis.v3#NewFailoverClient).
- [Redis Cluster](http://godoc.org/gopkg.in/redis.v3#NewClusterClient).
- [Ring](http://godoc.org/gopkg.in/redis.v3#NewRing).
- [Cache friendly](https://github.com/go-redis/cache).
- [Rate limiting](https://github.com/go-redis/rate).
- [Distributed Locks](https://github.com/bsm/redis-lock).

API docs: http://godoc.org/gopkg.in/redis.v3.
Examples: http://godoc.org/gopkg.in/redis.v3#pkg-examples.

## Installation

Install:

    go get gopkg.in/redis.v3

## Quickstart

```go
func ExampleNewClient() {
	client := redis.NewClient(&redis.Options{
		Addr:     "localhost:6379",
		Password: "", // no password set
		DB:       0,  // use default DB
	})

	pong, err := client.Ping().Result()
	fmt.Println(pong, err)
	// Output: PONG <nil>
}

func ExampleClient() {
	err := client.Set("key", "value", 0).Err()
	if err != nil {
		panic(err)
	}

	val, err := client.Get("key").Result()
	if err != nil {
		panic(err)
	}
	fmt.Println("key", val)

	val2, err := client.Get("key2").Result()
	if err == redis.Nil {
		fmt.Println("key2 does not exists")
	} else if err != nil {
		panic(err)
	} else {
		fmt.Println("key2", val2)
	}
	// Output: key value
	// key2 does not exists
}
```

## Howto

Please go through [examples](http://godoc.org/gopkg.in/redis.v3#pkg-examples) to get an idea how to use this package.

## Look and feel

Some corner cases:

    SET key value EX 10 NX
    set, err := client.SetNX("key", "value", 10*time.Second).Result()

    SORT list LIMIT 0 2 ASC
    vals, err := client.Sort("list", redis.Sort{Offset: 0, Count: 2, Order: "ASC"}).Result()

    ZRANGEBYSCORE zset -inf +inf WITHSCORES LIMIT 0 2
    vals, err := client.ZRangeByScoreWithScores("zset", redis.ZRangeByScore{
        Min: "-inf",
        Max: "+inf",
        Offset: 0,
        Count: 2,
    }).Result()

    ZINTERSTORE out 2 zset1 zset2 WEIGHTS 2 3 AGGREGATE SUM
    vals, err := client.ZInterStore("out", redis.ZStore{Weights: []int64{2, 3}}, "zset1", "zset2").Result()

    EVAL "return {KEYS[1],ARGV[1]}" 1 "key" "hello"
    vals, err := client.Eval("return {KEYS[1],ARGV[1]}", []string{"key"}, []string{"hello"}).Result()

## Benchmark

go-redis vs redigo:

```
BenchmarkSetGoRedis10Conns64Bytes-4 	  200000	      7621 ns/op	     210 B/op	       6 allocs/op
BenchmarkSetGoRedis100Conns64Bytes-4	  200000	      7554 ns/op	     210 B/op	       6 allocs/op
BenchmarkSetGoRedis10Conns1KB-4     	  200000	      7697 ns/op	     210 B/op	       6 allocs/op
BenchmarkSetGoRedis100Conns1KB-4    	  200000	      7688 ns/op	     210 B/op	       6 allocs/op
BenchmarkSetGoRedis10Conns10KB-4    	  200000	      9214 ns/op	     210 B/op	       6 allocs/op
BenchmarkSetGoRedis100Conns10KB-4   	  200000	      9181 ns/op	     210 B/op	       6 allocs/op
BenchmarkSetGoRedis10Conns1MB-4     	    2000	    583242 ns/op	    2337 B/op	       6 allocs/op
BenchmarkSetGoRedis100Conns1MB-4    	    2000	    583089 ns/op	    2338 B/op	       6 allocs/op
BenchmarkSetRedigo10Conns64Bytes-4  	  200000	      7576 ns/op	     208 B/op	       7 allocs/op
BenchmarkSetRedigo100Conns64Bytes-4 	  200000	      7782 ns/op	     208 B/op	       7 allocs/op
BenchmarkSetRedigo10Conns1KB-4      	  200000	      7958 ns/op	     208 B/op	       7 allocs/op
BenchmarkSetRedigo100Conns1KB-4     	  200000	      7725 ns/op	     208 B/op	       7 allocs/op
BenchmarkSetRedigo10Conns10KB-4     	  100000	     18442 ns/op	     208 B/op	       7 allocs/op
BenchmarkSetRedigo100Conns10KB-4    	  100000	     18818 ns/op	     208 B/op	       7 allocs/op
BenchmarkSetRedigo10Conns1MB-4      	    2000	    668829 ns/op	     226 B/op	       7 allocs/op
BenchmarkSetRedigo100Conns1MB-4     	    2000	    679542 ns/op	     226 B/op	       7 allocs/op
```

Redis Cluster:

```
BenchmarkRedisPing-4                	  200000	      6983 ns/op	     116 B/op	       4 allocs/op
BenchmarkRedisClusterPing-4         	  100000	     11535 ns/op	     117 B/op	       4 allocs/op
```

## Shameless plug

Check my [PostgreSQL client for Go](https://github.com/go-pg/pg).
