package org.lantern.proxy.pt;

import java.io.File;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.Properties;

import org.apache.commons.exec.CommandLine;
import org.apache.commons.exec.DefaultExecuteResultHandler;
import org.apache.commons.exec.DefaultExecutor;
import org.apache.commons.exec.ExecuteWatchdog;
import org.apache.commons.exec.Executor;
import org.apache.commons.exec.PumpStreamHandler;
import org.apache.commons.exec.ShutdownHookProcessDestroyer;
import org.apache.commons.io.FileUtils;
import org.apache.commons.lang3.SystemUtils;
import org.lantern.LanternClientConstants;
import org.lantern.LanternUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * <p>
 * Implementation of {@link PluggableTransport} that runs a standalone
 * flashlight process in order to provide a client pluggable transport. It
 * cannot be used as a server-side pluggable transport.
 * </p>
 */
public class Flashlight implements PluggableTransport {
    private static final Logger LOGGER = LoggerFactory
            .getLogger(Flashlight.class);
    private static final String FLASHLIGHT_RELATIVE_PATH = "pt/flashlight";
    private static final String FLASHLIGHT_BASE_PATH = findFlashlight()
            .getAbsolutePath();
    private static final String[] FLASHLIGHT_EXECUTABLE_NAMES =
            new String[] { "flashlight", "flashlight.exe" };

    private static final File CA_CERT_FILE =
            new File(LanternClientConstants.CONFIG_DIR + File.separator +
                    "pt" + File.separator +
                    "flashlight" + File.separator +
                    "cacert.pem");

    private static final String GLOBALSIGN_CA_CERT = "-----BEGIN CERTIFICATE-----\nMIIDdTCCAl2gAwIBAgILBAAAAAABFUtaw5QwDQYJKoZIhvcNAQEFBQAwVzELMAkG\nA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNVBAsTB1Jv\nb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw05ODA5MDExMjAw\nMDBaFw0yODAxMjgxMjAwMDBaMFcxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i\nYWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290IENBMRswGQYDVQQDExJHbG9iYWxT\naWduIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDaDuaZ\njc6j40+Kfvvxi4Mla+pIH/EqsLmVEQS98GPR4mdmzxzdzxtIK+6NiY6arymAZavp\nxy0Sy6scTHAHoT0KMM0VjU/43dSMUBUc71DuxC73/OlS8pF94G3VNTCOXkNz8kHp\n1Wrjsok6Vjk4bwY8iGlbKk3Fp1S4bInMm/k8yuX9ifUSPJJ4ltbcdG6TRGHRjcdG\nsnUOhugZitVtbNV4FpWi6cgKOOvyJBNPc1STE4U6G7weNLWLBYy5d4ux2x8gkasJ\nU26Qzns3dLlwR5EiUWMWea6xrkEmCMgZK9FGqkjWZCrXgzT/LCrBbBlDSgeF59N8\n9iFo7+ryUp9/k5DPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8E\nBTADAQH/MB0GA1UdDgQWBBRge2YaRQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0B\nAQUFAAOCAQEA1nPnfE920I2/7LqivjTFKDK1fPxsnCwrvQmeU79rXqoRSLblCKOz\nyj1hTdNGCbM+w6DjY1Ub8rrvrTnhQ7k4o+YviiY776BQVvnGCv04zcQLcFGUl5gE\n38NflNUVyRRBnMRddWQVDf9VMOyGj/8N7yy5Y0b2qvzfvGn9LhJIZJrglfCm7ymP\nAbEVtQwdpf5pLGkkeB6zpxxxYu7KyJesF12KwvhHhm4qxFYxldBniYUr+WymXUad\nDKqC5JlR3XC321Y9YeRq4VzW9v493kHMB65jUr9TU/Qr6cf9tveCX4XSQRjbgbME\nHMUfpIBvFSDJ3gyICh3WZlXi/EjJKSZp4A==\n-----END CERTIFICATE-----\n";

    public static final String ADDRESS_KEY = "addr";

    private String flashlightPath;
    private CommandLine cmd;
    private Executor cmdExec;

    /**
     * Construct a new Flashlight pluggable transport.
     * 
     * @param props
     *            ignored
     */
    public Flashlight(Properties props) {
        super();
    }

    // TODO: make the below shared between fteproxy and flashlight
    private static File findFlashlight() {
        final File rel = new File(FLASHLIGHT_RELATIVE_PATH);
        if (rel.isDirectory())
            return rel;

        if (SystemUtils.IS_OS_MAC_OSX) {
            return new File("./install/osx", FLASHLIGHT_RELATIVE_PATH);
        }

        if (SystemUtils.IS_OS_WINDOWS) {
            return new File("./install/win", FLASHLIGHT_RELATIVE_PATH);
        }

        if (SystemUtils.OS_ARCH.contains("64")) {
            return new File("./install/linux_x86_64", FLASHLIGHT_RELATIVE_PATH);
        }
        return new File("./install/linux_x86_32", FLASHLIGHT_RELATIVE_PATH);
    }

    @Override
    public InetSocketAddress startClient(
            InetSocketAddress getModeAddress,
            InetSocketAddress proxyAddress) {
        LOGGER.info("Starting flashlight client");
        InetSocketAddress address = new InetSocketAddress(
                getModeAddress.getAddress(),
                LanternUtils.findFreePort());

        startFlashlight("-addr", String.format("%s:%s", address.getHostName(),
                address.getPort()));

        if (!LanternUtils.waitForServer(address, 60000)) {
            throw new RuntimeException("Unable to start flashlight");
        }

        return address;
    }

    @Override
    public void stopClient() {
        LOGGER.info("Stopping flashlight client");
        cmdExec.getWatchdog().destroyProcess();
    }

    @Override
    public void startServer(int port, InetSocketAddress giveModeAddress) {
        throw new UnsupportedOperationException(
                "flashlight does not support server mode");
    }

    @Override
    public void stopServer() {
        // does nothing
    }

    @Override
    public boolean suppliesEncryption() {
        return true;
    }

    @Override
    public String getLocalCACert() {
        try {
            return FileUtils.readFileToString(CA_CERT_FILE);
        } catch (IOException ioe) {
            throw new RuntimeException("Unable to read cacert.pem: "
                    + ioe.getMessage(), ioe);
        }
    }

    private void startFlashlight(Object... args) {
        initFlashlightPath();
        buildCmdLine(args);
        exec();
    }

    private void initFlashlightPath() {
        File flashlight = null;
        for (String name : FLASHLIGHT_EXECUTABLE_NAMES) {
            flashlight = new File(FLASHLIGHT_BASE_PATH + "/" + name);
            flashlightPath = flashlight.getAbsolutePath();
            if (flashlight.exists()) {
                break;
            } else {
                LOGGER.info("flashlight executable not found at {}",
                        flashlightPath);
                flashlight = null;
                flashlightPath = null;
            }
        }
        if (flashlight == null) {
            String message = "flashlight executable not found in search path";
            LOGGER.error(message, flashlightPath);
            throw new Error(message);
        }
    }

    private void buildCmdLine(Object... args) {
        cmd = new CommandLine(flashlightPath);
        // -addr localhost:10080 -server getiantem.org -masquerade
        // thehackernews.com -configDir ~/.lantern/pt/flashlight
        cmd.addArgument("-server");
        cmd.addArgument("getiantem.org");
        cmd.addArgument("-masquerade");
        cmd.addArgument("cdnjs.com");
        cmd.addArgument("-masqueradecacert");
        cmd.addArgument("'"+GLOBALSIGN_CA_CERT+"'");
        cmd.addArgument("-configdir");
        cmd.addArgument(String.format("%s%spt%sflashlight",
                LanternClientConstants.CONFIG_DIR,
                File.separatorChar,
                File.separatorChar));
        for (Object arg : args) {
            cmd.addArgument(stringify(arg));
        }
    }

    private void exec() {
        cmdExec = new DefaultExecutor();
        cmdExec.setStreamHandler(new PumpStreamHandler(System.out,
                System.err,
                System.in));
        cmdExec.setProcessDestroyer(new ShutdownHookProcessDestroyer());
        cmdExec.setWatchdog(new ExecuteWatchdog(
                ExecuteWatchdog.INFINITE_TIMEOUT));
        DefaultExecuteResultHandler resultHandler = new DefaultExecuteResultHandler();
        LOGGER.info("About to run cmd: {}", cmd);
        try {
            cmdExec.execute(cmd, resultHandler);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private static String stringify(Object value) {
        return String.format("%1$s", value);
    }
}
