package enproxy

import (
	"os"
	"strconv"
	"sync/atomic"
	"time"
)

var (
	// Connection metrics
	open                                           = int32(0)
	reading                                        = int32(0)
	readingFinishing                               = int32(0)
	blockedOnRead                                  = int32(0)
	writing                                        = int32(0)
	writingSelecting                               = int32(0)
	writingWriting                                 = int32(0)
	writePipeOpen                                  = int32(0)
	writingRequestPending                          = int32(0)
	writingSubmittingRequest                       = int32(0)
	writingProcessingRequest                       = int32(0)
	writingProcessingRequestPostingRequestFinished = int32(0)
	writingProcessingRequestPostingResponse        = int32(0)
	writingProcessingRequestDialingFirst           = int32(0)
	writingProcessingRequestRedialing              = int32(0)
	writingDoingWrite                              = int32(0)
	writingWritingEmpty                            = int32(0)
	writingFinishingBody                           = int32(0)
	writingPostingResponse                         = int32(0)
	writingFinishing                               = int32(0)
	blockedOnWrite                                 = int32(0)
	requesting                                     = int32(0)
	requestingFinishing                            = int32(0)
	closing                                        = int32(0)
	blockedOnClosing                               = int32(0)
)

func init() {
	traceOn, _ := strconv.ParseBool(os.Getenv("TRACE_CONN_STATE"))
	if !traceOn {
		return
	}

	go func() {
		for {
			time.Sleep(5 * time.Second)
			log.Debugf(
				`
---- Connections----
Open:                      %4d
Closing:                   %4d
Blocked on Closing:        %4d
Blocked on Read:           %4d
Reading:                   %4d
Reading Finishing:         %4d
Blocked on Write:          %4d
Writing:                   %4d
  Selecting:               %4d
  Writing:                 %4d
    Write Pipe Open:       %4d
    Request Pending:       %4d
      Submitting Req.:     %4d
      Processing Req.:     %4d
        Posting Req. Fin:  %4d
        Posting Resp:      %4d       
        Dialing First:     %4d
        Redialing:         %4d
    Doing Write:           %4d
  Posting Response:        %4d
  Writing Empty:           %4d
  Finishing Body:          %4d
  Finishing:               %4d
Requesting:                %4d
Requesting Finishing:      %4d
`, atomic.LoadInt32(&open),
				atomic.LoadInt32(&closing),
				atomic.LoadInt32(&blockedOnClosing),
				atomic.LoadInt32(&blockedOnRead),
				atomic.LoadInt32(&reading),
				atomic.LoadInt32(&readingFinishing),
				atomic.LoadInt32(&blockedOnWrite),
				atomic.LoadInt32(&writing),
				atomic.LoadInt32(&writingSelecting),
				atomic.LoadInt32(&writingWriting),
				atomic.LoadInt32(&writePipeOpen),
				atomic.LoadInt32(&writingRequestPending),
				atomic.LoadInt32(&writingSubmittingRequest),
				atomic.LoadInt32(&writingProcessingRequest),
				atomic.LoadInt32(&writingProcessingRequestPostingRequestFinished),
				atomic.LoadInt32(&writingProcessingRequestPostingResponse),
				atomic.LoadInt32(&writingProcessingRequestDialingFirst),
				atomic.LoadInt32(&writingProcessingRequestRedialing),
				atomic.LoadInt32(&writingDoingWrite),
				atomic.LoadInt32(&writingPostingResponse),
				atomic.LoadInt32(&writingWritingEmpty),
				atomic.LoadInt32(&writingFinishingBody),
				atomic.LoadInt32(&writingFinishing),
				atomic.LoadInt32(&requesting),
				atomic.LoadInt32(&requestingFinishing),
			)
		}
	}()
}

// Increment a metric
func increment(val *int32) {
	atomic.AddInt32(val, 1)
}

// Decrement a metric
func decrement(val *int32) {
	atomic.AddInt32(val, -1)
}
