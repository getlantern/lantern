package org.lantern;

import static org.junit.Assert.*;

import org.junit.Test;
import org.lantern.state.JsonModelModifier;
import org.lantern.state.Model;
import org.lantern.state.ModelService;
import org.lantern.state.Settings;

public class JsonModelModifierTest {

    @Test
    public void test() {
        final ModelService mm = TestUtils.getModelService();
        final JsonModelModifier mod = new JsonModelModifier(mm);
        
        final Model model = TestUtils.getModel();
        
        assertFalse(model.isLaunchd());
        //String json = "{\"path\":\"launchd\",\"value\":true}";
        //mod.applyJson(json);
        //assertTrue("Model modifier didn't modify!", model.isLaunchd());

        // Now test nested properties.
        final Settings set = model.getSettings();
        set.setSystemProxy(true);
        assertTrue(set.isSystemProxy());
        
        String json = "{\"path\":\"settings.systemProxy\",\"value\":false}";
        mod.applyJson(json);
        assertFalse("Model modifier didn't modify!", set.isSystemProxy());
    }

}
