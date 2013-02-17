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
@SuiteClasses({ LanternUtilsTest.class, LanternTrustStoreTest.class })

/**
 * There seem to be several common problems with these tests. First, sometimes 
 * cipher suites are configured for p2p connections and not for general 
 * connections, and the p2p cipher suites typically won't work. 
 * 
 * Second, it is sometimes the case that keys are added to the wrong keystore
 * or are removed for some reason, causing unexpected behavior in subsequent 
 * tests.
 */
public class AllTrustStoreTests {

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
