package org.lantern;

import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;

import com.google.inject.Singleton;

/**
 * Does nothing -- all port mapping is now in flashlight.
 */
@Singleton
public class NatPmpImpl implements NatPmpService {

    @Override
    public int addNatPmpMapping(PortMappingProtocol protocol, int localPort,
            int externalPortRequested, PortMapListener portMapListener) {
        portMapListener.onPortMapError();
        return -1;
    }

    @Override
    public void removeNatPmpMapping(int mappingIndex) {}

    @Override
    public void shutdown() {}

}
