package org.lantern.network;

import java.security.cert.Certificate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.jboss.netty.util.internal.ConcurrentHashMap;

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
 * </ul>
 */
@Singleton
public class NetworkTracker<U, F, D> {
    private Map<U, Map<InstanceId<U, F>, Certificate>> receivedCertificates = new ConcurrentHashMap<U, Map<InstanceId<U, F>, Certificate>>();
    private Map<U, Map<InstanceId<U, F>, InstanceInfo<U, F, D>>> onlineInstances = new ConcurrentHashMap<U, Map<InstanceId<U, F>, InstanceInfo<U, F, D>>>();
    private Set<U> trustedUsers = Collections
            .synchronizedSet(new HashSet<U>());
    private Set<InstanceInfoWithCert<U, F, D>> trustedOnlineInstances = Collections
            .synchronizedSet(new HashSet<InstanceInfoWithCert<U, F, D>>());
    private List<TrustedOnlineInstanceListener> trustedOnlineInstancesListeners = new ArrayList<TrustedOnlineInstanceListener>();

    public void addTrustedOnlineInstanceListener(
            TrustedOnlineInstanceListener listener) {
        this.trustedOnlineInstancesListeners.add(listener);
    }

    public void certificateReceived(InstanceId<U, F> instanceId,
            Certificate certificate) {
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

    public void instanceOnline(InstanceId<U, F> instanceId,
            InstanceInfo<U, F, D> instanceInfo) {
        synchronized (onlineInstances) {
            U userId = instanceId.getUserId();
            Map<InstanceId<U, F>, InstanceInfo<U, F, D>> userInstances = onlineInstances
                    .get(userId);
            if (userInstances == null) {
                userInstances = new ConcurrentHashMap<InstanceId<U, F>, InstanceInfo<U, F, D>>();
                onlineInstances.put(userId, userInstances);
            }
            userInstances.put(instanceId, instanceInfo);
        }
        reevaluateTrustedOnlineInstances();
    }

    public void instanceOffline(InstanceId<U, F> instanceId) {
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
        trustedUsers.add(userId);
        reevaluateTrustedOnlineInstances();
    }

    public void userUntrusted(U userId) {
        trustedUsers.remove(userId);
        reevaluateTrustedOnlineInstances();
    }

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
            for (TrustedOnlineInstanceListener listener : trustedOnlineInstancesListeners) {
                listener.instanceOnlineAndTrusted(instance);
            }
        }
        for (InstanceInfoWithCert<U, F, D> instance : removedOnlineInstances) {
            for (TrustedOnlineInstanceListener listener : trustedOnlineInstancesListeners) {
                listener.instanceOfflineOrUntrusted(instance);
            }
        }
        trustedOnlineInstances = updatedTrustedOnlineInstances;
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
