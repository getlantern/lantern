// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/*
Gobind generates language bindings that make it possible to call Go
functions from Java and Objective-C.

Typically gobind is not used directly. Instead, a binding is
generated and automatically packaged for Android or iOS by
`gomobile bind`. For more details on installing and using the gomobile
tool, see https://golang.org/x/mobile/cmd/gomobile.

Binding Go

Gobind generates target language (Java or Objective-C) bindings for
each exported symbol in a Go package. The Go package you choose to
bind defines a cross-language interface.

Bindings require additional Go code be generated, so using gobind
manually requires calling it twice, first with -lang=<target>, where
target is either java or objc, and again with -lang=go. The generated
package can then be _ imported into a Go program, typically built
with -buildmode=c-archive for iOS or -buildmode=c-shared for Android.
These details are handled by the `gomobile bind` command.

Passing Go objects to target languages

Consider a type for counting:

	package mypkg

	type Counter struct {
		Value int
	}

	func (c *Counter) Inc() { c.Value++ }

	func New() *Counter { return &Counter{ 5 } }

In Java, the generated bindings are,

	public abstract class Mypkg {
		private Mypkg() {}
		public static final class Counter {
			public void Inc();
			public long GetValue();
			public void SetValue(long value);
		}
		public static Counter New();
	}

The package-level function New can be called like so:

	Counter c = Mypkg.New()

returns a Java Counter, which is a proxy for a Go *Counter. Calling the Inc
and Get methods will call the Go implementations of these methods.

Similarly, the same Go package will generate the Objective-C interface

	@class GoMypkgCounter;

	@interface GoMypkgCounter : NSObject {
	}

	@property(strong, readonly) GoSeqRef *ref;
	- (void)Inc;
	- (int64_t)Value;
	- (void)setValue:(int64_t)v;
	@end

	FOUNDATION_EXPORT GoMypkgCounter* GoMypkgNewCounter();

The equivalent of calling New in Go is GoMypkgNewCounter in Objective-C.
The returned GoMypkgCounter* holds a reference to an underlying Go
*Counter.

Passing target language objects to Go

For a Go interface:

	package myfmt

	type Printer interface {
		Print(s string)
	}

	func PrintHello(p Printer) {
		p.Print("Hello, World!")
	}

gobind generates a Java interface that can be used to implement a Printer:

	public abstract class Myfmt {
		private Myfmt() {}
		public interface Printer {
			public void Print(String s);

			...
		}

		public static void PrintHello(Printer p) { ... }
	}

You can implement Myfmt.Printer, and pass it to Go using the PrintHello
package function:

	public class SysPrint implements Myfmt.Printer {
		public void Print(String s) {
			System.out.println(s);
		}
	}

The Java implementation can be used like so:

	Myfmt.Printer printer = new SysPrint();
	Myfmt.PrintHello(printer);


For Objective-C binding, gobind generates a protocol that declares
methods corresponding to Go interface's methods.

	@protocol GoMyfmtPrinter
	- (void)Print:(NSString*)s;
	@end

	FOUNDATION_EXPORT void GoMyfmtPrintHello(id<GoMyfmtPrinter> p0);

Any Objective-C classes conforming to the GoMyfmtPrinter protocol can be
passed to Go using the GoMyfmtPrintHello function:

	@interface SysPrint : NSObject<GoMyfmtPrinter> {
	}
	@end

	@implementation SysPrint {
	}
	- (void)Print:(NSString*)s {
		NSLog("%@", s);
	}
	@end

The Objective-C implementation can be used like so:

	SysPrint* printer = [[SysPrint alloc] init];
	GoMyfmtPrintHello(printer);


Type restrictions

At present, only a subset of Go types are supported.

All exported symbols in the package must have types that are supported.
Supported types include:

	- Signed integer and floating point types.

	- String and boolean types.

	- Byte slice types. Note the current implementation does not
	  support data mutation of slices passed in as function arguments.
	  (https://golang.org/issues/12113)

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

The set of supported types will eventually be expanded to cover more
Go types, but this is a work in progress.

Exceptions and panics are not yet supported. If either pass a language
boundary, the program will exit.

Avoid reference cycles

The language bindings maintain a reference to each object that has been
proxied. When a proxy object becomes unreachable, its finalizer reports
this fact to the object's native side, so that the reference can be
removed, potentially allowing the object to be reclaimed by its native
garbage collector.  The mechanism is symmetric.

However, it is possible to create a reference cycle between Go and
objects in target languages, via proxies, meaning objects cannot be
collected. This causes a memory leak.

For example, in Java: if a Go object G holds a reference to the Go
proxy of a Java object J, and J holds a reference to the Java proxy
of G, then the language bindings on each side must keep G and J live
even if they are otherwise unreachable.

We recommend that implementations of foreign interfaces do not hold
references to proxies of objects. That is: if you implement a Go
interface in Java, do not store an instance of Seq.Object inside it.

Further reading

Examples can be found in http://golang.org/x/mobile/example.

Design doc: http://golang.org/s/gobind
*/
package main // import "golang.org/x/mobile/cmd/gobind"
