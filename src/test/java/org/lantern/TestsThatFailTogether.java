package org.lantern;

import org.junit.AfterClass;
import org.junit.BeforeClass;
import org.junit.experimental.categories.Categories;
import org.junit.runner.RunWith;
import org.junit.runners.Suite.SuiteClasses;

@RunWith(Categories.class)
//@Categories.IncludeCategory(TrustStoreTests.class)
//@SuiteClasses({
//  AllTests.class,
//})
@SuiteClasses({ DefaultXmppHandlerTest.class, FallbackProxyTest.class})

/**
 * This is a catch all test suite just for running tests that happen to fail
 * when run together even though they succeed individually. It's for debugging
 * those tests.
 * 
 * This tends to happen when one test corrupts the other test in some way,
 * typically through setting global static variables.
 */
public class TestsThatFailTogether {

    @BeforeClass 
    public static void setUpClass() {  
        System.setProperty("javax.net.debug", "ssl");
        System.out.println("Master setup");
    }

    @AfterClass 
    public static void tearDownClass() { 
        System.out.println("Master tearDown");
    }
}
