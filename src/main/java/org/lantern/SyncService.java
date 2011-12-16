package org.lantern;

import java.util.Map;
import java.util.HashMap;

import org.cometd.bayeux.Message;
import org.cometd.bayeux.server.BayeuxServer;
import org.cometd.bayeux.server.ServerSession;
import org.cometd.server.AbstractService;

/**
 * Service for pushing updated Lantern state to the client.
 */
public class SyncService extends AbstractService {
    
    public SyncService(final BayeuxServer bayeux) {
        super(bayeux, "sync");
        addService("/service/sync", "processSync");
    }

    public void processSync(final ServerSession remote, final Message message) {
        final Map<String, Object> input = message.getDataAsMap();
        final String name = (String) input.get("name");

        final Map<String, Object> output = new HashMap<String, Object>();
        output.put("greeting", "Hello, " + name);
        remote.deliver(getServerSession(), "/sync", output, null);
    }
}
