package org.lantern;

import java.net.InetSocketAddress;

import org.lantern.util.LanternTrafficCounter;
import org.littleshoot.util.FiveTuple;
import org.littleshoot.util.FiveTuple.Protocol;

public final class ProxyHolder {

    private final String id;
    private final FiveTuple fiveTuple;
    private final LanternTrafficCounter trafficShapingHandler;

    public ProxyHolder(final String id, final InetSocketAddress isa, 
        final LanternTrafficCounter trafficShapingHandler) {
        this.id = id;
        this.fiveTuple = new FiveTuple(null, isa, Protocol.TCP);
        this.trafficShapingHandler = trafficShapingHandler;
    }
    
    public ProxyHolder(final String id, final FiveTuple tuple, 
        final LanternTrafficCounter trafficShapingHandler) {
        this.id = id;
        this.fiveTuple = tuple;
        this.trafficShapingHandler = trafficShapingHandler;
    }

    public String getId() {
        return id;
    }

    public FiveTuple getFiveTuple() {
        return fiveTuple;
    }
    
    public LanternTrafficCounter getTrafficShapingHandler() {
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
        result = prime * result + ((fiveTuple == null) ? 0 : fiveTuple.hashCode());
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
        if (fiveTuple == null) {
            if (other.fiveTuple != null)
                return false;
        } else if (!fiveTuple.equals(other.fiveTuple))
            return false;
        return true;
    }
}