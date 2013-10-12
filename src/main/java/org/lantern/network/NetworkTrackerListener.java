package org.lantern.network;

public interface NetworkTrackerListener<U, F, D> {
    void instanceOnlineAndTrusted(InstanceInfoWithCert<U, F, D> instance);

    void instanceOfflineOrUntrusted(InstanceInfoWithCert<U, F, D> instance);
}
