package org.lantern;

import java.util.Map;

/**
 * Default implementation of the Lantern API.
 */
public class DefaultLanternApi implements LanternApi {

    @Override
    public void processCall(final Map<String, String> data) {
        final String id = data.get("id");
        final LanternApiCall call = LanternApiCall.valueOf(id.toUpperCase());
        switch (call) {
        case SIGNIN:
            LanternHub.xmppHandler().disconnect();
            final String email = data.get("email");
            final String pass = data.get("password");
            LanternHub.userInfo().setEmail(email);
            LanternHub.userInfo().setPassword(pass);
            LanternHub.xmppHandler().connect();
            break;
        case SIGNOUT:
            LanternHub.xmppHandler().disconnect();
            break;
        }
    }

}
