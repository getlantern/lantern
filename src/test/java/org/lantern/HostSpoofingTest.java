package org.lantern;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;

import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

import org.apache.commons.io.IOUtils;

import com.google.common.base.Charsets;

public class HostSpoofingTest {

    public static void main(final String... args) throws Exception {
        final SSLSocket sock = (SSLSocket) SSLSocketFactory.getDefault().createSocket();
        sock.connect(new InetSocketAddress("github.global.ssl.fastly.net", 443), 10000);
        
        OutputStream os = null;
        try {
            os = sock.getOutputStream();
            writeHttpRequest(os);
            readResponse(sock.getInputStream());
        } finally {
            IOUtils.closeQuietly(os);
        }
    }

    private static void readResponse(InputStream inputStream) throws IOException {
        /*
        BufferedReader br = null;
        br = new BufferedReader(new InputStreamReader(inputStream));
        String cur = br.readLine();
        while (!StringUtils.isEmpty(cur)) {
            System.err.println(cur);
            cur = br.readLine();
        }
        */
        final byte[] body = new byte[1200];
        int n = 0;
        int read = 0;
        while ((read = inputStream.read(body, n, 1200 - n)) > 0) {
            n += read;
        };
        System.out.println(new String(body, "UTF-8"));
    }

    private static void writeHttpRequest(final OutputStream os) throws IOException {
        os.write("GET / HTTP/1.1\r\n".getBytes(Charsets.UTF_8));
        os.write("Host: fastly.getlantern.org\r\n".getBytes(Charsets.UTF_8));
        os.write("\r\n".getBytes(Charsets.UTF_8));
    }

}
