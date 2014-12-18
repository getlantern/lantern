package org.lantern.state;

import java.io.File;
import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.Properties;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.io.FileUtils;
import org.apache.commons.lang3.StringUtils;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.lantern.Cli;
import org.lantern.Country;
import org.lantern.CountryService;
import org.lantern.LanternClientConstants;
import org.lantern.LanternUtils;
import org.lantern.S3Config;
import org.lantern.event.Events;
import org.lantern.event.RefreshTokenEvent;
import org.lantern.privacy.EncryptedFileService;
import org.lantern.privacy.InvalidKeyException;
import org.lantern.privacy.LocalCipherProvider;
import org.lantern.proxy.pt.PtType;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.littleshoot.proxy.TransportProtocol;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class ModelIo extends Storage<Model> {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private final CountryService countryService;
    private final CommandLine commandLine;
    private LocalCipherProvider localCipherProvider;

    /**
     * Creates a new instance with all the default operations.
     */
    @Inject
    public ModelIo(final EncryptedFileService encryptedFileService,
                   final CountryService countryService,
                   final CommandLine commandLine,
                   final LocalCipherProvider lcp) {
        this(LanternClientConstants.DEFAULT_MODEL_FILE, encryptedFileService,
                countryService, commandLine, lcp);
    }

    /**
     * Creates a new instance with custom settings typically used only in
     * testing.
     *
     * @param modelFile The file where settings are stored.
     * @param commandLine The command line arguments.
     * @param localCipherProvider The local cipher provider for accessing
     * encrypted data on disk.
     * @param s3ConfigManager The S3 config manager for maintaining the
     * controller-dependent data.
     */
    public ModelIo(final File modelFile,
                   final EncryptedFileService encryptedFileService,
                   final CountryService countryService,
                   final CommandLine commandLine,
                   final LocalCipherProvider localCipherProvider) {
        super(encryptedFileService, modelFile, Model.class);
        this.countryService = countryService;
        this.commandLine = commandLine;
        this.localCipherProvider = localCipherProvider;
        
        obj = read();
        Events.register(this);
        onS3ConfigChange(obj.getS3Config());
        log.info("Loaded module");
    }

    /**
     * Reads the state model from disk.
     *
     * @return The {@link Model} instance as read from disk.
     */
    @Override
    public Model read() {
        try {
            final Model read = super.read();
            read.setCountryService(countryService);
            if (!LanternUtils.persistCredentials()) {
                if (read.getModal() != Modal.welcome) {
                    read.setModal(Modal.authorize);
                }
            }

            // Make sure all peers are considered offline at startup.
            final Peers peers = read.getPeerCollector();
            peers.reset();
            if (read.getModal() == Modal.settingsLoadFailure) {
                read.setModal(Modal.none);
            }
            boolean isCensored = false;
            String countryCode = read.getLocation().getCountry();
            if (countryCode != null) {
                Country country = countryService.getCountryByCode(countryCode);
                if (country != null) {
                    isCensored = country.isCensors();
                }
            }
            if (!isCensored && read.getModal() == Modal.giveModeForbidden) {
                read.setModal(Modal.none);
            }
            LanternUtils.setModel(read);
            processCommandLine(this.commandLine, read);
            return read;
        } catch (final ModelReadFailedException e) {
            log.error("Failed to read model", e);
            Model blank = blank();
            blank.setModal(Modal.settingsLoadFailure);
            return blank;
        } catch (final Exception e) {
            log.error("Failed to read model for some other reason", e);
            Model blank = blank();
            return blank;
        }
    }
    
    /**
     * We need to make sure to set the server port before anything is 
     * injected -- otherwise we run the risk of running on a completely 
     * different port than what is passed on the command line!
     * 
     * @param cmd The command line.
     * @param read The model
     */
    private void processCommandLine(final CommandLine cmd, final Model model) {

        if (cmd == null) {
            // Can be true for testing.
            log.error("No command line?");
            return;
        }
        final Settings set = model.getSettings();
        if (cmd.hasOption(Cli.OPTION_SERVER_PORT)) {
            final String serverPortStr =
                cmd.getOptionValue(Cli.OPTION_SERVER_PORT);
            log.debug("Using command-line proxy port: "+serverPortStr);
            final int serverPort = Integer.parseInt(serverPortStr);
            set.setServerPort(serverPort);
        } else {
            final int existing = set.getServerPort();
            if (existing < 1024) {
                log.debug("Using random give mode proxy port...");
                set.setServerPort(LanternUtils.randomPort());
            }
        }
        log.info("Running give mode proxy on port: {}", set.getServerPort());
        
        TransportProtocol proxyProtocol = TransportProtocol.TCP;
        if (cmd.hasOption(Cli.OPTION_SERVER_PROTOCOL)) {
            String serverProtocol = cmd
                    .getOptionValue(Cli.OPTION_SERVER_PROTOCOL);
            if ("udp".equalsIgnoreCase(serverProtocol)) {
                proxyProtocol = TransportProtocol.UDT;
            }
        }
        set.setProxyProtocol(proxyProtocol);
        log.info("Running give mode proxy with protocol: {}", proxyProtocol);
        
        if (cmd.hasOption(Cli.OPTION_PLUGGABLE_TRANSPORT)) {
            Properties props = cmd.getOptionProperties(Cli.OPTION_PLUGGABLE_TRANSPORT);
            String type = props.getProperty("type");
            if (type != null) {
                PtType proxyPtType = PtType.valueOf(type.toUpperCase());
                log.info("Running give mode proxy with pluggable transport " + proxyPtType);
                set.setProxyPtType(proxyPtType);
                set.setProxyPtProps(props);
            }
        } 
        
        final String authTokenOpt = Cli.OPTION_SERVER_AUTHTOKEN_FILE;
        if (cmd.hasOption(authTokenOpt)) {
            loadServerAuthTokenFile(cmd.getOptionValue(authTokenOpt), set);
        }

        if (cmd.hasOption(Cli.OPTION_KEYSTORE)) {
            LanternUtils.setFallbackKeystorePath(cmd.getOptionValue(Cli.OPTION_KEYSTORE));
        }
        
        final String ctrlOpt = Cli.OPTION_CONTROLLER_ID;
        if (cmd.hasOption(ctrlOpt)) {
            LanternClientConstants.setControllerId(
                cmd.getOptionValue(ctrlOpt));
        }

        final String insOpt = Cli.OPTION_INSTANCE_ID;
        if (cmd.hasOption(insOpt)) {
            model.setInstanceId(cmd.getOptionValue(insOpt));
        }

        final String fbOpt = Cli.OPTION_AS_FALLBACK;
        if (cmd.hasOption(fbOpt)) {
            LanternUtils.setFallbackProxy(true);
        }

        final String secOpt = Cli.OPTION_OAUTH2_CLIENT_SECRETS_FILE;
        if (cmd.hasOption(secOpt)) {
            loadOAuth2ClientSecretsFile(cmd.getOptionValue(secOpt), set);
        }

        final String credOpt = Cli.OPTION_OAUTH2_USER_CREDENTIALS_FILE;
        if (cmd.hasOption(credOpt)) {
            loadOAuth2UserCredentialsFile(cmd.getOptionValue(credOpt), set);
        }

        final String ripOpt = Cli.OPTION_REPORT_IP;
        if (cmd.hasOption(ripOpt)) {
            model.setReportIp(cmd.getOptionValue(ripOpt));
        }

        //final Settings set = LanternHub.settings();

        set.setUseTrustedPeers(parseOptionDefaultTrue(cmd, Cli.OPTION_TRUSTED_PEERS));
        set.setUseAnonymousPeers(parseOptionDefaultTrue(cmd, Cli.OPTION_ANON_PEERS));
        set.setUseLaeProxies(parseOptionDefaultTrue(cmd, Cli.OPTION_LAE));
        set.setUseCentralProxies(parseOptionDefaultTrue(cmd, Cli.OPTION_CENTRAL));
        set.setUdpProxyPriority(cmd.getOptionValue(Cli.OPTION_UDP_PROXY_PRIORITY, "lower").toUpperCase());
        
        final boolean tcp = parseOptionDefaultTrue(cmd, Cli.OPTION_TCP);
        final boolean udp = parseOptionDefaultTrue(cmd, Cli.OPTION_UDP);
        IceConfig.setTcp(tcp);
        IceConfig.setUdp(udp);
        set.setTcp(tcp);
        set.setUdp(udp);

        /*
        if (cmd.hasOption(OPTION_USER)) {
            set.setUserId(cmd.getOptionValue(OPTION_USER));
        }
        if (cmd.hasOption(OPTION_PASS)) {
            set.(cmd.getOptionValue(OPTION_PASS));
        }
        */

        if (cmd.hasOption(Cli.OPTION_ACCESS_TOK)) {
            set.setAccessToken(cmd.getOptionValue(Cli.OPTION_ACCESS_TOK));
        }
        
        if (cmd.hasOption(Cli.OPTION_REFRESH_TOK)) {
            final String refresh = cmd.getOptionValue(Cli.OPTION_REFRESH_TOK);
            set.setRefreshToken(refresh);
            Events.asyncEventBus().post(new RefreshTokenEvent(refresh));
        }
        // option to disable use of keychains in local privacy
        if (cmd.hasOption(Cli.OPTION_DISABLE_KEYCHAIN)) {
            log.info("Disabling use of system keychains");
            set.setKeychainEnabled(false);
        }
        else {
            set.setKeychainEnabled(true);
        }

        if (cmd.hasOption(Cli.OPTION_PASSWORD_FILE)) {
            loadLocalPasswordFile(cmd.getOptionValue(Cli.OPTION_PASSWORD_FILE));
        }

        if (cmd.hasOption(Cli.OPTION_PUBLIC_API)) {
            set.setBindToLocalhost(false);
        }

        log.info("Running API on port: {}", StaticSettings.getApiPort());
        if (cmd.hasOption(Cli.OPTION_LAUNCHD)) {
            log.debug("Running from launchd or launchd set on command line");
            model.setLaunchd(true);
        } else {
            model.setLaunchd(false);
        }

        if (cmd.hasOption(Cli.OPTION_GIVE)) {
            model.getSettings().setMode(Mode.give);
        } else if (cmd.hasOption(Cli.OPTION_GET)) {
            model.getSettings().setMode(Mode.get);
        }
        
        if (cmd.hasOption(Cli.OPTION_CHROME)) {
            set.setChrome(true);
        }
        
        if (cmd.hasOption(Cli.OPTION_FORCE_FLASHLIGHT)) {
            LanternClientConstants.FORCE_FLASHLIGHT = true;
        }
    }
    
    private void loadServerAuthTokenFile(final String filename, final Settings set) {
        if (StringUtils.isBlank(filename)) {
            log.error("No server auth token filename specified");
            throw new NullPointerException("No filename specified!");
        }
        final File file = new File(filename);
        if (!(file.exists() && file.canRead())) {
            log.error("Unable to read server auth token  from {}", filename);
            throw new IllegalArgumentException("File does not exist! "+filename);
        }
        log.info("Reading server auth token from file \"{}\"", filename);
        try {
            String authToken = FileUtils.readFileToString(file, "UTF-8");
            // Strip all whitespace
            authToken = authToken.replaceAll("\\s", "");
            set.setProxyAuthToken(authToken);
        } catch (final IOException e) {
            log.error("Failed to read file \"{}\"", filename);
            throw new Error("Could not load server auth token", e);
        }
    }

    private void loadOAuth2ClientSecretsFile(final String filename, final Settings set) {
        if (StringUtils.isBlank(filename)) {
            log.error("No filename specified");
            throw new NullPointerException("No filename specified!");
        }
        final File file = new File(filename);
        if (!(file.exists() && file.canRead())) {
            log.error("Unable to read user credentials from {}", filename);
            throw new IllegalArgumentException("File does not exist! "+filename);
        }
        log.debug("Reading client secrets from file \"{}\"", filename);
        try {
            final String json = FileUtils.readFileToString(file, "US-ASCII");
            JSONObject installed = (JSONObject)JSONValue.parse(json);
            final JSONObject ins;
            final JSONObject temp = (JSONObject)installed.get("installed");
            if (temp == null) {
                ins = (JSONObject)installed.get("web");
            } else {
                ins = temp;
            }
            //JSONObject ins = (JSONObject)obj.get("installed");
            final String clientID = (String)ins.get("client_id");
            final String clientSecret = (String)ins.get("client_secret");
            if (StringUtils.isBlank(clientID) || 
                StringUtils.isBlank(clientSecret)) {
                log.error("Failed to parse client secrets file \"{}\"", file);
                throw new Error("Failed to parse client secrets file: "+ file);
            } else {
                set.setClientID(clientID);
                set.setClientSecret(clientSecret);
            }
        } catch (final IOException e) {
            log.error("Failed to read file \"{}\"", filename);
            throw new Error("Could not load oauth file"+file, e);
        }
    }

    public void loadOAuth2UserCredentialsFile(final String filename,
            final Settings set) {
        if (StringUtils.isBlank(filename)) {
            log.error("No filename specified");
            throw new NullPointerException("No filename specified!");
        }
        final File file = new File(filename);
        if (!(file.exists() && file.canRead())) {
            log.error("Unable to read user credentials from {}", filename);
            throw new IllegalArgumentException("File does not exist! "+filename);
        }
        log.info("Reading user credentials from file \"{}\"", filename);
        try {
            final String json = FileUtils.readFileToString(file, "US-ASCII");
            final JSONObject creds = (JSONObject)JSONValue.parse(json);
            final String username = (String)creds.get("username");
            final String accessToken = (String)creds.get("access_token");
            final String refreshToken = (String)creds.get("refresh_token");
            // Access token is not strictly necessary, so we allow it to be
            // null.
            if (StringUtils.isBlank(username) || 
                StringUtils.isBlank(refreshToken)) {
                log.error("Failed to parse user credentials file \"{}\"", filename);
                throw new Error("Could not load username or refresh_token");
            } else {
                set.setAccessToken(accessToken);
                set.setRefreshToken(refreshToken);
                set.setUseGoogleOAuth2(true);
            }
        } catch (final IOException e) {
            log.error("Failed to read file \"{}\"", filename);
            throw new Error("Could not load oauth credentials", e);
        }
    }

    private boolean parseOptionDefaultTrue(final CommandLine cmd,
        final String option) {
        if (cmd.hasOption(option)) {
            log.info("Found option: "+option);
            return false;
        }

        // DEFAULTS TO TRUE!!
        return true;
    }

    private void loadLocalPasswordFile(final String pwFilename) {
        //final LocalCipherProvider lcp = localCipherProvider;
        if (!localCipherProvider.requiresAdditionalUserInput()) {
            log.error("Settings do not require a password to unlock.");
            System.exit(1);
        }

        if (StringUtils.isBlank(pwFilename)) {
            log.error("No filename specified to --{}", Cli.OPTION_PASSWORD_FILE);
            System.exit(1);
        }
        final File pwFile = new File(pwFilename);
        if (!(pwFile.exists() && pwFile.canRead())) {
            log.error("Unable to read password from {}", pwFilename);
            System.exit(1);
        }

        log.info("Reading local password from file \"{}\"", pwFilename);
        try {
            final String pw = FileUtils.readLines(pwFile, "US-ASCII").get(0);
            final boolean init = !localCipherProvider.isInitialized();
            localCipherProvider.feedUserInput(pw.toCharArray(), init);
        }
        catch (final IndexOutOfBoundsException e) {
            log.error("Password in file \"{}\" was incorrect", pwFilename);
            System.exit(1);
        }
        catch (final InvalidKeyException e) {
            log.error("Password in file \"{}\" was incorrect", pwFilename);
            System.exit(1);
        }
        catch (final GeneralSecurityException e) {
            log.error("Failed to initialize using password in file \"{}\": {}", pwFilename, e);
            System.exit(1);
        }
        catch (final IOException e) {
            log.error("Failed to initialize using password in file \"{}\": {}", pwFilename, e);
            System.exit(1);
        }
    }


    @Override
    protected Model blank() {
        log.info("Loading empty model!!");
        final Model mod = new Model(countryService);
        processCommandLine(this.commandLine, mod);
        return mod;
    }

    /**
     * Serializes the specified model -- useful for testing.
     */
    @Override
    public synchronized void write(final Model toWrite) {
        final Settings set = toWrite.getSettings();
        final String refresh = set.getRefreshToken();
        final String access = set.getAccessToken();
        final boolean useOauth = set.isUseGoogleOAuth2();
        final boolean gtalk = toWrite.getConnectivity().isGtalkAuthorized();
        if (!LanternUtils.persistCredentials()) {

            set.setRefreshToken("");
            set.setAccessToken("");
            set.setUseGoogleOAuth2(false);
            toWrite.getConnectivity().setGtalkAuthorized(false);

        }
        super.write(toWrite);
        if (!LanternUtils.persistCredentials()) {
            set.setRefreshToken(refresh);
            set.setAccessToken(access);
            set.setUseGoogleOAuth2(useOauth);
            toWrite.getConnectivity().setGtalkAuthorized(gtalk);
        }
    }

    public boolean reload() {
        Model newModel = read();
        newModel.setCountryService(countryService);
        if (newModel.getModal() == Modal.welcome) {
            //if modal is welcome, then we are dealing with fresh settings
            return false;
        }
        obj.loadFrom(newModel);
        return true;
    }
    
    @Subscribe
    public void onS3ConfigChange(final S3Config config) {
        if (hasCommandLineOption(Cli.OPTION_CONTROLLER_ID)) {
            log.info("Not overriding command-line settings.");
        } else if (config != null) {
            final String controller = config.getController();
            if (StringUtils.isNotBlank(controller) && !controller.equalsIgnoreCase("null")) {
                LanternClientConstants.setControllerId(controller);
            }
        }
    }

    private boolean hasCommandLineOption(final String opt) {
        if (commandLine != null) {
            return commandLine.hasOption(opt);
        }
        return false;
    }
}
