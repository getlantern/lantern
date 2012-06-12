package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.util.Arrays;
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

    protected void exit() {
        cleanup();
        if (!isConfig) {
            display.dispose();
            System.exit(1);
        }
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
}
