package org.lantern.network;

import java.net.InetSocketAddress;

/**
 * Encapsulates information about an instance on the Lantern network.
 * 
 * @param <U>
 *            Type of object identifying users
 * @param <F>
 *            Type of object identifying full instance ids
 * @param <D>
 *            Type of object representing additional data stored in
 *            {@link InstanceInfo}s
 */
public class InstanceInfo<U, F, D> {
    private final InstanceId<U, F> instanceId;
    protected final InetSocketAddress addressOnLan;
    protected final InetSocketAddress addressOnInternet;
    protected final D data;

    /**
     * 
     * @param instanceId unique id for this instance
     * @param addressOnLan the instance's address on its own LAN
     * @param addressOnInternet the instance's address as seen on the internet
     * @param data
     */
    public InstanceInfo(InstanceId<U, F> instanceId,
            InetSocketAddress addressOnLan,
            InetSocketAddress addressOnInternet,
            D data) {
        super();
        this.instanceId = instanceId;
        this.addressOnLan = addressOnLan;
        this.addressOnInternet = addressOnInternet;
        this.data = data;
    }

    public InstanceInfo(InstanceId<U, F> instanceId,
            InetSocketAddress addressOnLan,
            InetSocketAddress addressOnInternet) {
        this(instanceId, addressOnLan, addressOnInternet, null);
    }

    public InstanceId<U, F> getInstanceId() {
        return instanceId;
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

    @Override
    public String toString() {
        return "InstanceInfo [instanceId=" + instanceId + ", addressOnLan="
                + addressOnLan + ", addressOnWan=" + addressOnInternet + "]";
    }

}