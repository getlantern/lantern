// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/*
Gobind generates language bindings that make it possible to call Go code
and pass objects from Java.

Using gobind

Gobind takes a Go package and generates bindings for all of the exported
symbols. The exported symbols define the cross-language interface.

The gobind tool generates both an API stub in Java, and binding code in
Go. Start with a Go package:

	package hi

	import "fmt"

	func Hello(name string) {
		fmt.Println("Hello, %s!\n", name)
	}

Generate a Go binding package and Java stubs:

	go install golang.org/x/mobile/cmd/gobind
	gobind -lang=go github.com/crawshaw/hi > hi/go_hi/go_hi.go
	gobind -lang=java github.com/crawshaw/hi > hi/Hi.java

The generated Go package, go_hi, must be linked into your Go program:

	import _ "github.com/crawshaw/hi/go_hi"

Type restrictions

At present, only a subset of Go types are supported.

All exported symbols in the package must have types that are supported.
Supported types include:

	- Signed integer and floating point types.

	- String and boolean types.

	- Any function type all of whose parameters and results have
	  supported types. Functions must return either no results,
	  one result, or two results where the type of the second is
	  the built-in 'error' type.

	- Any interface type, all of whose exported methods have
	  supported function types.

	- Any struct type, all of whose exported methods have
	  supported function types and all of whose exported fields
	  have supported types.

Unexported symbols have no effect on the cross-language interface, and
as such are not restricted.

The set of supported types will eventually be expanded to cover all Go
types, but this is a work in progress.

Exceptions and panics are not yet supported. If either pass a language
boundary, the program will exit.

Passing Go objects to foreign languages

Consider a type for counting:

	package mypkg

	type Counter struct {
		Value int
	}

	func (c *Counter) Inc() { c.Value++ }

	func New() *Counter { return &Counter{ 5 } }

The generated bindings enable Java programs to create and use a Counter.

	public abstract class Mypkg {
		private Mypkg() {}
		public static final class Counter {
			public void Inc() { ... }
			public long GetValue() { ... }
			public void SetValue(long value) { ... }
		}
		public static Counter New() { ... }
	}

The package-level function New can be called like so:

	Counter c = Mypkg.New()

returns a Java Counter, which is a proxy for a Go *Counter. Calling the Inc
and Get methods will call the Go implementations of these methods.

Passing foreign language objects to Go

For a Go interface:

	package myfmt

	type Printer interface {
		Print(s string)
	}

	func PrintHello(p Printer) {
		p.Print("Hello, World!")
	}

gobind generates a Java stub that can be used to implement a Printer:

	public abstract class Myfmt {
		private Myfmt() {}
		public interface Printer {
			public void Print(String s);

			public static abstract class Stub implements Printer {
				...
			}

			...
		}

		public static void PrintHello(Printer p) { ... }
	}

You can extend Myfmt.Printer.Stub to implement the Printer interface, and
pass it to Go using the PrintHello package function:

	public class SysPrint extends Myfmt.Printer.Stub {
		public void Print(String s) {
			System.out.println(s);
		}
	}

The Java implementation can be used like so:

	Myfmt.Printer printer = new SysPrint();
	Myfmt.PrintHello(printer);

Avoid reference cycles

The language bindings maintain a reference to each object that has been
proxied. When a proxy object becomes unreachable, its finalizer reports
this fact to the object's native side, so that the reference can be
removed, potentially allowing the object to be reclaimed by its native
garbage collector.  The mechanism is symmetric.

However, it is possible to create a reference cycle between Go and
Java objects, via proxies, meaning objects cannot be collected. This
causes a memory leak.

For example, if a Go object G holds a reference to the Go proxy of a
Java object J, and J holds a reference to the Java proxy of G, then the
language bindings on each side must keep G and J live even if they are
otherwise unreachable.

We recommend that implementations of foreign interfaces do not hold
references to proxies of objects. That is: if you extend a Stub in
Java, do not store an instance of Seq.Object inside it.

Further reading

Examples can be found in http://golang.org/x/mobile/example.

Design doc: http://golang.org/s/gobind
*/
package main // import "golang.org/x/mobile/cmd/gobind"
