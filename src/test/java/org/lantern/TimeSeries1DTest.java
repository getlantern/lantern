package org.lantern;

import java.util.List; 
import java.util.LinkedList;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


public class TimeSeries1DTest {
    
    public TimeSeries1DTest() {}
    
    @Test
    public void testWindowAverage() {
        
        TimeSeries1D ts = new TimeSeries1D();
        
        for (int i = 1; i <= 100; i++) {
            ts.addData(i, i);
        }
        
        assertTrue(ts.windowAverage(10,10) == 10);
        assertTrue(ts.windowAverage(10,11) == 10.5);
        
        // (10*11/2)/10
        assertTrue(ts.windowAverage(1,10) == 5.5);
        // (100*101/2)/100
        assertTrue(ts.windowAverage(1,100) == 50.5);
    }
    
    @Test
    public void testBucketing() {
        TimeSeries1D ts = new TimeSeries1D(10);
        for (int i = 1; i <= 100; i++) {
            ts.addData(i, i);
        }

        // over the whole range it should be the 
        // sum of all the data divided by the 
        // number of buckets
        // (100*101/2)/11
        assertTrue(ts.windowAverage(1,100) - 459.09 < 0.001);

        // first bucket will get 0-9, anything in 
        // that range will just be the first bucket's
        // value (9*10/2)
        assertTrue(ts.windowAverage(0,9) == 45);
        assertTrue(ts.windowAverage(1,9) == 45);
        assertTrue(ts.windowAverage(1,1) == 45);
        assertTrue(ts.windowAverage(9,9) == 45);
        
        // the second bucket will get 10-19
        assertTrue(ts.windowAverage(10,19) == 145);
        assertTrue(ts.windowAverage(10,10) == 145);
        assertTrue(ts.windowAverage(10,19) == 145);
        
        // if bucket lines are crossed, then it should
        // be the average per bucket.
        // 45+145/2
        assertTrue(ts.windowAverage(0,19) == 95);
    
    
    }
    
    @Test
    public void testAgeLimit() {
        // construct a time series with max age 5ms
        TimeSeries1D ts = new TimeSeries1D(1, 5);
        
        // add in a bunch of data
        for (int i = 1; i <= 100; i++) {
            ts.addData(i, i);
        }
        
        // everything older than 5 is gone...
        for (int i = 0; i < 95; i++) {
            assertTrue(ts.windowAverage(i,i) == 0);
        }
        // everything else is still there
        for (int i = 95; i <= 100; i++) {
            assertTrue(ts.windowAverage(i,i) == i);
        }
    }
    
    @Test
    public void testAgeLimitAndBuckets() {
        // construct a time series with max age 5ms
        // and bucket size 3
        TimeSeries1D ts = new TimeSeries1D(3, 5);
        
        // add in a bunch of data
        for (int i = 1; i <= 100; i++) {
            ts.addData(i, i);
        }
        
        // The age limit is 5, so this will discard
        // buckets up to the bucket containing 95 
        // which actually begins with 93
        for (int i = 0; i < 93; i++) {
            assertTrue(ts.windowAverage(i,i) == 0);
        }
        // everything else is still there
        for (int i = 93; i <= 100; i++) {
            assertTrue(ts.windowAverage(i,i) > 0);
        }
        
    }
    
    @Test
    public void testAccumulation() {
        TimeSeries1D ts = new TimeSeries1D();
        // add in a bunch of data
        for (int i = 1; i <= 100; i++) {
            for (int j = 1; j <= 100; j++) {
                ts.addData(i, j);
            }
        }
        
        for (int i = 1; i <= 100; i++) {
            assertTrue(ts.windowAverage(i,i) == 5050);
        }
    }
    
    @Test
    public void testConcurrent() throws Exception {
        
        final TimeSeries1D ts = new TimeSeries1D(100);
        
        class TestThread extends Thread {
            public void run() {
                for (int i = 0; i < 5000; i++) {
                    ts.addData(i, 1);
                }
            }
        }
        
        List<TestThread> allThreads = new LinkedList<TestThread>();
        for (int i = 0 ; i < 200; i++) {
            allThreads.add(new TestThread());
        }
        for (TestThread t : allThreads) {
            t.start();
        }
        for (TestThread t : allThreads) {
            t.join();
        }
        
        for (int i = 0; i < 5000; i++) {
            assertTrue(ts.windowAverage(i,i) == 100*200);
        }
    }
    
}