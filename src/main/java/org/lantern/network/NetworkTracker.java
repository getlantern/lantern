package org.lantern.network;

import java.security.cert.Certificate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.jboss.netty.util.internal.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

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
 * @param <F>
 *            Type of object identifying full instance ids
 * @param <D>
 *            Type of object representing additional data stored in
 *            {@link InstanceInfo}s
 */
@Singleton
public class NetworkTracker<U, F, D> {
    private static final Logger LOG = LoggerFactory
            .getLogger(NetworkTracker.class);

    private final Map<U, Map<InstanceId<U, F>, Certificate>> receivedCertificates = new ConcurrentHashMap<U, Map<InstanceId<U, F>, Certificate>>();
    private final Map<U, Map<InstanceId<U, F>, InstanceInfo<U, F, D>>> onlineInstances = new ConcurrentHashMap<U, Map<InstanceId<U, F>, InstanceInfo<U, F, D>>>();
    private final Set<U> trustedUsers = Collections
            .synchronizedSet(new HashSet<U>());
    private final List<NetworkTrackerListener<U, F, D>> listeners = new ArrayList<NetworkTrackerListener<U, F, D>>();
    private Set<InstanceInfoWithCert<U, F, D>> trustedOnlineInstances = Collections
            .synchronizedSet(new HashSet<InstanceInfoWithCert<U, F, D>>());

    public void addListener(
            NetworkTrackerListener<U, F, D> listener) {
        this.listeners.add(listener);
    }

    /**
     * Tell the {@link NetworkTracker} that an instance went online.
     * 
     * @param instanceId
     * @param instanceInfo
     * @return true if NetworkTracker didn't already know that this instance is
     *         online.
     */
    public boolean instanceOnline(InstanceId<U, F> instanceId,
            InstanceInfo<U, F, D> instanceInfo) {
        LOG.debug("instanceOnline: {}", instanceInfo);
        boolean instanceIsNew = false;
        synchronized (onlineInstances) {
            U userId = instanceId.getUserId();
            Map<InstanceId<U, F>, InstanceInfo<U, F, D>> userInstances = onlineInstances
                    .get(userId);
            if (userInstances == null) {
                userInstances = new ConcurrentHashMap<InstanceId<U, F>, InstanceInfo<U, F, D>>();
                instanceIsNew = onlineInstances.put(userId, userInstances) == null;
            }
            userInstances.put(instanceId, instanceInfo);
        }
        reevaluateTrustedOnlineInstances();
        LOG.debug("New instance? {}", instanceIsNew);
        return instanceIsNew;
    }

    public void instanceOffline(InstanceId<U, F> instanceId) {
        LOG.debug("instanceOffline: {}", instanceId);
        synchronized (onlineInstances) {
            U userId = instanceId.getUserId();
            Map<InstanceId<U, F>, InstanceInfo<U, F, D>> userInstances = onlineInstances
                    .get(userId);
            if (userInstances != null) {
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

    public void certificateReceived(InstanceId<U, F> instanceId,
            Certificate certificate) {
        LOG.debug("certificateReceived: {} {}", instanceId, certificate);
        synchronized (receivedCertificates) {
            U userId = instanceId.getUserId();
            Map<InstanceId<U, F>, Certificate> userCerts = receivedCertificates
                    .get(userId);
            if (userCerts == null) {
                userCerts = new ConcurrentHashMap<InstanceId<U, F>, Certificate>();
                receivedCertificates.put(userId, userCerts);
            }
            userCerts.put(instanceId, certificate);
        }
        reevaluateTrustedOnlineInstances();
    }

    /**
     * Returns a list of all instances that are currently trusted, including
     * their certs.
     * 
     * @return
     */
    public Set<InstanceInfoWithCert<U, F, D>> getTrustedOnlineInstances() {
        return trustedOnlineInstances;
    }

    private void reevaluateTrustedOnlineInstances() {
        Set<InstanceInfoWithCert<U, F, D>> updatedTrustedOnlineInstances = calculateTrustedOnlineInstances();
        Set<InstanceInfoWithCert<U, F, D>> addedOnlineInstances = new HashSet<InstanceInfoWithCert<U, F, D>>(
                updatedTrustedOnlineInstances);
        Set<InstanceInfoWithCert<U, F, D>> removedOnlineInstances = new HashSet<InstanceInfoWithCert<U, F, D>>(
                trustedOnlineInstances);
        addedOnlineInstances.removeAll(trustedOnlineInstances);
        removedOnlineInstances.removeAll(updatedTrustedOnlineInstances);
        for (InstanceInfoWithCert<U, F, D> instance : addedOnlineInstances) {
            for (NetworkTrackerListener<U, F, D> listener : listeners) {
                LOG.debug("Online trusted instance added: {}", instance);
                listener.instanceOnlineAndTrusted(instance);
            }
        }
        for (InstanceInfoWithCert<U, F, D> instance : removedOnlineInstances) {
            for (NetworkTrackerListener<U, F, D> listener : listeners) {
                LOG.debug("Online trusted instance removed: {}", instance);
                listener.instanceOfflineOrUntrusted(instance);
            }
        }
        trustedOnlineInstances = updatedTrustedOnlineInstances;
        LOG.debug("Number of trusted online instances: {}",
                trustedOnlineInstances.size());
    }

    private Set<InstanceInfoWithCert<U, F, D>> calculateTrustedOnlineInstances() {
        Set<InstanceInfoWithCert<U, F, D>> result = Collections
                .synchronizedSet(new HashSet<InstanceInfoWithCert<U, F, D>>());
        for (Map.Entry<U, Map<InstanceId<U, F>, Certificate>> userCertsEntry : receivedCertificates
                .entrySet()) {
            U userId = userCertsEntry.getKey();
            if (trustedUsers.contains(userId)) {
                Map<InstanceId<U, F>, Certificate> userCerts = userCertsEntry
                        .getValue();
                if (userCerts != null) {
                    Map<InstanceId<U, F>, InstanceInfo<U, F, D>> userInstances = onlineInstances
                            .get(userId);
                    for (Map.Entry<InstanceId<U, F>, Certificate> certEntry : userCerts
                            .entrySet()) {
                        InstanceId<U, F> instanceId = certEntry.getKey();
                        if (userInstances != null) {
                            InstanceInfo<U, F, D> instanceInfo = userInstances
                                    .get(instanceId);
                            if (instanceInfo != null) {
                                Certificate certificate = certEntry.getValue();
                                result.add(new InstanceInfoWithCert<U, F, D>(
                                        instanceInfo,
                                        certificate));

                            }
                        }
                    }
                }
            }
        }
        return result;
    }
}
