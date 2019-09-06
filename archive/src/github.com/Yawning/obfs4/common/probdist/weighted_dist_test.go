/*
 * Copyright (c) 2014, Yawning Angel <yawning at torproject dot org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  * Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 *  * Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

package probdist

import (
	"fmt"
	"testing"

	"git.torproject.org/pluggable-transports/obfs4.git/common/drbg"
)

const debug = false

func TestWeightedDist(t *testing.T) {
	seed, err := drbg.NewSeed()
	if err != nil {
		t.Fatal("failed to generate a DRBG seed:", err)
	}

	const nrTrials = 1000000

	hist := make([]int, 1000)

	w := New(seed, 0, 999, true)
	if debug {
		// Dump a string representation of the probability table.
		fmt.Println("Table:")
		var sum float64
		for _, weight := range w.weights {
			sum += weight
		}
		for i, weight := range w.weights {
			p := weight / sum
			if p > 0.000001 { // Filter out tiny values.
				fmt.Printf(" [%d]: %f\n", w.minValue+w.values[i], p)
			}
		}
		fmt.Println()
	}

	for i := 0; i < nrTrials; i++ {
		value := w.Sample()
		hist[value]++
	}

	if debug {
		fmt.Println("Generated:")
		for value, count := range hist {
			if count != 0 {
				p := float64(count) / float64(nrTrials)
				fmt.Printf(" [%d]: %f (%d)\n", value, p, count)
			}
		}
	}
}
