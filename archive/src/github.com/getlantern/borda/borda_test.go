package borda

import (
	"fmt"
	"sync/atomic"
	"testing"
	"time"

	"github.com/getlantern/eventual"
	"github.com/influxdata/influxdb/client/v2"
	"github.com/stretchr/testify/assert"
)

const (
	dbName = "lantern"
)

func TestBatchingOnSize(t *testing.T) {
	ok, err := doTest(t, func(write WriteFunc) Collector {
		return NewCollector(&Options{
			IndexedDimensions: []string{"dim_string", "dim_int"},
			WriteToDatabase:   write,
			DBName:            dbName,
			BatchSize:         1,
			MaxBatchWindow:    24 * time.Hour,
			MaxRetries:        5,
			RetryInterval:     5 * time.Millisecond,
		})
	})

	assert.True(t, ok, "Write should have succeeded")
	assert.NoError(t, err, "Waiting for Collector to finish should not have returned error")
}

func TestBatchingOnTime(t *testing.T) {
	ok, err := doTest(t, func(write WriteFunc) Collector {
		return NewCollector(&Options{
			IndexedDimensions: []string{"dim_string", "dim_int"},
			WriteToDatabase:   write,
			DBName:            dbName,
			BatchSize:         1000,
			MaxBatchWindow:    1 * time.Millisecond,
			MaxRetries:        5,
			RetryInterval:     5 * time.Millisecond,
		})
	})

	assert.True(t, ok, "Write should have succeeded")
	assert.NoError(t, err, "Waiting for Collector to finish should not have returned error")
}

func TestRetriesExhausted(t *testing.T) {
	ok, err := doTest(t, func(write WriteFunc) Collector {
		return NewCollector(&Options{
			IndexedDimensions: []string{"dim_string", "dim_int"},
			WriteToDatabase:   write,
			DBName:            dbName,
			BatchSize:         1000,
			MaxBatchWindow:    1 * time.Millisecond,
			MaxRetries:        1,
			RetryInterval:     5 * time.Millisecond,
		})
	})

	assert.False(t, ok, "Write should have failed")
	assert.Error(t, err, "Waiting for collector to finish should have returned error")
}

func doTest(t *testing.T, buildCollector func(WriteFunc) Collector) (bool, error) {
	done := eventual.NewValue()

	i := int32(0)
	write := func(batch client.BatchPoints) error {
		if atomic.AddInt32(&i, 1) < 3 {
			return fmt.Errorf("Failed on try %d", i)
		}
		validateBatch(t, false, batch)
		done.Set(true)
		return nil
	}

	c := buildCollector(write)

	c.Submit(&Measurement{
		Name: "mymeasure",
		Ts:   time.Now(),
		Values: map[string]float64{
			"field_float": 2.1,
		},
		Dimensions: map[string]interface{}{
			"dim_string":   "a",
			"dim_int":      1,
			"field_int":    2,
			"field_bool":   true,
			"field_string": "stringy",
		},
	})

	_c := c.(*collector)
	timeout := time.Duration(_c.MaxRetries) * _c.RetryInterval * 2
	start := time.Now()
	_, ok := done.Get(timeout)
	delta := time.Now().Sub(start)
	timeout = timeout - delta
	if timeout < 0 {
		timeout = 0
	}
	return ok, c.Wait(timeout)
}

func validateBatch(t *testing.T, allFloats bool, batch client.BatchPoints) {
	assert.Equal(t, dbName, batch.Database(), "Incorrect database name")
	assert.Len(t, batch.Points(), 1, "Incorrect batch size")
	point := batch.Points()[0]
	assert.Equal(t, "combined", point.Name(), "Incorrect measurement key")
	assert.NotNil(t, point.Time(), "Missing timestamp")
	assert.Equal(t, map[string]string{
		// Original dimensions, all are strings
		"dim_string": "a",
		"dim_int":    "1",

		// Synthetic field capturing original measurement key
		"orig_measurement": "mymeasure",
	}, point.Tags(), "Incorrect tags")

	var dimI interface{} = int64(1)
	var i interface{} = int64(2)
	if allFloats {
		dimI = float64(1)
		i = float64(2)
	}

	assert.Equal(t, map[string]interface{}{
		// Original fields
		"field_int":    i,
		"field_float":  float64(2.1),
		"field_bool":   true,
		"field_string": "stringy",

		// Synthetic fields for dimensions
		"_dim_string": "a",
		"_dim_int":    dimI,
	}, point.Fields(), "Incorrect fields")
}
