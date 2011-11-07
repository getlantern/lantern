package org.lantern;

import static org.junit.Assert.assertTrue;

import org.apache.commons.lang.StringUtils;
import org.junit.Test;


public class I18Test {

    @Test 
    public void testI18n() throws Exception {
        final String val = 
            I18n.tr("Are you sure you want to ignore the update?");
        assertTrue(StringUtils.isNotBlank(val));
    }
}
