package org.lantern;

import java.util.Arrays;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.OptionBuilder;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.PosixParser;
import org.apache.commons.cli.UnrecognizedOptionException;

/**
 * Class for handling the Lantern command line interface options.
 */
public class Cli {


    // the following are command line options
    public static final String OPTION_DISABLE_UI = "disable-ui";
    public static final String OPTION_HELP = "help";
    public static final String OPTION_LAUNCHD = "launchd";
    public static final String OPTION_PUBLIC_API = "public-api";
    public static final String OPTION_SERVER_PORT = "server-port";
    public static final String OPTION_SERVER_PROTOCOL = "server-protocol";
    public static final String OPTION_SERVER_AUTHTOKEN_FILE = "auth-token-file";
    public static final String OPTION_DISABLE_KEYCHAIN = "disable-keychain";
    public static final String OPTION_PASSWORD_FILE = "password-file";
    public static final String OPTION_TRUSTED_PEERS = "disable-trusted-peers";
    public static final String OPTION_ANON_PEERS ="disable-anon-peers";
    public static final String OPTION_LAE = "disable-lae";
    public static final String OPTION_CENTRAL = "disable-central";
    public static final String OPTION_UDP_PROXY_PRIORITY = "udp-proxy-priority";
    public static final String OPTION_UDP = "disable-udp";
    public static final String OPTION_TCP = "disable-tcp";
    public static final String OPTION_USER = "user";
    public static final String OPTION_PASS = "pass";
    public static final String OPTION_GET = "force-get";
    public static final String OPTION_GIVE = "force-give";
    public static final String OPTION_VERSION = "version";
    public static final String OPTION_NEW_UI = "new-ui";
    public static final String OPTION_REFRESH_TOK = "refresh-tok";
    public static final String OPTION_ACCESS_TOK = "access-tok";
    public static final String OPTION_OAUTH2_CLIENT_SECRETS_FILE = "oauth2-client-secrets-file";
    public static final String OPTION_OAUTH2_USER_CREDENTIALS_FILE = "oauth2-user-credentials-file";
    public static final String OPTION_CONTROLLER_ID = "controller-id";
    public static final String OPTION_INSTANCE_ID = "instance-id";
    public static final String OPTION_AS_FALLBACK = "as-fallback-proxy";
    public static final String OPTION_KEYSTORE = "keystore";
    public static final String OPTION_REPORT_IP = "report-ip";
    public static final String OPTION_PLUGGABLE_TRANSPORT = "pt";
    public static final String OPTION_TEST_FALLBACKS = "test-fallbacks";
    
    private CommandLine cmd;
    
    public Cli(String[] args) {
        // first apply any command line settings
        final Options options = buildOptions();
        final CommandLineParser parser = new PosixParser();
        try {
            cmd = parser.parse(options, args);
            if (cmd.getArgs().length > 0) {
                throw new UnrecognizedOptionException("Extra arguments were provided");
            }
        }
        catch (final ParseException e) {
            printHelp(options, e.getMessage()+" args: "+Arrays.asList(args));
            return;
        }


        if (cmd.hasOption(OPTION_HELP)) {
            printHelp(options, null);
            System.exit(0);
        } else if (cmd.hasOption(OPTION_VERSION)) {
            printVersion();
            System.exit(0);
        }
    }
    

    private static void printHelp(Options options, String errorMessage) {
        if (errorMessage != null) {
            System.err.println(errorMessage);
        }

        final HelpFormatter formatter = new HelpFormatter();
        formatter.printHelp("lantern", options);
    }

    private static void printVersion() {
        System.out.println("Lantern version "+LanternClientConstants.VERSION);
    }

    public static Options buildOptions() {
        final Options options = new Options();
        options.addOption(null, OPTION_DISABLE_UI, false,
            "run without a graphical user interface.");
        options.addOption(null, OPTION_SERVER_PORT, true,
            "the port to run the give mode proxy server on.");
        options.addOption(null, OPTION_SERVER_PROTOCOL, true,
                "the protocol with which to run the proxy ('tcp' or 'udp').");
        options.addOption(null, OPTION_SERVER_AUTHTOKEN_FILE, true,
                "a file containing the auth-token to require from clients.");
        options.addOption(null, OPTION_PUBLIC_API, false,
            "make the API server publicly accessible on non-localhost.");
        options.addOption(null, OPTION_HELP, false,
            "display command line help");
        options.addOption(null, OPTION_LAUNCHD, false,
            "running from launchd - not normally called from command line");
        options.addOption(null, OPTION_DISABLE_KEYCHAIN, false,
            "disable use of system keychain and ask for local password");
        options.addOption(null, OPTION_PASSWORD_FILE, true,
            "read local password from the file specified");
        options.addOption(null, OPTION_TRUSTED_PEERS, false,
            "disable use of trusted peer-to-peer connections for proxies.");
        options.addOption(null, OPTION_ANON_PEERS, false,
            "disable use of anonymous peer-to-peer connections for proxies.");
        options.addOption(null, OPTION_LAE, false,
            "disable use of app engine proxies.");
        options.addOption(null, OPTION_CENTRAL, false,
            "disable use of centralized proxies.");
        options.addOption(null, OPTION_UDP_PROXY_PRIORITY, true,
                "set the priority of UDP proxies relative to TCP, one of 'lower', 'same', or 'higher', defaults to 'lower'");
        options.addOption(null, OPTION_UDP, false,
            "disable UDP for peer-to-peer connections.");
        options.addOption(null, OPTION_TCP, false,
            "disable TCP for peer-to-peer connections.");
        options.addOption(null, OPTION_USER, true,
            "Google user name -- WARNING INSECURE - ONLY USE THIS FOR TESTING!");
        options.addOption(null, OPTION_PASS, true,
            "Google password -- WARNING INSECURE - ONLY USE THIS FOR TESTING!");
        options.addOption(null, OPTION_GET, false, "Force running in get mode");
        options.addOption(null, OPTION_GIVE, false, "Force running in give mode");
        options.addOption(null, OPTION_VERSION, false,
            "Print the Lantern version");
        options.addOption(null, OPTION_NEW_UI, false,
            "Use the new UI under the 'ui' directory");
        options.addOption(null, OPTION_REFRESH_TOK, true,
                "Specify the oauth2 refresh token");
        options.addOption(null, OPTION_ACCESS_TOK, true,
                "Specify the oauth2 access token");
        options.addOption(null, OPTION_OAUTH2_CLIENT_SECRETS_FILE, true,
            "read Google OAuth2 client secrets from the file specified");
        options.addOption(null, OPTION_OAUTH2_USER_CREDENTIALS_FILE, true,
            "read Google OAuth2 user credentials from the file specified");
        options.addOption(null, OPTION_CONTROLLER_ID, true,
            "GAE id of the lantern-controller");
        options.addOption(null, OPTION_INSTANCE_ID, true,
            "Identifier for this instance in the lantern-controller");
        options.addOption(null, OPTION_AS_FALLBACK, false,
            "Run as fallback proxy");
        options.addOption(null, OPTION_KEYSTORE, true,
            "[XXX: perhaps provisional] path to keystore file where the fallback proxy should find its own keypair.");
        options.addOption(null, OPTION_REPORT_IP, true,
            "(Fallback's listen) IP to report to controller");
        options.addOption(null, OPTION_TEST_FALLBACKS, false,
                "run in 'test fallbacks' mode, i.e. periodically make sure we can proxy through all known fallbacks");
        options.addOption(OptionBuilder
                .withLongOpt(OPTION_PLUGGABLE_TRANSPORT)
                .withArgName("property=value")
                .hasArgs(2)
                .withValueSeparator()
                .withDescription("(Optional) Specify pluggable transport properties")
                .create());
        return options;
    }


    public CommandLine getParsedCommandLine() {
        return this.cmd;
    }
}
