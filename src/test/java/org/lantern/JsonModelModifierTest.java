package org.lantern;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;
import org.lantern.state.DefaultModelService;
import org.lantern.state.JsonModelModifier;
import org.lantern.state.Model;
import org.lantern.state.ModelService;
import org.lantern.state.Settings;

import static org.mockito.Mockito.mock;

public class JsonModelModifierTest {

    @Test
    public void test() {
        
        final Model model = TestingUtils.newModel();
        
        final ProxyService proxifier = mock(ProxyService.class);
        
        final ModelService mm = new DefaultModelService(model, proxifier);
        final JsonModelModifier mod = new JsonModelModifier(mm);

        assertFalse(model.isLaunchd());
        //String json = "{\"path\":\"launchd\",\"value\":true}";
        //mod.applyJson(json);
        //assertTrue("Model modifier didn't modify!", model.isLaunchd());

        // Now test nested properties.
        final Settings set = model.getSettings();
        set.setSystemProxy(true);
        assertTrue(set.isSystemProxy());

        String json = "{\"path\":\"settings/systemProxy\",\"value\":false}";
        mod.applyJson(json);
        assertFalse("Model modifier didn't modify!", set.isSystemProxy());
    }

}
