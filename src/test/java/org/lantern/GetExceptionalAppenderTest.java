package org.lantern;

import org.apache.log4j.Category;
import org.apache.log4j.Level;
import org.apache.log4j.Logger;
import org.apache.log4j.Priority;
import org.apache.log4j.spi.LoggingEvent;
import org.junit.Test;
import org.lantern.getexceptional.GetExceptionalAppender;


public class GetExceptionalAppenderTest {

    @Test public void testGetExceptionalAppender() {
        final GetExceptionalAppender appender = 
            new GetExceptionalAppender("", false);
        final String fqnOfCategoryClass = getClass().getName();
        final Category logger = Logger.getLogger(getClass());
        final Priority level = Level.ERROR;
        final Object message = "big bad error";
        final Throwable throwable = new RuntimeException();
        final LoggingEvent le = 
            new LoggingEvent(fqnOfCategoryClass, logger, level, message, throwable);
        appender.append(le);
    }
}
