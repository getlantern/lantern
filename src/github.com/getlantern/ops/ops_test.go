package ops_test

import (
	"sync"
	"testing"

	"github.com/getlantern/errors"
	"github.com/getlantern/ops"
	"github.com/stretchr/testify/assert"
)

func TestSuccess(t *testing.T) {
	var reportedFailure error
	var reportedCtx map[string]interface{}
	report := func(failure error, ctx map[string]interface{}) {
		reportedFailure = failure
		reportedCtx = ctx
	}

	ops.RegisterReporter(report)
	ops.PutGlobal("g", "g1")
	op := ops.Enter("test_success").Put("a", 1).PutDynamic("b", func() interface{} { return 2 })
	defer op.Exit()
	innerOp := op.Enter("inside")
	innerOp.Error(nil)
	innerOp.Exit()

	assert.Nil(t, reportedFailure)
	expectedCtx := map[string]interface{}{
		"op":      "inside",
		"root_op": "test_success",
		"g":       "g1",
		"a":       1,
		"b":       2,
	}
	assert.Equal(t, expectedCtx, reportedCtx)
}

func TestFailure(t *testing.T) {
	var reportedFailure error
	var reportedCtx map[string]interface{}
	report := func(failure error, ctx map[string]interface{}) {
		reportedFailure = failure
		reportedCtx = ctx
	}

	ops.RegisterReporter(report)
	op := ops.Enter("test_failure")
	var wg sync.WaitGroup
	wg.Add(1)
	op.Go(func() {
		op.Error(errors.New("I failed").With("errorcontext", 5))
		wg.Done()
	})
	wg.Wait()
	op.Exit()

	assert.Contains(t, reportedFailure.Error(), "I failed")
	assert.Equal(t, 5, reportedCtx["errorcontext"])
}
