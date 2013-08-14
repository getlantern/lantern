package org.lantern.updater;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.Map;

import org.lantern.LanternConstants;
import org.lantern.LanternUtils;
import org.lantern.event.Events;
import org.lantern.event.UpdateEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Connects the update event to the updater. As a fallback proxy, automatically
 * quits after an update, so that the new version will get run.
 */

@Singleton
public class UpdateListener {
    private final Logger log = LoggerFactory.getLogger(getClass());

    private final Updater updater;

    @Inject
    public UpdateListener(Updater updater) {
        this.updater = updater;
        Events.register(this);
    }

    @Subscribe
    public void onUpdate(UpdateEvent e) {
        Map<String, Object> data = e.getData();
        String url = (String) data.get(LanternConstants.UPDATE_URL_KEY);
        try {
            log.info("Downloading updater lantern jar from " + url);
            updater.update(new URI(url));
        } catch (URISyntaxException e1) {
            log.warn("Bogus update URL: " + url, e);
        }
    }

    @Subscribe
    public void onUpdateSucceeded(UpdateSucceededEvent e) {

        if (LanternUtils.isFallbackProxy()) {
            System.exit(0);
        }

    }

}
