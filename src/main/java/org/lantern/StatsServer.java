package org.lantern;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.util.concurrent.ThreadFactoryBuilder;

/**
 * Class that serves JSON stats over REST.
 */
public class StatsServer {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final ExecutorService service = 
        Executors.newCachedThreadPool(
            new ThreadFactoryBuilder().setDaemon(true).build());
    
    public void serve() {
        service.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    final ServerSocket server = new ServerSocket();
                    server.bind(new InetSocketAddress("127.0.0.1", 7878));
                    while (true) {
                        final Socket sock = server.accept();
                        processSocket(sock);
                    }
                } catch (final IOException e) {
                    log.error("Could not run stats server?", e);
                }
            }
        });
    }

    private void processSocket(final Socket sock) {
        service.execute(new Runnable() {

            @Override
            public void run() {
                log.info("Got socket!!");
                try {
                    final InputStream is = sock.getInputStream();
                    final BufferedReader br = 
                        new BufferedReader(new InputStreamReader(is, "UTF-8"));
                    String cur = br.readLine();
                    if (StringUtils.isBlank(cur)) {
                        log.info("Closing blank request socket");
                        IOUtils.closeQuietly(sock);
                        return;
                    } 
                    
                    if (!cur.startsWith("GET /stats")) {
                        log.info("Ignoring request with line: "+cur);
                        IOUtils.closeQuietly(sock);
                        return;
                    }
                    while (StringUtils.isNotBlank(cur)) {
                        log.info(cur);
                        cur = br.readLine();
                    }
                    log.info("Read all headers...");
                    
                    final String body = LanternHub.statsTracker().toJson();
                    OutputStream os = sock.getOutputStream();
                    final String response = 
                        "HTTP/1.1 200 OK\r\n"+
                        "Content-Type: application/json\r\n"+
                        "Connection: close\r\n"+
                        "Content-Length: "+body.length()+"\r\n"+
                        "\r\n"+
                        body;
                    os.write(response.getBytes("UTF-8"));
                } catch (final IOException e) {
                    log.info("Exception serving stats!", e);
                } finally {
                    IOUtils.closeQuietly(sock);
                }
            }
            
        });
    }

}
