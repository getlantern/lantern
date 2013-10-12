package org.lantern.network;

import java.net.InetSocketAddress;

public class InstanceInfo<U, F, D> {
    private final InstanceId<U, F> instanceId;
    protected final InetSocketAddress addressOnLan;
    protected final InetSocketAddress addressOnWan;
    protected final D data;

    public InstanceInfo(InstanceId<U, F> instanceId,
            InetSocketAddress addressOnLan,
            InetSocketAddress addressOnWan,
            D data) {
        super();
        this.instanceId = instanceId;
        this.addressOnLan = addressOnLan;
        this.addressOnWan = addressOnWan;
        this.data = data;
    }

    public InstanceInfo(InstanceId<U, F> instanceId,
            InetSocketAddress addressOnLan,
            InetSocketAddress addressOnWan) {
        this(instanceId, addressOnLan, addressOnWan, null);
    }

    public InstanceId<U, F> getInstanceId() {
        return instanceId;
    }

    public InetSocketAddress getAddressOnLan() {
        return addressOnLan;
    }

    public InetSocketAddress getAddressOnWan() {
        return addressOnWan;
    }

    public D getData() {
        return data;
    }
}