package org.lantern.proxy;

import static org.lantern.state.PeerType.pc;
import static org.littleshoot.util.FiveTuple.Protocol.TCP;

import java.util.Comparator;

import org.lantern.state.PeerType;
import org.lantern.state.UDPProxyPriority;
import org.littleshoot.util.FiveTuple.Protocol;

/**
 * <p>
 * Prioritizes proxies based on the following rules (highest to lowest):
 * </p>
 * 
 * Note: this comparator imposes orderings that are inconsistent with equals,
 * in particular the weighted ordering of proxies with weights.
 * 
 * <ol>
 * <li>Prioritize other Lanterns over fallback proxies</li>
 * <li>Prioritize TCP over UDP</li>
 * <li>Probabilistically prioritize higher weighted proxies over lower weighted</li>
 * <li>Prioritize higher priority proxies over lower priority</li>
 * <li>Prioritize proxies to whom we have fewer open sockets</li>
 * </ol>
 */
class ProxyPrioritizer implements Comparator<ProxyHolder> {
    
    private final UDPProxyPriority udpPriority;

    /**
     * @param defaultProxyTracker
     */
    ProxyPrioritizer(final UDPProxyPriority udpPriority) {
        this.udpPriority = udpPriority;
    }

    @Override
    public int compare(final ProxyHolder a, final ProxyHolder b) {
     // Prioritize other Lanterns over fallback proxies
        PeerType typeA = a.getType();
        PeerType typeB = b.getType();
        if (typeA == pc && typeB != pc) {
            return -1;
        } else if (typeB == pc && typeA != pc) {
            return 1;
        }

        // Prioritize TCP over UDP
        int protocolPriority = 0;
        Protocol protocolA = a.getFiveTuple().getProtocol();
        Protocol protocolB = b.getFiveTuple().getProtocol();
        if (protocolA == TCP && protocolB != TCP) {
            protocolPriority = -1;
        } else if (protocolB == TCP && protocolA != TCP) {
            protocolPriority = 1;
        }
        // Adjust protocolPriority based on configured UDP proxy priority
        protocolPriority = this.udpPriority.adjustComparisonResult(protocolPriority);
        if (protocolPriority != 0) {
            return protocolPriority;
        }
        
        // Next prioritize based on weighting.
        if (a.getWeight() > 0 && b.getWeight() > 0) {
            final int total = a.getWeight() + b.getWeight();
            final double rand = Math.random() * total;
            if (rand < a.getWeight()) {
                return -1;
            } else {
                return 1;
            }
        }
        
        // Next prioritize based on relative priority, if different
        int priority = a.getPriority() - b.getPriority();
        if (priority != 0) {
            return priority;
        }

        // Lastly prioritize based on least number of open sockets
        long numberOfSocketsA = a.getPeer().getNSockets();
        long numberOfSocketsB = b.getPeer().getNSockets();
        if (numberOfSocketsA < numberOfSocketsB) {
            return -1;
        } else if (numberOfSocketsB > numberOfSocketsA) {
            return 1;
        } else {
            return 0;
        }
    }
}