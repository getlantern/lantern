package org.lantern.network;

import java.security.cert.Certificate;

/**
 * An {@link InstanceInfo} that also includes the {@link Certificate} by which
 * this instance is trusted.
 * 
 * @param <U>
 *            Type of object identifying users
 * @param <F>
 *            Type of object identifying full instance ids
 * @param <D>
 *            Type of object representing additional data stored in
 *            {@link InstanceInfo}s
 */
public class InstanceInfoWithCert<U, F, D> extends InstanceInfo<U, F, D> {
    private Certificate certificate;

    public InstanceInfoWithCert(InstanceInfo<U, F, D> instanceInfo,
            Certificate certificate) {
        super(instanceInfo.getInstanceId(),
                instanceInfo.getAddressOnLan(),
                instanceInfo.getAddressOnInternet(),
                instanceInfo.getData());
        this.certificate = certificate;
    }

    public Certificate getCertificate() {
        return certificate;
    }

    public boolean hasMappedEndpoint() {
        return !addressOnInternet.isUnresolved()
                && addressOnInternet.getPort() > 1;
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result
                + ((addressOnLan == null) ? 0 : addressOnLan.hashCode());
        result = prime
                * result
                + ((addressOnInternet == null) ? 0 : addressOnInternet
                        .hashCode());
        result = prime * result
                + ((certificate == null) ? 0 : certificate.hashCode());
        return result;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj)
            return true;
        if (obj == null)
            return false;
        if (getClass() != obj.getClass())
            return false;
        InstanceInfoWithCert<?, ?, ?> other = (InstanceInfoWithCert<?, ?, ?>) obj;
        if (addressOnLan == null) {
            if (other.addressOnLan != null)
                return false;
        } else if (!addressOnLan.equals(other.addressOnLan))
            return false;
        if (addressOnInternet == null) {
            if (other.addressOnInternet != null)
                return false;
        } else if (!addressOnInternet.equals(other.addressOnInternet))
            return false;
        if (certificate == null) {
            if (other.certificate != null)
                return false;
        } else if (!certificate.equals(other.certificate))
            return false;
        return true;
    }

    @Override
    public String toString() {
        return "InstanceInfoWithCert [addressOnLan=" + addressOnLan
                + ", addressOnWan=" + addressOnInternet + "]";
    }

}