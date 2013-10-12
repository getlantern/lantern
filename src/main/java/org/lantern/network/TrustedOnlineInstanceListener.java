package org.lantern.network;

public interface TrustedOnlineInstanceListener<U, F, D> {
    void instanceOnlineAndTrusted(InstanceInfoWithCert<U, F, D> instance);

    void instanceOfflineOrUntrusted(InstanceInfoWithCert<U, F, D> instance);
}
