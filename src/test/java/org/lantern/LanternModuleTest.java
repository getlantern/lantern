package org.lantern;

import static org.junit.Assert.*;

import org.junit.Test;
import org.lantern.http.JettyLauncher;
import org.lantern.state.Model;

import com.google.inject.Guice;
import com.google.inject.Injector;

public class LanternModuleTest {

    @Test
    public void test() {
        final Injector injector = Guice.createInjector(new LanternModule());
        
        final LanternService xmpp = 
            injector.getInstance(DefaultXmppHandler.class);
        
        final Model model = injector.getInstance(Model.class);
        assertNotNull(xmpp);
        assertNotNull(model);
        assertTrue(model == injector.getInstance(Model.class));
        
        
        final LanternService jetty = 
                injector.getInstance(JettyLauncher.class);
        assertNotNull(jetty);
    }

}
