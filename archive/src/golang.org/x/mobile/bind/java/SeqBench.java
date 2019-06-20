// Copyright 2016 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package go;

import android.test.InstrumentationTestCase;
import android.util.Log;

import java.util.Map;
import java.util.HashMap;

import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;

import go.benchmark.Benchmark;

public class SeqBench extends InstrumentationTestCase {

  public static class AnI implements Benchmark.I {
    @Override public void F() {
    }
  }

  private static class Benchmarks implements Benchmark.Benchmarks {
    private static Map<String, Runnable> benchmarks;
    private static ExecutorService executor = Executors.newSingleThreadExecutor();

    static {
      benchmarks = new HashMap<String, Runnable>();
      benchmarks.put("Empty", new Runnable() {
        @Override public void run() {
        }
      });
      benchmarks.put("Noargs", new Runnable() {
        @Override public void run() {
          Benchmark.Noargs();
        }
      });
      benchmarks.put("Onearg", new Runnable() {
        @Override public void run() {
          Benchmark.Onearg(0);
        }
      });
      benchmarks.put("Manyargs", new Runnable() {
        @Override public void run() {
          Benchmark.Manyargs(0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        }
      });
      benchmarks.put("Oneret", new Runnable() {
        @Override public void run() {
          Benchmark.Oneret();
        }
      });
      final Benchmark.I javaRef = new AnI();
      benchmarks.put("Refforeign", new Runnable() {
        @Override public void run() {
          Benchmark.Ref(javaRef);
        }
      });
      final Benchmark.I goRef = Benchmark.NewI();
      benchmarks.put("Refgo", new Runnable() {
        @Override public void run() {
          Benchmark.Ref(goRef);
        }
      });
      benchmarks.put("StringShort", new Runnable() {
        @Override public void run() {
          Benchmark.String(Benchmark.ShortString);
        }
      });
      benchmarks.put("StringLong", new Runnable() {
        @Override public void run() {
          Benchmark.String(Benchmark.LongString);
        }
      });
      benchmarks.put("StringShortUnicode", new Runnable() {
        @Override public void run() {
          Benchmark.String(Benchmark.ShortStringUnicode);
        }
      });
      benchmarks.put("StringLongUnicode", new Runnable() {
        @Override public void run() {
          Benchmark.String(Benchmark.LongStringUnicode);
        }
      });
      benchmarks.put("StringRetShort", new Runnable() {
        @Override public void run() {
          Benchmark.StringRetShort();
        }
      });
      benchmarks.put("StringRetLong", new Runnable() {
        @Override public void run() {
          Benchmark.StringRetLong();
        }
      });
      final byte[] shortSlice = Benchmark.getShortSlice();
      benchmarks.put("SliceShort", new Runnable() {
        @Override public void run() {
          Benchmark.Slice(shortSlice);
        }
      });
      final byte[] longSlice = Benchmark.getLongSlice();
      benchmarks.put("SliceLong", new Runnable() {
        @Override public void run() {
          Benchmark.Slice(longSlice);
        }
      });
    }

    public void RunDirect(String name, final long n) {
      final Runnable r = benchmarks.get(name);
      try {
        executor.submit(new Runnable() {
          @Override public void run() {
            for (int i = 0; i < n; i++) {
              r.run();
            }
          }
        }).get();
      } catch (Exception e) {
        throw new RuntimeException(e);
      }
    }

    public void Run(String name, long n) {
      final Runnable r = benchmarks.get(name);
      for (int i = 0; i < n; i++) {
        r.run();
      }
    }

    @Override public Benchmark.I NewI() {
      return new AnI();
    }
    @Override public void Ref(Benchmark.I i) {
    }
    @Override public void Noargs() {
    }
    @Override public void Onearg(long i) {
    }
    @Override public long Oneret() {
      return 0;
    }
    @Override public void Manyargs(long p0, long p1, long p2, long p3, long p4, long p5, long p6, long p7, long gp8, long p9) {
    }
    @Override public void String(String s) {
    }
    @Override public void Slice(byte[] s) {
    }
	@Override public String StringRetShort() {
		return Benchmark.ShortString;
	}
	@Override public String StringRetLong() {
		return Benchmark.LongString;
	}
  }

  public void testBenchmark() {
    Benchmark.RunBenchmarks(new Benchmarks());
  }
}
