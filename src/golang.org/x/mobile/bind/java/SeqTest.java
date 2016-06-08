// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package go;

import android.test.InstrumentationTestCase;
import android.test.MoreAsserts;

import java.util.Arrays;
import java.util.Random;

import go.testpkg.Testpkg;
import go.secondpkg.Secondpkg;

public class SeqTest extends InstrumentationTestCase {
  public SeqTest() {
  }

  public void testConst() {
    assertEquals("const String", "a string", Testpkg.AString);
    assertEquals("const Int", 7, Testpkg.AnInt);
    assertEquals("const Bool", true, Testpkg.ABool);
    assertEquals("const Float", 0.12345, Testpkg.AFloat, 0.0001);

    assertEquals("const MinInt32", -1<<31, Testpkg.MinInt32);
    assertEquals("const MaxInt32", (1<<31) - 1, Testpkg.MaxInt32);
    assertEquals("const MinInt64", -1L<<63, Testpkg.MinInt64);
    assertEquals("const MaxInt64", (1L<<63) - 1, Testpkg.MaxInt64);
    assertEquals("const SmallestNonzeroFloat64", 4.940656458412465441765687928682213723651e-324, Testpkg.SmallestNonzeroFloat64, 1e-323);
    assertEquals("const MaxFloat64", 1.797693134862315708145274237317043567981e+308, Testpkg.MaxFloat64, 0.0001);
    assertEquals("const SmallestNonzeroFloat32", 1.401298464324817070923729583289916131280e-45, Testpkg.SmallestNonzeroFloat32, 1e-44);
    assertEquals("const MaxFloat32", 3.40282346638528859811704183484516925440e+38, Testpkg.MaxFloat32, 0.0001);
    assertEquals("const Log2E", 1/0.693147180559945309417232121458176568075500134360255254120680009, Testpkg.Log2E, 0.0001);
  }

  public void testRefMap() {
    // Ensure that the RefMap.live count is kept in sync
    // even a particular reference number is removed and
    // added again
    Seq.RefMap m = new Seq.RefMap();
    Seq.Ref r = new Seq.Ref(1, null);
    m.put(r.refnum, r);
    m.remove(r.refnum);
    m.put(r.refnum, r);
    // Force the RefMap to grow, to activate the sanity
    // checking of the live count in RefMap.grow.
    for (int i = 2; i < 24; i++) {
      m.put(i, new Seq.Ref(i, null));
    }
  }

  public void testVar() {
    assertEquals("var StringVar", "a string var", Testpkg.getStringVar());

    String newStringVar = "a new string var";
    Testpkg.setStringVar(newStringVar);
    assertEquals("var StringVar", newStringVar, Testpkg.getStringVar());

    assertEquals("var IntVar", 77, Testpkg.getIntVar());

    long newIntVar = 777;
    Testpkg.setIntVar(newIntVar);
    assertEquals("var IntVar", newIntVar, Testpkg.getIntVar());

    Testpkg.S s0 = Testpkg.getStructVar();
    assertEquals("var StructVar", "a struct var", s0.String());
    Testpkg.S s1 = Testpkg.New();
    Testpkg.setStructVar(s1);
    assertEquals("var StructVar", s1.String(), Testpkg.getStructVar().String());

    AnI obj = new AnI();
    obj.name = "this is an I";
    Testpkg.setInterfaceVar(obj);
    assertEquals("var InterfaceVar", obj.String(), Testpkg.getInterfaceVar().String());
  }

  public void testAssets() {
    // Make sure that a valid context is set before reading assets
    Seq.setContext(getInstrumentation().getContext());
    String want = "Hello, Assets.\n";
    String got = Testpkg.ReadAsset();
    assertEquals("Asset read", want, got);
  }

  public void testAdd() {
    long res = Testpkg.Add(3, 4);
    assertEquals("Unexpected arithmetic failure", 7, res);
  }

  public void testBool() {
    assertTrue(Testpkg.Negate(false));
    assertFalse(Testpkg.Negate(true));
  }

  public void testShortString() {
    String want = "a short string";
    String got = Testpkg.StrDup(want);
    assertEquals("Strings should match", want, got);

    want = "";
    got = Testpkg.StrDup(want);
    assertEquals("Strings should match (empty string)", want, got);

    got = Testpkg.StrDup(null);
    assertEquals("Strings should match (null string)", want, got);
  }

  public void testLongString() {
    StringBuilder b = new StringBuilder();
    for (int i = 0; i < 128*1024; i++) {
      b.append("0123456789");
    }
    String want = b.toString();
    String got = Testpkg.StrDup(want);
    assertEquals("Strings should match", want, got);
  }

  public void testUnicode() {
    String[] tests = new String[]{
      "abcxyz09{}",
      "Hello, 世界",
      "\uffff\uD800\uDC00\uD800\uDC01\uD808\uDF45\uDBFF\uDFFF",
      // From Go std lib tests in unicode/utf16/utf16_test.go
      "\u0001\u0002\u0003\u0004",
      "\uffff\ud800\udc00\ud800\udc01\ud808\udf45\udbff\udfff",
      "\ud800a",
      "\udfff"
    };
    String[] wants = new String[]{
      "abcxyz09{}",
      "Hello, 世界",
      "\uffff\uD800\uDC00\uD800\uDC01\uD808\uDF45\uDBFF\uDFFF",
      "\u0001\u0002\u0003\u0004",
      "\uffff\ud800\udc00\ud800\udc01\ud808\udf45\udbff\udfff",
      "\ufffda",
      "\ufffd"
    };
    for (int i = 0; i < tests.length; i++) {
      String got = Testpkg.StrDup(tests[i]);
      String want = wants[i];
      assertEquals("Strings should match", want, got);
    }
  }

  public void testNilErr() throws Exception {
    Testpkg.Err(null); // returns nil, no exception
  }

  public void testErr() {
    String msg = "Go errors are dropped into the confusing space of exceptions";
    try {
      Testpkg.Err(msg);
      fail("expected non-nil error to be turned into an exception");
    } catch (Exception e) {
      assertEquals("messages should match", msg, e.getMessage());
    }
  }

  public void testByteArray() {
    for (int i = 0; i < 2048; i++) {
      if (i == 0) {
        byte[] got = Testpkg.BytesAppend(null, null);
        assertEquals("Bytes(null+null) should match", (byte[])null, got);
        got = Testpkg.BytesAppend(new byte[0], new byte[0]);
        assertEquals("Bytes(empty+empty) should match", (byte[])null, got);
        continue;
      }

      byte[] want = new byte[i];
      new Random().nextBytes(want);

      byte[] s1 = null;
      byte[] s2 = null;
      if (i > 0) {
        s1 = Arrays.copyOfRange(want, 0, 1);
      }
      if (i > 1) {
        s2 = Arrays.copyOfRange(want, 1, i);
      }
      byte[] got = Testpkg.BytesAppend(s1, s2);
      MoreAsserts.assertEquals("Bytes(len="+i+") should match", want, got);
    }
  }

  // Test for golang.org/issue/9486.
  public void testByteArrayAfterString() {
    byte[] bytes = new byte[1024];
    for (int i=0; i < bytes.length; i++) {
           bytes[i] = 8;
    }

    String stuff = "stuff";
    byte[] got = Testpkg.AppendToString(stuff, bytes);

    try {
      byte[] s = stuff.getBytes("UTF-8");
      byte[] want = new byte[s.length + bytes.length];
      System.arraycopy(s, 0, want, 0, s.length);
      System.arraycopy(bytes, 0, want, s.length, bytes.length);
      MoreAsserts.assertEquals("Bytes should match", want, got);
    } catch (Exception e) {
      fail("Cannot perform the test: " + e.toString());
    }
  }

  public void testGoRefGC() {
    Testpkg.S s = Testpkg.New();
    runGC();
    long collected = Testpkg.NumSCollected();
    assertEquals("Only S should be pinned", 0, collected);

    s = null;
    runGC();
    collected = Testpkg.NumSCollected();
    assertEquals("S should be collected", 1, collected);
  }

  private class AnI implements Testpkg.I {
    public void E() throws Exception {
      throw new Exception("my exception from E");
    }

    boolean calledF;
    public void F() {
      calledF = true;
    }

    public Testpkg.I I() {
      return this;
    }

    public Testpkg.S S() {
      return Testpkg.New();
    }

    public String StoString(Testpkg.S s) {
      return s.String();
    }

    public long V() {
      return 1234;
    }

    public long VE() throws Exception {
      throw new Exception("my exception from VE");
    }

    public String name;

    public String String() {
      return name;
    }

  }

  // TODO(hyangah): add tests for methods that take parameters.

  public void testInterfaceMethodReturnsError() {
    final AnI obj = new AnI();
    try {
      Testpkg.CallE(obj);
      fail("Expecting exception but none was thrown.");
    } catch (Exception e) {
      assertEquals("Error messages should match", "my exception from E", e.getMessage());
    }
  }

  public void testInterfaceMethodVoid() {
    final AnI obj = new AnI();
    Testpkg.CallF(obj);
    assertTrue("Want AnI.F to be called", obj.calledF);
  }

  public void testInterfaceMethodReturnsInterface() {
    AnI obj = new AnI();
    obj.name = "testing AnI.I";
    Testpkg.I i = Testpkg.CallI(obj);
    assertEquals("Want AnI.I to return itself", i.String(), obj.String());

    runGC();

    i = Testpkg.CallI(obj);
    assertEquals("Want AnI.I to return itself", i.String(), obj.String());
  }

  public void testInterfaceMethodReturnsStructPointer() {
    final AnI obj = new AnI();
    for (int i = 0; i < 5; i++) {
    	Testpkg.S s = Testpkg.CallS(obj);
	runGC();
    }
  }

  public void testInterfaceMethodTakesStructPointer() {
    final AnI obj = new AnI();
    Testpkg.S s = Testpkg.CallS(obj);
    String got = obj.StoString(s);
    String want = s.String();
    assertEquals("Want AnI.StoString(s) to call s's String", want, got);
  }

  public void testInterfaceMethodReturnsInt() {
    final AnI obj = new AnI();
    assertEquals("Values must match", 1234, Testpkg.CallV(obj));
  }

  public void testInterfaceMethodReturnsIntOrError() {
    final AnI obj = new AnI();
    try {
      long v = Testpkg.CallVE(obj);
      fail("Expecting exception but none was thrown and got value " + v);
    } catch (Exception e) {
      assertEquals("Error messages should match", "my exception from VE", e.getMessage());
    }
  }

  boolean finalizedAnI;

  private class AnI_Traced extends AnI {
    @Override
    public void finalize() throws Throwable {
      finalizedAnI = true;
      super.finalize();
    }
  }

  public void testJavaRefGC() {
    finalizedAnI = false;
    AnI obj = new AnI_Traced();
    Testpkg.CallF(obj);
    assertTrue("want F to be called", obj.calledF);
    Testpkg.CallF(obj);
    obj = null;
    runGC();
    assertTrue("want obj to be collected", finalizedAnI);
  }

  public void testJavaRefKeep() {
    finalizedAnI = false;
    AnI obj = new AnI_Traced();
    Testpkg.CallF(obj);
    Testpkg.CallF(obj);
    obj = null;
    runGC();
    assertTrue("want obj not to be kept by Go", finalizedAnI);

    finalizedAnI = false;
    obj = new AnI_Traced();
    Testpkg.Keep(obj);
    obj = null;
    runGC();
    assertFalse("want obj to be kept live by Go", finalizedAnI);
  }

  private int countI = 0;

  private class CountI implements Testpkg.I {
    public void F() { countI++; }

    public void E() throws Exception {}
    public Testpkg.I I() { return null; }
    public Testpkg.S S() { return null; }
    public String StoString(Testpkg.S s) { return ""; }
    public long V() { return 0; }
    public long VE() throws Exception { return 0; }
    public String String() { return ""; }
  }

  public void testGoRefMapGrow() {
    CountI obj = new CountI();
    Testpkg.Keep(obj);

    // Push active references beyond base map size.
    for (int i = 0; i < 24; i++) {
      CountI o = new CountI();
      Testpkg.CallF(o);
      if (i%3==0) {
        Testpkg.Keep(o);
      }
    }
    runGC();
    for (int i = 0; i < 128; i++) {
      Testpkg.CallF(new CountI());
    }

    Testpkg.CallF(obj); // original object needs to work.

    assertEquals(countI, 1+24+128);
  }

  private void runGC() {
    System.gc();
    System.runFinalization();
    Testpkg.GC();
    System.gc();
    System.runFinalization();
  }

  public void testUnnamedParams() {
    final String msg = "1234567";
    assertEquals("want the length of \"1234567\" passed after unnamed params",
		    7, Testpkg.UnnamedParams(10, 20, msg));
  }

  public void testPointerToStructAsField() {
    Testpkg.Node a = Testpkg.NewNode("A");
    Testpkg.Node b = Testpkg.NewNode("B");
    a.setNext(b);
    String got = a.String();
    assertEquals("want Node A points to Node B", "A:B:<end>", got);
  }

  public void testImplementsInterface() {
    Testpkg.Interface intf = Testpkg.NewConcrete();
  }

  public void testErrorField() {
    final String want = "an error message";
    Testpkg.Node n = Testpkg.NewNode("ErrTest");
    n.setErr(want);
    String got = n.getErr();
    assertEquals("want back the error message we set", want, got);
  }

  //test if we have JNI local reference table overflow error
  public void testLocalReferenceOverflow() {
    Testpkg.CallWithCallback(new Testpkg.GoCallback() {

      @Override
      public void VarUpdate() {
        //do nothing
      }
    });
  }

  public void testNullReferences() {
    assertTrue(Testpkg.CallWithNull(null, new Testpkg.NullTest() {
      public Testpkg.NullTest Null() {
        return null;
      }
    }));
	assertEquals("Go nil interface is null", null, Testpkg.NewNullInterface());
	assertEquals("Go nil struct pointer is null", null, Testpkg.NewNullStruct());
  }

  public void testPassByteArray() {
    Testpkg.PassByteArray(new Testpkg.B() {
      @Override public void B(byte[] b) {
        byte[] want = new byte[]{1, 2, 3, 4};
        MoreAsserts.assertEquals("bytes should match", want, b);
      }
    });
  }

  public void testReader() {
    byte[] b = new byte[8];
    try {
      long n = Testpkg.ReadIntoByteArray(b);
      assertEquals("wrote to the entire byte array", b.length, n);
      byte[] want = new byte[b.length];
      for (int i = 0; i < want.length; i++)
        want[i] = (byte)i;
      MoreAsserts.assertEquals("bytes should match", want, b);
     } catch (Exception e) {
       fail("Failed to write: " + e.toString());
     }
  }

  public void testGoroutineCallback() {
    Testpkg.GoroutineCallback(new Testpkg.Receiver() {
      @Override public void Hello(String msg) {
      }
    });
  }

  public void testImportedPkg() {
    Testpkg.CallImportedI(new Secondpkg.I() {
      @Override public long F(long i) {
        return i;
      }
    });
    assertEquals("imported string should match", Secondpkg.HelloString, Secondpkg.Hello());
    Secondpkg.I i = Testpkg.NewImportedI();
    Secondpkg.S s = Testpkg.NewImportedS();
    i = Testpkg.getImportedVarI();
    s = Testpkg.getImportedVarS();
    assertEquals("numbers should match", 8, i.F(8));
    assertEquals("numbers should match", 8, s.F(8));
    Testpkg.setImportedVarI(i);
    Testpkg.setImportedVarS(s);
    Testpkg.ImportedFields fields = Testpkg.NewImportedFields();
    i = fields.getI();
    s = fields.getS();
    fields.setI(i);
    fields.setS(s);
    Testpkg.WithImportedI(i);
    Testpkg.WithImportedS(s);

    Secondpkg.IF f = new AnI();
    f = Testpkg.New();
    Secondpkg.Ser ser = Testpkg.NewSer();
  }

  public void testRoundtripEquality() {
    Testpkg.I want = new AnI();
    assertTrue("java object passed through Go should not be wrapped", want == Testpkg.IDup(want));
    Testpkg.InterfaceDupper idup = new Testpkg.InterfaceDupper(){
      @Override public Testpkg.Interface IDup(Testpkg.Interface i) {
        return i;
      }
    };
    assertTrue("Go interface passed through Java should not be wrapped", Testpkg.CallIDupper(idup));
    Testpkg.ConcreteDupper cdup = new Testpkg.ConcreteDupper(){
      @Override public Testpkg.Concrete CDup(Testpkg.Concrete c) {
        return c;
      }
    };
    assertTrue("Go struct passed through Java should not be wrapped", Testpkg.CallCDupper(cdup));
  }
}
