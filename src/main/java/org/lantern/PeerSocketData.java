package org.lantern;

public interface PeerSocketData {

    long getBpsUp();
    long getBpsDn();
    long getBpsTotal();
    long getBytesUp();
    long getBytesDn();
    long getBytesTotal();
}
