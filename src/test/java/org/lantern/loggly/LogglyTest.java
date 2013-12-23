package org.lantern.loggly;

import java.util.Date;
import java.util.HashMap;
import java.util.Map;

import org.junit.Before;
import org.junit.Test;

public class LogglyTest {
    private Loggly loggly;

    @Before
    public void setUp() {
        loggly = new Loggly(true);
    }

    @Test
    public void testSendToLoggly() {
        LogglyMessage msg = new LogglyMessage("test-reporter", "test-message", new Date());
        Map<String, Object> extra = new HashMap<String, Object>();
        extra.put("int_key", 11);
        extra.put("str_key", "foo");
        msg.setExtra(extra);
        msg.setThrowable(new Exception("test-exception"));
        loggly.log(msg);
    }
}