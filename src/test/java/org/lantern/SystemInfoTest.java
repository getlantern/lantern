package org.lantern;

import static org.junit.Assert.*;

import org.junit.Test;
import org.littleshoot.util.NetworkUtils;


public class SystemInfoTest {

    @Test
    public void testSystemInfo() throws Exception {
        final SystemInfo si = new SystemInfo();
        final String json = LanternUtils.jsonify(si);
        System.out.println(json);
        assertTrue("Not found in\n"+json,
            json.contains(NetworkUtils.getLocalHost().getCanonicalHostName()));
    }
    
}
