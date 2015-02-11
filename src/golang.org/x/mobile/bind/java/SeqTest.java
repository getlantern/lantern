package go;

import android.test.suitebuilder.annotation.Suppress;
import android.test.MoreAsserts;
import java.util.Arrays;
import java.util.Random;

import go.testpkg.Testpkg;

import junit.framework.TestCase;

public class SeqTest extends TestCase {
  static {
    Go.init(null);
  }

  public void testAdd() {
    long res = Testpkg.Add(3, 4);
    assertEquals("Unexpected arithmetic failure", 7, res);
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

  boolean finalizedAnI;

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

    @Override
    public void finalize() throws Throwable {
      finalizedAnI = true;
      super.finalize();
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
  }

  public void testInterfaceMethodReturnsStructPointer() {
    final AnI obj = new AnI();
    Testpkg.S s = Testpkg.CallS(obj);
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

  /* Suppress this test for now; it's flaky or broken. */
  @Suppress
  public void testJavaRefGC() {
    finalizedAnI = false;
    AnI obj = new AnI();
    runGC();
    Testpkg.CallF(obj);
    assertTrue("want F to be called", obj.calledF);
    obj = null;
    runGC();
    assertTrue("want obj to be collected", finalizedAnI);
  }

  public void testJavaRefKeep() {
    finalizedAnI = false;
    AnI obj = new AnI();
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
}
