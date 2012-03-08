package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.io.UnsupportedEncodingException;
import java.net.URLDecoder;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.eclipse.swt.SWT;
import org.eclipse.swt.browser.Browser;
import org.eclipse.swt.browser.LocationAdapter;
import org.eclipse.swt.browser.LocationEvent;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.graphics.Rectangle;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Event;
import org.eclipse.swt.widgets.Listener;
import org.eclipse.swt.widgets.MessageBox;
import org.eclipse.swt.widgets.Monitor;
import org.eclipse.swt.widgets.Shell;
import org.lantern.SettingsState.State;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class for the embedded browser allowing the user to interface with Lantern.
 */
public class LanternBrowser {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private Shell shell;

    private Browser browser;

    private Display display;

    private File tmp;

    private boolean closed;

    private final boolean isConfig;
    
    private String lastEventLocation = "";
    
    
    public LanternBrowser(final boolean isConfig) {
        log.info("Creating Lantern browser...");
        //I18n = I18nFactory.getI18n(LanternBrowser.class, 
        //        "app.i18n.Messages", locale, I18nFactory.FALLBACK);
        this.display = LanternHub.display();
        this.isConfig = isConfig;
        
        log.info("Creating shell...");
        this.shell = new Shell(display);
        final Image small = newImage("16on.png");
        final Image medium = newImage("32on.png");
        final Image large = newImage("128on.png");
        final Image[] icons = new Image[]{small, medium, large};
        log.info("Setting images...");
        this.shell.setImages(icons);
        // this.shell = createShell(this.display);
        if (isConfig) {
            this.shell.setText(I18n.tr("Configure Lantern"));
        } else {
            this.shell.setText(I18n.tr("Lantern Installation"));
        }
        this.shell.setSize(720, 540);
        // shell.setFullScreen(true);

        log.info("Centering on screen...");
        final Monitor primary = this.display.getPrimaryMonitor();
        final Rectangle bounds = primary.getBounds();
        final Rectangle rect = shell.getBounds();

        final int x = bounds.x + (bounds.width - rect.width) / 2;
        final int y = bounds.y + (bounds.height - rect.height) / 2;

        this.shell.setLocation(x, y);

        log.info("Creating new browser...");
        this.browser = new Browser(shell, SWT.NONE);
        // browser.setSize(700, 500);
        this.browser.setBounds(0, 0, 700, 560);
        // browser.setBounds(5, 75, 600, 400);

        log.info("About to copy html dir");
        final File srv = new File("srv");
        try {
            this.tmp = createTempDirectory();
            FileUtils.copyDirectory(srv, tmp);
            Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
                @Override
                public void run() {
                    cleanup();
                }
            }));
        } catch (final IOException e) {
            log.error("Could not copy to temp dir", e);
            return;
        }
        log.info("tmp files: "+Arrays.asList(tmp.listFiles()));
    }
    
    private Image newImage(final String path) {
        final String toUse;
        final File path1 = new File(path);
        if (path1.isFile()) {
            toUse = path1.getAbsolutePath();
        } else {
            final File path2 = new File("install/common", path);
            toUse = path2.getAbsolutePath();
        }
        return new Image(display, toUse);
    }

    public char[] setLocalPassword() {
        shell.addListener (SWT.Close, new Listener () {
            @Override
            public void handleEvent(final Event event) {
                log.info("CLOSE EVENT: {}", event);
                if (!closed) {
                    final int style = SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.YES | SWT.NO;
                    final MessageBox messageBox = new MessageBox (shell, style);
                    messageBox.setText (I18n.tr("Exit?"));
                    final String msg;
                    if (isConfig) {
                        msg = I18n.tr("Are you sure you want to cancel configuring Lantern?");
                    } else {
                        msg = I18n.tr("Are you sure you want to cancel installing Lantern?");
                    }
                    messageBox.setMessage (msg);
                    event.doit = messageBox.open () == SWT.YES;
                    if (event.doit) {
                        exit();
                    }
                }
            }
        });

        final String startFile = "setLocalPassword0.html";        
        final StringBuffer passwordBuf = new StringBuffer();
        
        final Map<String, String> startVals = new HashMap<String, String>();
        startVals.put("set_password_title", "Set Password");
        startVals.put("title_string", "Choose Password");
        startVals.put("body_string", "Please choose a password to protect your local lantern data.");
        startVals.put("password1_label", "Password");
        startVals.put("password2_label", "Confirm Password");
        startVals.put("confirm_password", "Set Password");
        // startVals.put("set_password_title", I18n.tr("Set Password"));
        // startVals.put("title_string", "Choose Password");
        // startVals.put("body_string", I18n.tr("Please choose a password to protect your local information."));
        // startVals.put("password1_label", I18n.tr("Password"));
        // startVals.put("password2_label", I18n.tr("Confirm Password"));
        // startVals.put("confirm_password", I18n.tr("Set Password"));

        browser.addLocationListener(new LocationAdapter() {
            @Override
            public void changed(final LocationEvent event) {
                final String location = event.location;
                log.info("Got location CHANGED: {}", location);
                if (lastEventLocation.equals(location)) {
                    return;
                }
                processEvent(event);
            }
            @Override
            public void changing(final LocationEvent event) {
                final String location = event.location;
                lastEventLocation = location;
                log.info("Got location CHANGING: {}", location);
                processEvent(event);
            }

            private void processEvent(final LocationEvent event) {
                final String location = event.location;
                log.info("Got location: {}", location);

                if (location.endsWith("-copy.html")) {
                    // This just means it's a request we've already prepared
                    // for serving. If we don't do this check, we'll get an
                    // infinite loop of copies.
                    log.info("Accepting copied location");
                    return;
                }
                // else if (location.contains("setLocalPassword0")) {
                // }
                else if (location.contains("setLocalPassword1")) {
                    final String args = 
                        StringUtils.substringAfter(location, "&");
                    if (StringUtils.isBlank(args)) {
                        log.error("Weird location: {}", location);
                        return;
                    }
                    final String password1 = 
                        StringUtils.substringBetween(location, "&password1=", "&");
                    final String password2 = 
                        StringUtils.substringAfter(location, "&password2=");
                    if (StringUtils.isBlank(password1)) {
                        startVals.put("error_message", "Password cannot be blank");
                        // startVals.put("error_message", I18n.tr("Password cannot be blank"));
                        setUrl(startFile, startVals);
                    }
                    else if (!password1.equals(password2)) {
                        startVals.put("error_message", "Passwords did not match");
                        // startVals.put("error_message", I18n.tr("Passwords did not match"));
                        setUrl(startFile, startVals);
                    }
                    else {
                        passwordBuf.append(password1);
                        close();
                    }
                }
                event.doit = false;
            }
        });

        setUrl(startFile, startVals);

        shell.open();
        shell.forceActive();
        while (!shell.isDisposed()) {
            if (!this.display.readAndDispatch())
                this.display.sleep();
        }

        char[] passwordChars = new char[passwordBuf.length()];
        passwordBuf.getChars(0, passwordBuf.length(), passwordChars, 0);
        return passwordChars;
    }
    
    public interface PasswordValidator {
        public boolean passwordIsValid(char [] password) throws Exception;
    }
    
    public char[] getLocalPassword(final PasswordValidator validator) {
        shell.addListener (SWT.Close, new Listener () {
            @Override
            public void handleEvent(final Event event) {
                log.info("CLOSE EVENT: {}", event);
                if (!closed) {
                    final int style = SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.YES | SWT.NO;
                    final MessageBox messageBox = new MessageBox (shell, style);
                    messageBox.setText (I18n.tr("Exit?"));
                    final String msg;
                    msg = "Are you sure you want to cancel starting Lantern?";
                    // XXX i18n
                    // msg = I18n.tr("Are you sure you want to cancel starting Lantern?");
                    messageBox.setMessage (msg);
                    event.doit = messageBox.open () == SWT.YES;
                    if (event.doit) {
                        exit();
                    }
                }
            }
        });

        final String startFile = "getLocalPassword0.html";        
        final StringBuffer passwordBuf = new StringBuffer();
        
        final Map<String, String> startVals = new HashMap<String, String>();
        // XXX i18n
        startVals.put("get_password_title", "Enter Password");
        startVals.put("title_string", "Enter Password");
        startVals.put("body_string", "Please enter your lantern password.");
        startVals.put("password1_label", "Password");
        startVals.put("confirm_password", "Start Lantern");

        browser.addLocationListener(new LocationAdapter() {
            @Override
            public void changed(final LocationEvent event) {
                final String location = event.location;
                log.info("Got location CHANGED: {}", location);
                if (lastEventLocation.equals(location)) {
                    return;
                }
                processEvent(event);
            }
            @Override
            public void changing(final LocationEvent event) {
                final String location = event.location;
                lastEventLocation = location;
                log.info("Got location CHANGING: {}", location);
                processEvent(event);
            }

            private void processEvent(final LocationEvent event) {
                final String location = event.location;
                log.info("Got location: {}", location);

                if (location.endsWith("-copy.html")) {
                    // This just means it's a request we've already prepared
                    // for serving. If we don't do this check, we'll get an
                    // infinite loop of copies.
                    log.info("Accepting copied location");
                    return;
                }
                // else if (location.contains("getLocalPassword0")) {
                // }
                else if (location.contains("getLocalPassword1")) {
                    final String args = 
                        StringUtils.substringAfter(location, "&");
                    if (StringUtils.isBlank(args)) {
                        log.error("Weird location: {}", location);
                        return;
                    }
                    final String password1 = 
                        StringUtils.substringAfter(location, "&password1=");
                    if (StringUtils.isBlank(password1)) {
                        startVals.put("error_message", "Password cannot be blank");
                        // XXX i18n
                        // startVals.put("error_message", I18n.tr("Password cannot be blank"));
                        setUrl(startFile, startVals);
                    }
                    else {
                        char[] passwordChars = new char[password1.length()];
                        password1.getChars(0, password1.length(), passwordChars, 0);
                        try {
                            if (!validator.passwordIsValid(passwordChars)) {
                                startVals.put("error_message", "The password was incorrect, please try again");
                                // XXX i18n
                                // startVals.put("error_message", I18n.tr("The password was incorrect, please try again"));
                                setUrl(startFile, startVals);
                            }
                            else {
                                passwordBuf.append(password1);
                                close();
                            }
                        } catch (Exception e) {
                            log.error("Error checking user password: {}", e);
                            startVals.put("error_message", "An error occured checking your password.");
                            // XXX i18n
                            // startVals.put("error_message", I18n.tr("An error occurred checking your password"));
                            setUrl(startFile, startVals);                     
                        }
                        finally {
                            Arrays.fill(passwordChars, '\0');
                        }
                    }
                }
                event.doit = false;
            }
        });

        setUrl(startFile, startVals);

        shell.open();
        shell.forceActive();
        while (!shell.isDisposed()) {
            if (!this.display.readAndDispatch())
                this.display.sleep();
        }

        char[] passwordChars = new char[passwordBuf.length()];
        passwordBuf.getChars(0, passwordBuf.length(), passwordChars, 0);
        return passwordChars;
    }

    public void showUpdate(final Map<String, String> update) {
        log.info("Attempting to show udate message");
        final String startFile = "update.html";
        shell.addListener (SWT.Close, new Listener () {
            @Override
            public void handleEvent(final Event event) {
                log.info("CLOSE EVENT: {}", event);
                if (!closed) {
                    final int style = SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.YES | SWT.NO;
                    final MessageBox messageBox = new MessageBox (shell, style);
                    messageBox.setText (I18n.tr("Exit?"));
                    messageBox.setMessage (
                        I18n.tr("Are you sure you want to ignore the update?"));
                    event.doit = messageBox.open () == SWT.YES;
                    if (event.doit) {
                        exit();
                    }
                }
            }
        });
        
        final File file = new File(tmp, startFile).getAbsoluteFile();
        setUrl(file, update);

        browser.addLocationListener(new LocationAdapter() {
            @Override
            public void changing(final LocationEvent event) {
                final String location = event.location;
                log.info("Got location: {}", location);
                if (location.contains("update")) {
                    // Open a real browser to the update page.
                    log.info("Got update url..");
                } else if (location.contains("noUpdate")) {
                    close();
                } 
                event.doit = false;
            }
        });
        
        shell.open();
        shell.forceActive();
        while (!shell.isDisposed()) {
            if (!this.display.readAndDispatch())
                this.display.sleep();
        }
    }

    public void install() {
        shell.addListener (SWT.Close, new Listener () {
            @Override
            public void handleEvent(final Event event) {
                log.info("CLOSE EVENT: {}", event);
                if (!closed) {
                    final int style = SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.YES | SWT.NO;
                    final MessageBox messageBox = new MessageBox (shell, style);
                    messageBox.setText (I18n.tr("Exit?"));
                    final String msg;
                    if (isConfig) {
                        msg = I18n.tr("Are you sure you want to cancel configuring Lantern?");
                    } else {
                        msg = I18n.tr("Are you sure you want to cancel installing Lantern?");
                    }
                    messageBox.setMessage (msg);
                    event.doit = messageBox.open () == SWT.YES;
                    if (event.doit) {
                        LanternUtils.clearCredentials();
                        exit();
                    }
                }
            }
        });
        
        final Map<String, String> startVals = new HashMap<String, String>();
        startVals.put("lead_string", 
            I18n.tr("Welcome to Lantern! You're almost done."));
        startVals.put("title_string", I18n.tr("Complete Your Installation"));
        final String startFile;
        if (LanternHub.censored().isCensored()) {
            startFile = "install0Censored.html";
            startVals.put("body_string", I18n.tr("You appear to be running Lantern to gain access to blocked web sites from a censored country. Is that correct?"));
            startVals.put("yes_need_access", I18n.tr("Yes - I need access to the blocked internet."));
            startVals.put("no_provide_access", I18n.tr("No - I want to provide access instead."));
        } else {
            startFile = "install0Uncensored.html";
            startVals.put("body_string", I18n.tr("You appear to be running Lantern from a country that does not employ censorship. Is that correct?"));
            startVals.put("yes_provide_access", I18n.tr("Yes - I want to provide access to the open internet."));
            startVals.put("no_need_access", I18n.tr("No - I need to access the open internet myself."));
        }
        setUrl(startFile, startVals);

        browser.addLocationListener(new LocationAdapter() {
            @Override
            public void changed(final LocationEvent event) {
                final String location = event.location;
                log.info("Got location CHANGED: {}", location);
                if (lastEventLocation.equals(location)) {
                    return;
                }
                processEvent(event);
            }
            @Override
            public void changing(final LocationEvent event) {
                final String location = event.location;
                lastEventLocation = location;
                log.info("Got location CHANGING: {}", location);
                processEvent(event);
            }
            
            private void processEvent(final LocationEvent event) {
                final String location = event.location;
                lastEventLocation = location;
                log.info("Got location CHANGING: {}", location);
                if (location.endsWith("-copy.html")) {
                    // This just means it's a request we've already prepared
                    // for serving. If we don't do this check, we'll get an
                    // infinite loop of copies.
                    log.info("Accepting copied location");
                    return;
                } else if (location.contains("install1Uncensored.html")) {
                    // The user could be re-configuring their system. Make sure
                    // force is no longer active.
                    if (!LanternHub.censored().isCensored()) {
                        LanternHub.settings().setGetMode(false);
                    }
                    final Map<String, String> replace = install1Uncensored();
                    setUrl("install1Uncensored.html", replace);
                } else if (location.contains("install1Censored.html")) {
                    LanternHub.settings().setGetMode(true);
                    final Map<String, String> replace = install1Censored();
                    setUrl("install1Censored.html", replace);
                } else if (location.contains("trustedContacts")) {
                    log.info("Got trust form");
                    final String elements = 
                        StringUtils.substringAfter(location, "trustedContacts");
                    if (StringUtils.isNotBlank(elements)) {
                        log.info("Got elements: {}", elements);
                        try {
                            String decoded = 
                                URLDecoder.decode(elements, "UTF-8");
                            if (decoded.startsWith("?")) {
                                decoded = decoded.substring(1);
                            }
                            log.info("Decoded: {}", decoded);
                            final String[] contacts = decoded.split("&");
                            final TrustedContactsManager tcm =
                                LanternHub.getTrustedContactsManager();
                            final Collection<String> trusted = 
                                new HashSet<String>();
                            for (final String contact : contacts) {
                                final String email = StringUtils.substringBefore(contact, "=");
                                final String val = StringUtils.substringAfter(contact, "=");
                                if (LanternUtils.isTrue(val)) {
                                    log.info("Adding contact: {}", email);
                                    trusted.add(email);
                                }
                            }
                            tcm.addTrustedContacts(trusted);
                        } catch (final UnsupportedEncodingException e) {
                            log.error("Encoding?", e);
                        }
                    }

                    final Map<String, String> replace = 
                        new HashMap<String, String>();
                    replace.put("lead_string", 
                        I18n.tr("Welcome to Lantern! You're almost done."));
                    replace.put("title_string", 
                        I18n.tr("Complete Your Installation"));
                    replace.put("text_body", 
                        I18n.tr("That's it! Lantern is now configured to automatically " +
                        "give you access to the open internet.<br><br>" +
                        "You may need to restart your browser."));
                    
                    replace.put("run_now", I18n.tr("Run Lantern Now?"));
                    replace.put("finish_string", I18n.tr("Finish"));
                    
                    setUrl("installFinishedCensored.html", replace);
                } else if (location.contains("loginUncensored")) {
                    final String args = 
                        StringUtils.substringAfter(location, "&");
                    if (StringUtils.isBlank(args)) {
                        log.error("Weird location: {}", location);
                        return;
                    }
                    final String email = 
                        StringUtils.substringBetween(location, "&email=", "&");
                    final String pwd = 
                        StringUtils.substringAfter(location, "&pwd=");
                    
                    try {
                        // TODO: We should just do a simple login instead
                        // of this persistent lookup here.
                        final String contactsDiv = contactsDiv(email, pwd, 1);
                        final Map<String, String> replace = 
                            new HashMap<String, String>();
                        replace.put("lead_string", 
                            I18n.tr("Welcome to Lantern! You're almost done."));
                        replace.put("title_string", 
                            I18n.tr("Complete Your Installation"));
                        replace.put("body_string", I18n.tr("That's it! You're now set up to share your uncensored connection "+ 
                        "with those who need it. Thanks for contributing to the global fight against censorship!"));
                        replace.put("run_now", I18n.tr("Run Lantern Now?"));
                        replace.put("finish_string", I18n.tr("Finish"));
                        setUrl("installFinishedUncensored.html", replace);
                    } catch (final IOException e) {
                        log.warn("Error accessing contacts", e);
                        final Map<String, String> replace = install1Uncensored();
                        replace.put("error_message", 
                            I18n.tr("Error logging in. E-mail or password incorrect?"));
                        setUrl("install1Uncensored.html", replace);
                    }
                } else if (location.contains("loginCensored")) {
                    final String args = 
                        StringUtils.substringAfter(location, "&");
                    if (StringUtils.isBlank(args)) {
                        log.error("Weird location: {}", location);
                        return;
                    }
                    final String email = 
                        StringUtils.substringBetween(location, "&email=", "&");
                    final String pwd = 
                        StringUtils.substringAfter(location, "&pwd=");
                    
                    try {
                        final String contactsDiv = contactsDiv(email, pwd, 5);
                        final Map<String, String> replace = 
                            new HashMap<String, String>();
                        replace.put("lead_string", 
                            I18n.tr("Welcome to Lantern! You're almost done."));
                        replace.put("title_string", I18n.tr("Complete Your Installation"));
                        replace.put("contacts_div", contactsDiv);
                        replace.put("text_body", I18n.tr(
                            "Please select your <b>trusted</b> friends below to " +
                            "send them a request to join your Lantern network. " +
                            "These friends will serve as especially trusted " +
                            "access points to the open internet."));
                        replace.put("select_all", I18n.tr("Select All"));
                        replace.put("clear_all", I18n.tr("Clear"));
                        replace.put("approve", I18n.tr("Approve these Contacts"));
                        setUrl("install2Censored.html", replace);
                    } catch (final IOException e) {
                        log.warn("Error accessing contacts", e);
                        final Map<String, String> replace = install1Censored();
                        replace.put("error_message", 
                            I18n.tr("Error logging in. E-mail or password incorrect?"));
                        setUrl("install1Censored.html", replace);
                    }
                } else if (location.contains("finished")) {
                    log.info("Got finished...closing on location: {}", location);
                    final String elements = 
                        StringUtils.substringAfter(location, "finished");
                    if (isConfig) {
                        LanternHub.configurator().reconfigure();
                    }
                    LanternHub.settings().getSettings().setState(State.SET);
                    LanternHub.settingsIo().write();
                    if (StringUtils.isNotBlank(elements)) {
                        log.info("Got elements: {}", elements);
                        try {
                            String decoded = 
                                URLDecoder.decode(elements, "UTF-8");
                            if (decoded.startsWith("?")) {
                                decoded = decoded.substring(1);
                            }
                            log.info("Decoded: {}", decoded);
                            // This means the user hasn't checked the checkbox
                            // to run Lantern now.
                            if (StringUtils.isBlank(decoded)) {
                                exit();
                            }
                            final String[] args = decoded.split("&");
                            for (final String arg : args) {
                                final String name = StringUtils.substringBefore(arg, "=");
                                final String val = StringUtils.substringAfter(arg, "=");
                                if (name.equals("runNow")) {
                                    if (LanternUtils.isTrue(val)) {
                                        // Just pass through -- we're all good.
                                    } else {
                                        exit();
                                    }
                                }
                            }
                        } catch (final UnsupportedEncodingException e) {
                            log.error("Encoding?", e);
                        }
                    }
                    close();
                } else {
                    defaultPage(location);
                }
                event.doit = false;
            }
        });
        
        shell.open();
        shell.forceActive();
        while (!shell.isDisposed()) {
            if (!this.display.readAndDispatch())
                this.display.sleep();
        }
    }
    
    protected Map<String, String> install1Censored() {
        final Map<String, String> replace = 
            new HashMap<String, String>();
        replace.put("lead_string", 
            I18n.tr("Welcome to Lantern! You're almost done."));
        replace.put("title_string", I18n.tr("Complete Your Installation"));
        replace.put("body_string", I18n.tr(
            "Lantern uses your friends as your personal access points to the open internet. "+
            "The more access points you have, the better your experience will be, so we encourage you to "+
            "invite your <b>most trusted friends</b> to use Lantern. "+
            "<br/><br/> "+

            "Provide your Gmail login below to select your trusted Gmail contacts. "+
            "We need this because Lantern uses Gmail to build its trust network. We don't store any "+ 
            "of this information - <b>it's stored only on your own computer, and you log in securely over SSL</b>."));
        
        replace.put("user_name_password", I18n.tr("<b>Please enter your user name and password from</b>"));
        replace.put("gmail_user_name", I18n.tr("Gmail E-mail Address"));
        replace.put("gmail_password", I18n.tr("Gmail Password"));
        replace.put("show_contacts", I18n.tr("Show My Contacts"));
        return replace;
    }

    protected Map<String, String> install1Uncensored() {
        final Map<String, String> replace = 
            new HashMap<String, String>();
        replace.put("lead_string", 
            I18n.tr("Welcome to Lantern! You're almost done."));
        replace.put("title_string", I18n.tr("Complete Your Installation"));
        replace.put("body_string", I18n.tr(
            "Lantern allows Lantern users living in censored to access the open internet through your computer "+
            "when you're not using it, creating a cooperative global network to combat censorship. "+
            "We make these connections using your GMail contacts, and this is how we know it's you. "+
            "We do not store your password on our servers, although we do store your e-mail "+
            "because we need it to connect you to other users. <b>We will never send you e-mail or "+
            "provide your e-mail to any third party, and your login happens securely over SSL.</b>"));
        replace.put("user_name_password", I18n.tr("<b>Please enter your user name and password from</b>"));
        replace.put("gmail_user_name", I18n.tr("Gmail E-mail Address"));
        replace.put("gmail_password", I18n.tr("Gmail Password"));
        return replace;
    }

    protected void exit() {
        cleanup();
        if (!isConfig) {
            display.dispose();
            System.exit(1);
        }
    }
    
    protected void defaultPage(final String location) {
        final String page = StringUtils.substringAfterLast(location, "/");
        final Map<String, String> replace = new HashMap<String, String>();
        replace.put("lead_string", 
            I18n.tr("Welcome to Lantern! You're almost done."));
        replace.put("title_string", I18n.tr("Complete Your Installation"));
        setUrl(page, replace);
    }

    /*
    protected void setUrl(final String page) {
        final File defaultFile = new File(tmp, page);
        setUrl(defaultFile);
    }
    
    protected void setUrl(final File file) {
        setUrl(file, "error_message", "");
    }
    
    private void setUrl(final File file, final String key, final String val) {
        final Map<String, String> map = new HashMap<String, String>();
        map.put(key, val);
        setUrl(file, map);
    }
    */
    protected void setUrl(final String fileName, final Map<String, String> map) {
        if (!map.containsKey("error_message")) {
            map.put("error_message", "");
        }
        map.put("installation_title", I18n.tr("Lantern Installation"));
        final File defaultFile = new File(tmp, fileName);
        setUrl(defaultFile, map);
    }
    
    protected void setUrl(final File file, final Map<String, String> map) {
        String copyStr;
        try {
            copyStr = IOUtils.toString(new FileInputStream(file), "UTF-8");
        } catch (final IOException e) {
            log.error("Could not read file to string?", e);
            return;
        }
        final Set<Entry<String, String>> entries = map.entrySet();
        for (final Entry<String, String> entry : entries) {
            final String key = entry.getKey();
            final String val = entry.getValue();
            copyStr = copyStr.replace(key, val);
        }
        
        final String name = 
            StringUtils.substringBefore(file.getName(), ".html") + "-copy.html";
        final File copy = new File(file.getParentFile(), name);
        OutputStream os = null;
        try {
            os = new FileOutputStream(copy);
            os.write(copyStr.getBytes("UTF-8"));
        } catch (final IOException e) {
            log.error("Could not write new file?", e);
        } finally {
            IOUtils.closeQuietly(os);
        }

        final String url = copy.toURI().toASCIIString();
        final String parsed = url.replace("file:/", "file:///");
        log.info("Setting url to: {}", parsed);
        browser.setUrl(parsed);
    }

    private File createTempDirectory() throws IOException {
        final File temp = 
            File.createTempFile("temp", Long.toString(System.nanoTime()));
        if (!(temp.delete())) {
            throw new IOException("Could not delete temp file: "
                    + temp.getAbsolutePath());
        }
        if (!(temp.mkdir())) {
            throw new IOException("Could not create temp directory: "
                    + temp.getAbsolutePath());
        }
        return (temp);
    }

    public void close() {
        this.closed = true;
        display.syncExec(new Runnable() {
            @Override
            public void run() {
                shell.dispose();
                cleanup();
            }
        });
    }

    protected void cleanup() {
        if (tmp == null || !tmp.isDirectory()) {
            log.info("Nothing to cleanup");
            return;
        }
        try {
            FileUtils.deleteDirectory(tmp);
        } catch (final IOException e) {
            log.error("Error deleting tmp dir", e);
        }
    }
    
    private String contactsDiv(final String rawEmail, final String pwd, 
        final int attempts) throws IOException {
        log.info("Creating contacts with {} retries", attempts);
        if (StringUtils.isBlank(rawEmail)) {
            throw new IOException("Please enter an e-mail address.");
        }
        if (StringUtils.isBlank(pwd)) {
            throw new IOException("Please enter a password.");
        }
        final String email;
        if (!rawEmail.contains("@")) {
            email = rawEmail + "@gmail.com";
        } else {
            email = rawEmail;
        }
        final Collection<LanternPresence> entries;
        try {
            entries = LanternUtils.getRosterEntries(email, pwd, attempts);
        } catch (final IOException e) {
            final String str = "Error logging in. Are you sure you "
                    + "entered the correct user name and password?";
            // sendError(response, str);
            throw e;
        }

        LanternUtils.writeCredentials(email, pwd);
        final TrustedContactsManager trustManager = 
            LanternHub.getTrustedContactsManager();
        final StringBuilder sb = new StringBuilder();
        sb.append("<div id='contacts'>\n");
        int index = 0;
        for (final LanternPresence entry : entries) {
            final String name;
            final String entryName  = entry.getName();
            log.info("Got entry name: '{}'", entryName);
            if (StringUtils.isBlank(entryName)) {
                name = entry.getEmail();
            } else {
                name = entryName;
            }
            final String user = entry.getEmail();
            final boolean trusted = trustManager.isTrusted(user.trim());
            final String evenOrOdd;
            if (index % 2 == 0) {
                evenOrOdd = "even";
            } else {
                evenOrOdd = "odd";
            }
            sb.append("<div class='contactDiv ");
            sb.append(evenOrOdd);
            sb.append("'>");
            sb.append("<span class='contactName'>");
            sb.append(name);
            sb.append("</span><input type='checkbox' name='");
            sb.append(user);
            sb.append("' class='contactCheck' ");
            if (trusted) {
                sb.append(" checked='true'");
            }
            sb.append("/>");
            sb.append("</div>\n");
            sb.append("<div style='clear: both'></div>\n");
            index++;
        }

        sb.append("</div>\n");
        return sb.toString();
    }
}
