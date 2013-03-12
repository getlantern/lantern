package org.lantern;

import java.net.InetSocketAddress;

import org.lantern.util.LanternTrafficCounterHandler;
import org.littleshoot.util.FiveTuple;
import org.littleshoot.util.FiveTuple.Protocol;

public final class ProxyHolder {

    private final String id;
    private final FiveTuple isa;
    private final LanternTrafficCounterHandler trafficShapingHandler;

    public ProxyHolder(final String id, final InetSocketAddress isa, 
        final LanternTrafficCounterHandler trafficShapingHandler) {
        this.id = id;
        this.isa = new FiveTuple(null, isa, Protocol.TCP);
        this.trafficShapingHandler = trafficShapingHandler;
    }
    
    public ProxyHolder(final String id, final FiveTuple tuple, 
        final LanternTrafficCounterHandler trafficShapingHandler) {
        this.id = id;
        this.isa = tuple;
        this.trafficShapingHandler = trafficShapingHandler;
    }

    public String getId() {
        return id;
    }

    public FiveTuple getFiveTuple() {
        return isa;
    }
    
    public LanternTrafficCounterHandler getTrafficShapingHandler() {
        return trafficShapingHandler;
    }
    
    @Override
    public String toString() {
        return "ProxyHolder [isa=" + getFiveTuple() + "]";
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result + ((id == null) ? 0 : id.hashCode());
        result = prime * result + ((isa == null) ? 0 : isa.hashCode());
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
        ProxyHolder other = (ProxyHolder) obj;
        if (getId() == null) {
            if (other.id != null)
                return false;
        } else if (!id.equals(other.id))
            return false;
        if (isa == null) {
            if (other.isa != null)
                return false;
        } else if (!isa.equals(other.isa))
            return false;
        return true;
    }
}