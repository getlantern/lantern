package org.lantern.pubsub;

import java.io.BufferedOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.nio.charset.Charset;
import java.security.KeyStore;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.Collections;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManagerFactory;

import org.msgpack.core.MessageFormat;
import org.msgpack.core.MessagePack;
import org.msgpack.core.MessagePacker;
import org.msgpack.core.MessageUnpacker;

/**
 * A client for Lantern's pubsub infrastructure.
 */
public class Client implements Runnable {
    private static final Charset UTF8 = Charset.forName("UTF-8");

    private static final Runnable NOOP = new Runnable() {
        public void run() {
        };
    };

    private final ClientConfig cfg;
    private final LinkedBlockingQueue<Runnable> outQueue =
            new LinkedBlockingQueue<Runnable>(1);
    private final LinkedBlockingQueue<Message> in =
            new LinkedBlockingQueue<Message>(1);
    private final ScheduledExecutorService scheduledExecutor = Executors
            .newSingleThreadScheduledExecutor();
    private final Set<ByteBuffer> subscriptions = Collections
            .newSetFromMap(new ConcurrentHashMap<ByteBuffer, Boolean>());

    private volatile Socket socket;
    private volatile MessagePacker packer;
    private volatile ScheduledFuture<?> nextKeepalive;
    private final AtomicBoolean forceReconnect = new AtomicBoolean();

    public static class ClientConfig {
        private final String host;
        private final int port;
        public String authenticationKey;
        public long backoffBase;
        public long maxBackoff;
        public long keepalivePeriod;

        public ClientConfig(String host, int port) {
            this.host = host;
            this.port = port;
        }

        private Socket dial() throws IOException {
            return sslContext.getSocketFactory().createSocket(host, port);
        }
    }

    public Client(ClientConfig cfg) {
        // Apply sensible defaults
        if (cfg.backoffBase == 0) {
            cfg.backoffBase = 1000; // 1 second
        }
        if (cfg.maxBackoff == 0) {
            cfg.maxBackoff = 60 * 1000; // 1 minute
        }
        if (cfg.keepalivePeriod == 0) {
            cfg.keepalivePeriod = 20 * 1000; // 20 seconds
        }

        this.cfg = cfg;
        Thread thread = new Thread(this, "Client");
        thread.setDaemon(true);
        thread.start();
    }

    public static byte[] utf8(String str) {
        return str == null ? null : str.getBytes(UTF8);
    }

    public static String fromUTF8(byte[] bytes) {
        return bytes == null ? null : new String(bytes, UTF8);
    }

    public Message read() throws InterruptedException {
        return in.take();
    }

    public Message readTimeout(long timeout, TimeUnit unit)
            throws InterruptedException {
        return in.poll(timeout, unit);
    }

    public void subscribe(byte[] topic) throws InterruptedException {
        subscriptions.add(ByteBuffer.wrap(topic));
        new Sendable(this, new Message(Type.Subscribe, topic, null)).send();
    }

    public void unsubscribe(byte[] topic) throws InterruptedException {
        subscriptions.remove(ByteBuffer.wrap(topic));
        new Sendable(this, new Message(Type.Unsubscribe, topic, null)).send();
    }

    public void publish(byte[] topic, byte[] body) throws InterruptedException {
        new Sendable(this, new Message(Type.Publish, topic, body)).send();
    }

    public void run() {
        forceConnect();
        try {
            process();
        } catch (InterruptedException ie) {
            throw new RuntimeException("Interrupted while processing", ie);
        }
    }

    private void process() throws InterruptedException {
        while (true) {
            doWithConnection(outQueue.take());
        }
    }

    private void doWithConnection(Runnable op) throws InterruptedException {
        for (int numFailures = 0; numFailures < Integer.MAX_VALUE; numFailures++) {
            // Back off if necessary
            if (numFailures > 0) {
                long backoff = (long) (Math.pow(cfg.backoffBase, numFailures));
                backoff = Math.min(backoff, cfg.maxBackoff);
                Thread.sleep(backoff);
            }

            boolean force = forceReconnect.compareAndSet(true, false);
            boolean socketNull = socket == null;
            if (force || socketNull) {
                close();

                // Dial
                try {
                    // Dial
                    socket = cfg.dial();
                    packer = MessagePack
                            .newDefaultPacker(new BufferedOutputStream(socket
                                    .getOutputStream()));

                    sendInitialMessages();

                    final InputStream in = socket.getInputStream();
                    // Start read loop
                    Thread thread = new Thread(new Runnable() {
                        @Override
                        public void run() {
                            readLoop(MessagePack.newDefaultUnpacker(in));
                        }
                    }, "Client-ReadLoop");
                    thread.setDaemon(true);
                    thread.start();

                    // Success
                    return;
                } catch (Exception e) {
                    e.printStackTrace();
                    close();
                    continue;
                }
            }

            try {
                // Run the op
                op.run();

                // Success
                return;
            } catch (Exception e) {
                e.printStackTrace();
                close();
            }
        }
    }

    private void sendInitialMessages() throws IOException, InterruptedException {
        if (cfg.authenticationKey != null) {
            new Sendable(this, new Message(Type.Authenticate, null,
                    utf8(cfg.authenticationKey))).sendImmediate();
        }

        for (ByteBuffer topic : subscriptions) {
            new Sendable(this, new Message(Type.Subscribe, topic.array(), null))
                    .sendImmediate();
        }
    }

    private void readLoop(MessageUnpacker in) {
        try {
            doReadLoop(in);
        } catch (Exception e) {
            e.printStackTrace();
            forceReconnect.set(true);
            forceConnect();
        }
    }

    private void doReadLoop(MessageUnpacker in) throws IOException,
            InterruptedException {
        while (in.hasNext()) {
            if (in.getNextFormat() == MessageFormat.NIL) {
                in.skipValue();
                continue;
            }
            byte type = in.unpackByte();
            if (type == Type.KeepAlive) {
                // KeepAlive messages only contain the type, and we ignore them
                continue;
            }
            Message msg = new Message();
            msg.setType(type);
            msg.setTopic(unpackByteArray(in));
            msg.setBody(unpackByteArray(in));
            this.in.put(msg);
        }
    }

    private void forceConnect() {
        outQueue.offer(NOOP);
    }

    private final Runnable sendKeepalive = new Runnable() {
        public void run() {
            outQueue.offer(new Sendable(Client.this, new Message(
                    Type.KeepAlive, null, null)));
        }
    };

    private synchronized void resetKeepalive() {
        if (nextKeepalive != null) {
            nextKeepalive.cancel(false);
        }
        nextKeepalive = scheduledExecutor.schedule(sendKeepalive,
                cfg.keepalivePeriod,
                TimeUnit.MILLISECONDS);
    }

    private void close() {
        if (socket != null) {
            try {
                packer.close();
            } catch (Exception e) {
                // ignore exception on close
            }
            socket = null;
            packer = null;
        }
    }

    private static class Sendable implements Runnable {
        private final Client client;
        private final Message msg;

        public Sendable(Client client, Message msg) {
            super();
            this.client = client;
            this.msg = msg;
        }

        private void send() throws InterruptedException {
            client.outQueue.put(this);
        }

        public void run() {
            try {
                sendImmediate();
            } catch (IOException ioe) {
                throw new RuntimeException("Unable to send message: "
                        + ioe.getMessage(), ioe);
            }
        }

        private void sendImmediate() throws IOException {
            client.resetKeepalive();
            client.packer.packByte(msg.getType());
            if (msg.getType() != Type.KeepAlive) {
                // Only non-KeepAlive messages contain a topic and body
                packByteArray(msg.getTopic());
                packByteArray(msg.getBody());
            }
            client.packer.flush();
        }

        private void packByteArray(byte[] bytes) throws IOException {
            if (bytes == null) {
                client.packer.packNil();
            } else {
                client.packer.packBinaryHeader(bytes.length);
                client.packer.writePayload(bytes);
            }
        }
    }

    private static byte[] unpackByteArray(MessageUnpacker in)
            throws IOException {
        if (MessageFormat.NIL == in.getNextFormat()) {
            in.skipValue();
            return null;
        }
        int length = in.unpackBinaryHeader();
        byte[] result = new byte[length];
        in.readPayload(result);
        return result;
    }

    // pubsub.lantern.io uses a certificate from letsencrypt. The root
    // certificates for letsencrypt are not part of Java's standard trust store,
    // so we're loading it explicitly.
    //
    // See
    // http://danielstechblog.blogspot.com/2016/02/letsencrypt-java-truststore.html
    // See
    // http://stackoverflow.com/questions/24043397/options-for-programatically-adding-certificates-to-java-keystore
    private static final SSLContext sslContext;

    static {
        try {
            KeyStore ks = KeyStore.getInstance(KeyStore.getDefaultType());
            ks.load(null, null);
            addCertificate(ks, "isrgrootx1", "isrgrootx1.pem");
            addCertificate(ks, "letsencryptauthorityx1",
                    "letsencryptauthorityx1.der");
            addCertificate(ks, "letsencryptauthorityx2",
                    "letsencryptauthorityx2.der");
            addCertificate(ks, "lets-encrypt-x2-cross-signed",
                    "lets-encrypt-x2-cross-signed.der");

            TrustManagerFactory tmf = TrustManagerFactory
                    .getInstance(TrustManagerFactory.getDefaultAlgorithm());
            tmf.init(ks);

            sslContext = SSLContext.getInstance("TLS");
            sslContext.init(null, tmf.getTrustManagers(), null);
        } catch (Exception e) {
            e.printStackTrace();
            throw new RuntimeException("Unable to initialize sslContext: "
                    + e.getMessage(), e);
        }
    }

    private static void addCertificate(KeyStore ks, String alias, String file)
            throws Exception {
        InputStream in = Client.class.getResourceAsStream(file);
        X509Certificate cert = (X509Certificate) CertificateFactory
                .getInstance("X.509")
                .generateCertificate(in);
        ks.setCertificateEntry(alias, cert);
    }
}
