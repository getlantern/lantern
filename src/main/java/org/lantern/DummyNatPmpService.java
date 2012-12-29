package org.lantern;

import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;

public class DummyNatPmpService implements NatPmpService {

    @Override
    public int addNatPmpMapping(PortMappingProtocol protocol, int localPort,
            int externalPortRequested, PortMapListener portMapListener) {
        return -1;
    }

    @Override
    public void removeNatPmpMapping(int mappingIndex) {
    }

    @Override
    public void shutdown() {
    }

}
