package org.lantern.network;

import java.security.cert.Certificate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.jboss.netty.util.internal.ConcurrentHashMap;
import org.lantern.event.ResetEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Singleton;

/**
 * <p>
 * This singleton is responsible for tracking information about the physical
 * Lantern network as well as the trust network that's used to build it.
 * </p>
 * 
 * <p>
 * Core Concepts:
 * </p>
 * 
 * <ul>
 * <li>instanceId: Identifies a Lantern instance in some consistent and unique
 * way. In practice, this is currently the Jabber ID.</li>
 * <li>Instance online/offline: we're told of this as we learn about instances
 * being online or offline (e.g. via KScope ad)</li>
 * <li>User trusted/untrusted: we're told of this as the friends list changes</li>
 * <li>Certificate received: we're told of this as certificates are received</li>
 * </ul>
 * 
 * @param <U>
 *            Type of object identifying users
 * @param <I>
 *            Type of object identifying instances
 * @param <D>
 *            Type of object representing additional data stored in
 *            {@link InstanceInfo}s
 */
@Singleton
public class NetworkTracker<U, I, D> {
    private static final Logger LOG = LoggerFactory
            .getLogger(NetworkTracker.class);

    private final Map<I, Certificate> trustedCertificatesByInstance = new ConcurrentHashMap<I, Certificate>();
    private final Map<U, Map<I, InstanceInfo<I, D>>> onlineInstancesByAdvertisingUser = new ConcurrentHashMap<U, Map<I, InstanceInfo<I, D>>>();
    private final Set<U> trustedUsers = Collections
            .synchronizedSet(new HashSet<U>());
    private final List<NetworkTrackerListener<I, D>> listeners = new ArrayList<NetworkTrackerListener<I, D>>();
    private volatile Set<InstanceInfo<I, D>> trustedOnlineInstances;

    public NetworkTracker() {
        identifyTrustedOnlineInstances();
    }

    /**
     * Add a {@link NetworkTrackerListener} to listen for events from this
     * tracker.
     * 
     * @param listener
     */
    public void addListener(
            NetworkTrackerListener<I, D> listener) {
        this.listeners.add(listener);
    }

    /**
     * Tell the {@link NetworkTracker} that an instance went online.
     * 
     * @param advertisingUser
     *            the user who told us this instance is online
     * @param instanceId
     * @param instanceInfo
     * @return true if NetworkTracker didn't already know that this instance is
     *         online.
     */
    public boolean instanceOnline(U advertisingUser,
            I instanceId,
            InstanceInfo<I, D> instanceInfo) {
        LOG.debug("instanceOnline: {}", instanceInfo);
        boolean instanceIsNew = false;
        synchronized (onlineInstancesByAdvertisingUser) {
            Map<I, InstanceInfo<I, D>> userInstances = onlineInstancesByAdvertisingUser
                    .get(advertisingUser);
            if (userInstances == null) {
                userInstances = new ConcurrentHashMap<I, InstanceInfo<I, D>>();
                instanceIsNew = onlineInstancesByAdvertisingUser.put(
                        advertisingUser,
                        userInstances) == null;
            }
            userInstances.put(instanceId, instanceInfo);
        }
        reevaluateTrustedOnlineInstances();
        LOG.debug("New instance? {}", instanceIsNew);
        return instanceIsNew;
    }

    public void instanceOffline(U advertisingUser, I instanceId) {
        LOG.debug("instanceOffline: {}", instanceId);
        synchronized (onlineInstancesByAdvertisingUser) {
            Map<I, InstanceInfo<I, D>> userInstances = onlineInstancesByAdvertisingUser
                    .get(advertisingUser);
            if (userInstances != null) {
                LOG.debug("removing online instance: {}", instanceId);
                userInstances.remove(instanceId);
            }
        }
        reevaluateTrustedOnlineInstances();
    }

    public void userTrusted(U userId) {
        LOG.debug("userTrusted: {}", userId);
        trustedUsers.add(userId);
        reevaluateTrustedOnlineInstances();
    }

    public void userUntrusted(U userId) {
        LOG.debug("userUntrusted: {}", userId);
        trustedUsers.remove(userId);
        reevaluateTrustedOnlineInstances();
    }

    public void certificateTrusted(I instanceId,
            Certificate certificate) {
        LOG.debug("certificateReceived: {} {}", instanceId, certificate);
        trustedCertificatesByInstance.put(instanceId, certificate);
        reevaluateTrustedOnlineInstances();
    }

    /**
     * Returns a list of all instances that are currently trusted, including
     * their certificates.
     * 
     * @return
     */
    public Set<InstanceInfo<I, D>> getTrustedOnlineInstances() {
        return trustedOnlineInstances;
    }

    /**
     * Re-evalute which certificates and instances are trusted and notify
     * listeners.
     */
    private void reevaluateTrustedOnlineInstances() {
        Set<InstanceInfo<I, D>> originalTrustedOnlineInstances = trustedOnlineInstances;
        identifyTrustedOnlineInstances();
        notifyListenersAboutInstances(originalTrustedOnlineInstances);
    }

    private void notifyListenersAboutInstances(
            Set<InstanceInfo<I, D>> originalTrustedOnlineInstances) {
        Set<InstanceInfo<I, D>> addedOnlineInstances = new HashSet<InstanceInfo<I, D>>(
                trustedOnlineInstances);
        Set<InstanceInfo<I, D>> removedOnlineInstances = new HashSet<InstanceInfo<I, D>>(
                originalTrustedOnlineInstances);
        addedOnlineInstances.removeAll(originalTrustedOnlineInstances);
        removedOnlineInstances.removeAll(trustedOnlineInstances);
        for (InstanceInfo<I, D> instance : addedOnlineInstances) {
            LOG.debug("Online trusted instance added: {}", instance);
            for (NetworkTrackerListener<I, D> listener : listeners) {
                listener.instanceOnlineAndTrusted(instance);
            }
        }
        for (InstanceInfo<I, D> instance : removedOnlineInstances) {
            LOG.debug("Online trusted instance removed: {}", instance);
            for (NetworkTrackerListener<I, D> listener : listeners) {
                listener.instanceOfflineOrUntrusted(instance);
            }
        }
    }

    /**
     * <p>
     * Determines all trusted online instances.
     * </p>
     * 
     * <p>
     * Note - yes this is expensive, but we don't expect it to be on any
     * performance critical paths so it's not worth worrying about right now.
     * </p>
     * 
     * @return
     */
    private void identifyTrustedOnlineInstances() {
        Set<InstanceInfo<I, D>> currentTrustedOnlineInstances = Collections
                .synchronizedSet(new HashSet<InstanceInfo<I, D>>());

        for (Map.Entry<U, Map<I, InstanceInfo<I, D>>> userInstancesEntry : onlineInstancesByAdvertisingUser
                .entrySet()) {
            U userId = userInstancesEntry.getKey();
            if (trustedUsers.contains(userId)) {
                Map<I, InstanceInfo<I, D>> instances = userInstancesEntry
                        .getValue();
                for (InstanceInfo<I, D> instance : instances.values()) {
                    I instanceId = instance.getId();
                    if (trustedCertificatesByInstance.containsKey(instanceId)) {
                        currentTrustedOnlineInstances.add(instance);
                    }
                }
            }
        }

        this.trustedOnlineInstances = currentTrustedOnlineInstances;
        LOG.debug("Number of trusted online instances: {}",
                trustedOnlineInstances.size());
    }
    
    @SuppressWarnings("unused")
    @Subscribe
    public void onReset(final ResetEvent event) {
        this.onlineInstancesByAdvertisingUser.clear();
        this.trustedCertificatesByInstance.clear();
        this.trustedOnlineInstances.clear();
        this.trustedUsers.clear();
    }
}
