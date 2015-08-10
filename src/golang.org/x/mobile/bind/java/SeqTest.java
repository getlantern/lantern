// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package go;

import android.util.Log;
import android.test.suitebuilder.annotation.Suppress;
import android.test.AndroidTestCase;
import android.test.MoreAsserts;
import java.util.Arrays;
import java.util.Random;

import go.testpkg.Testpkg;

public class SeqTest extends AndroidTestCase {
  public SeqTest() {
  }

  public void testAssets() {
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
    String want = "Hello, 世界";
    String got = Testpkg.StrDup(want);
    assertEquals("Strings should match", want, got);
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

  private class AnI extends Testpkg.I.Stub {
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
}
