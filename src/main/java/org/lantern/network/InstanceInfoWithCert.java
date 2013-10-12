package org.lantern.network;

import java.security.cert.Certificate;

public class InstanceInfoWithCert<U, F, D> extends InstanceInfo<U, F, D> {
    private Certificate certificate;

    public InstanceInfoWithCert(InstanceInfo<U, F, D> instanceInfo,
            Certificate certificate) {
        super(instanceInfo.getInstanceId(),
                instanceInfo.getAddressOnLan(),
                instanceInfo.getAddressOnWan(),
                instanceInfo.getData());
        this.certificate = certificate;
    }

    public Certificate getCertificate() {
        return certificate;
    }

    public boolean hasMappedEndpoint() {
        return !addressOnWan.isUnresolved() && addressOnWan.getPort() > 1;
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result
                + ((addressOnLan == null) ? 0 : addressOnLan.hashCode());
        result = prime * result
                + ((addressOnWan == null) ? 0 : addressOnWan.hashCode());
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
        if (addressOnWan == null) {
            if (other.addressOnWan != null)
                return false;
        } else if (!addressOnWan.equals(other.addressOnWan))
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
                + ", addressOnWan=" + addressOnWan + "]";
    }

}