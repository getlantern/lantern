package org.lantern.network;

import java.net.InetSocketAddress;

/**
 * Encapsulates information about an instance on the Lantern network.
 * 
 * @param <I>
 *            Type of object identifying instances
 * @param <D>
 *            Type of object representing additional data stored in
 *            {@link InstanceInfo}s
 */
public class InstanceInfo<I, D> {
    protected final I id;
    protected final InetSocketAddress addressOnLan;
    protected final InetSocketAddress addressOnInternet;
    protected final D data;

    /**
     * @param id
     *            unique id for this instance
     * @param addressOnLan
     *            the instance's address on its own LAN
     * @param addressOnInternet
     *            the instance's address as seen on the internet
     * @param data
     */
    public InstanceInfo(I id,
            InetSocketAddress addressOnLan,
            InetSocketAddress addressOnInternet,
            D data) {
        super();
        this.id = id;
        this.addressOnLan = addressOnLan;
        this.addressOnInternet = addressOnInternet;
        this.data = data;
    }

    public InstanceInfo(I instanceId,
            InetSocketAddress addressOnLan,
            InetSocketAddress addressOnInternet) {
        this(instanceId, addressOnLan, addressOnInternet, null);
    }

    public I getId() {
        return id;
    }

    public InetSocketAddress getAddressOnLan() {
        return addressOnLan;
    }

    public InetSocketAddress getAddressOnInternet() {
        return addressOnInternet;
    }

    public D getData() {
        return data;
    }

    public boolean hasMappedEndpoint() {
        if (addressOnInternet == null) {
            return false;
        }
        return !addressOnInternet.isUnresolved()
                && addressOnInternet.getPort() > 1;
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime
                * result
                + ((addressOnInternet == null) ? 0 : addressOnInternet
                        .hashCode());
        result = prime * result
                + ((addressOnLan == null) ? 0 : addressOnLan.hashCode());
        result = prime * result
                + ((id == null) ? 0 : id.hashCode());
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
        InstanceInfo other = (InstanceInfo) obj;
        if (addressOnInternet == null) {
            if (other.addressOnInternet != null)
                return false;
        } else if (!addressOnInternet.equals(other.addressOnInternet))
            return false;
        if (addressOnLan == null) {
            if (other.addressOnLan != null)
                return false;
        } else if (!addressOnLan.equals(other.addressOnLan))
            return false;
        if (id == null) {
            if (other.id != null)
                return false;
        } else if (!id.equals(other.id))
            return false;
        return true;
    }

    @Override
    public String toString() {
        return "InstanceInfo [instanceId=" + id + ", addressOnLan="
                + addressOnLan + ", addressOnWan=" + addressOnInternet + "]";
    }

}