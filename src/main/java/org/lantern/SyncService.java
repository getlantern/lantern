package org.lantern;

import java.util.Map;

import org.cometd.bayeux.Message;
import org.cometd.bayeux.server.BayeuxServer;
import org.cometd.bayeux.server.ServerSession;
import org.cometd.server.AbstractService;
import org.eclipse.jetty.util.ajax.JSON;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Service for pushing updated Lantern state to the client.
 */
public class SyncService extends AbstractService {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    /**
     * Creates a new sync service.
     * 
     * @param bayeux The Bayeux server.
     */
    public SyncService(final BayeuxServer bayeux) {
        super(bayeux, "sync");
        addService("/service/sync", "processSync");
    }

    public void processSync(final ServerSession remote, final Message message) {
        final Map<String, Object> input = message.getDataAsMap();
        //final String name = (String) input.get("name");

        log.info("Pushing updated config to browser...");
        final String output = LanternHub.config().configAsJson();
        log.info("Config is: {}", output);
        remote.deliver(getServerSession(), "/sync", new JSON.Literal(output), null);
        
    }
}
