package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URLDecoder;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
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
import org.jivesoftware.smack.RosterEntry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class LanternBrowser {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private Shell shell;
    // private Display display;
    private Browser browser;

    private Display display;

    private File tmp;

    private boolean closed;

    private final boolean isConfig;

    public LanternBrowser(final boolean isConfig) {
        log.info("Creating Lantern browser...");
        this.display = LanternHub.display();
        this.isConfig = isConfig;
        
        log.info("Creating shell...");
        this.shell = new Shell(display);
        final Image small = newImage("16on.png");
        final Image medium = newImage("32on.png");
        final Image large = newImage("64on.png");
        final Image[] icons = new Image[]{small, medium, large};
        log.info("Setting images...");
        this.shell.setImages(icons);
        // this.shell = createShell(this.display);
        if (isConfig) {
            this.shell.setText("Configure Lantern");
        } else {
            this.shell.setText("Lantern Installation");
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
                    messageBox.setText ("Exit?");
                    messageBox.setMessage (
                        "Are you sure you want to ignore the update?");
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
        final String startFile;
        if (CensoredUtils.isCensored()) {
            startFile = "install0Censored.html";
        } else {
            startFile = "install0Uncensored.html";
        }
        shell.addListener (SWT.Close, new Listener () {
            @Override
            public void handleEvent(final Event event) {
                log.info("CLOSE EVENT: {}", event);
                if (!closed) {
                    final int style = SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.YES | SWT.NO;
                    final MessageBox messageBox = new MessageBox (shell, style);
                    messageBox.setText ("Exit?");
                    final String msg;
                    if (isConfig) {
                        msg = "Are you sure you want to cancel configuring Lantern?";
                    } else {
                        msg = "Are you sure you want to cancel installing Lantern?";
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
        
        final File file = new File(tmp, startFile).getAbsoluteFile();
        setUrl(file);

        browser.addLocationListener(new LocationAdapter() {
            @Override
            public void changing(final LocationEvent event) {
                final String location = event.location;
                log.info("Got location: {}", location);
                if (location.endsWith("-copy.html")) {
                    // This just means it's a request we've already prepared
                    // for serving. If we don't do this check, we'll get an
                    // infinite loop of copies.
                    log.info("Accepting copied location");
                    return;
                } else if (location.contains("install1Uncensored.html")) {
                    // The user could be re-configuring their system. Make sure
                    // force is no longer active.
                    if (!CensoredUtils.isCensored()) {
                        CensoredUtils.unforceCensored();
                    }
                    setUrl("install1Uncensored.html");
                } else if (location.contains("install1Censored.html")) {
                    // We use this to check if the user has selected to run
                    // in censored mode even if they don't appear to be in a
                    // censored country.
                    if (!CensoredUtils.isCensored()) {
                        CensoredUtils.forceCensored();
                    }
                    setUrl("install1Censored.html");
                } else if (location.contains("trustForm")) {
                    final String elements = 
                        StringUtils.substringAfter(location, "trustForm");
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
                            for (final String contact : contacts) {
                                final String email = StringUtils.substringBefore(contact, "=");
                                final String val = StringUtils.substringAfter(contact, "=");
                                if ("on".equalsIgnoreCase(val) || "true".equalsIgnoreCase(val)) {
                                    log.info("Adding contact: {}", email);
                                    tcm.addTrustedContact(email);
                                }
                            }
                        } catch (final UnsupportedEncodingException e) {
                            log.error("Encoding?", e);
                        }
                    }

                    final File finish = 
                        new File(tmp, "installFinishedCensored.html").getAbsoluteFile();
                    setUrl(finish);
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
                        LanternUtils.writeCredentials(email, pwd);
                        final File finish = 
                            new File(tmp, "installFinishedUncensored.html").getAbsoluteFile();
                        setUrl(finish);
                    } catch (final IOException e) {
                        log.warn("Error accessing contacts", e);
                        final File error = 
                            new File(tmp, "install1Uncensored.html");
                        
                        setUrl(error, "error_message", 
                            "Error logging in. E-mail or password incorrect?");
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
                        final File contacts = 
                            new File(tmp, "install2Censored.html").getAbsoluteFile();
                        LanternUtils.writeCredentials(email, pwd);
                        setUrl(contacts, "contacts_div", contactsDiv);
                        //browser.setUrl(finish.toURI().toASCIIString());
                        
                    } catch (final IOException e) {
                        log.warn("Error accessing contacts", e);
                        final File error = 
                            new File(tmp, "install1Censored.html");
                        
                        setUrl(error, "error_message", 
                            "Error logging in. E-mail or password incorrect?");
                    }
                } else if (location.contains("finished")) {
                    log.info("Got finished...closing on location: {}", location);
                    final String elements = 
                        StringUtils.substringAfter(location, "finished");
                    if (isConfig) {
                        Configurator.reconfigure();
                    }
                    LanternUtils.installed();
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
                                    if ("on".equalsIgnoreCase(val) || "true".equalsIgnoreCase(val)) {
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
    
    protected void exit() {
        cleanup();
        if (!isConfig) {
            display.dispose();
            System.exit(1);
        }
    }
    
    protected void defaultPage(final String location) {
        final String page = StringUtils.substringAfterLast(location, "/");
        setUrl(page);
    }

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
        FileWriter fw = null;
        try {
            fw = new FileWriter(copy);
            fw.write(copyStr);
        } catch (final IOException e) {
            log.error("Could not write new file?", e);
        } finally {
            IOUtils.closeQuietly(fw);
        }
        //FileUtils.copyFile(file, copy);
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
    
    private String contactsDiv(final String email, final String pwd, 
        final int attempts) throws IOException {
        log.info("Creating contacts with {} retries", attempts);
        if (StringUtils.isBlank(email)) {
            throw new IOException("Please enter an e-mail address.");
        }
        if (StringUtils.isBlank(pwd)) {
            throw new IOException("Please enter a password.");
        }
        final Collection<RosterEntry> entries;
        try {
            entries = LanternUtils.getRosterEntries(email, pwd, attempts);
        } catch (final IOException e) {
            final String str = "Error logging in. Are you sure you "
                    + "entered the correct user name and password?";
            // sendError(response, str);
            throw e;
        }

        final StringBuilder sb = new StringBuilder();
        sb.append("<div id='contacts'>\n");
        int index = 0;
        for (final RosterEntry entry : entries) {
            final String name = entry.getName();
            if (StringUtils.isBlank(name)) {
                continue;
            }
            final String user = entry.getUser();
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
            sb.append("' class='contactCheck'/></div>\n");
            sb.append("<div style='clear: both'></div>\n");
            index++;
        }

        sb.append("</div>\n");
        return sb.toString();
    }
}
