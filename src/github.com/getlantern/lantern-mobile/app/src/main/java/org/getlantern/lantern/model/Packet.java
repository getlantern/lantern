package org.getlantern.lantern.model;

/**
 * Created by todd on 8/16/15.
 */
public class Packet {
    private String destination;
    private long port;

    public void setPort(long port) {
        this.port  = port;
    }
    public long getPort() {
        return port;
    }

    public void setDestination(String destination) {
        this.destination = destination;
    }
    public String getDestination() {
        return destination;
    }

    /* private void passTcp(final LanternCustomVpn service, String destination,
                         long port,
                         final ByteBuffer packet,
                         OutputStream outputStream) throws Exception  {
        Socket sock = new Socket();
        sock.setTcpNoDelay(true);
        sock.setKeepAlive(true);
        if (service.protect(sock)) {
            try {
                sock.connect(new InetSocketAddress(destination, (int) port));
                ParcelFileDescriptor fd = ParcelFileDescriptor.fromSocket(sock);
                OutputStream outBuffer = sock.getOutputStream();
                outBuffer.write(packet.array());
                outBuffer.flush();
                outBuffer.close();
                packet.clear();
                if (sock.isConnected()) {
                    Log.d(TAG, "Socket is connected...");
                    InputStream inBuffer = sock.getInputStream();
                    byte[] bufferOutput = new byte[32767];
                    inBuffer.read(bufferOutput);
                    if (bufferOutput.length > 0) {
                        String recPacketString = new String(bufferOutput, 0, bufferOutput.length, "UTF-8");
                        Log.d(TAG, "recPacketString : " + recPacketString);
                        outputStream.write(bufferOutput);
                        fd.close();
                    }
                    inBuffer.close();
                }
            } catch (Exception e) {
                Log.e(TAG, "Could not send message " + e);
                sock.close();
            } finally {
                outputStream.flush();
            }
        }
    }

    private void passUdp(final LanternCustomVpn service, String destination,
                         long port,
                         final ByteBuffer packet) throws Exception {
        DatagramSocket sock = new DatagramSocket();
        if (service.protect(sock)) {
            Log.d(TAG, "Sending UDP packet");
            sock.connect((new InetSocketAddress(destination, (int)port)));
            ParcelFileDescriptor fd = ParcelFileDescriptor.fromDatagramSocket(sock);
            sock.send(new DatagramPacket(packet.array(), packet.array().length));
            sock.disconnect();
            packet.clear();
        }
    }*/
}
