package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.util.Arrays;
import java.util.Collection;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.eclipse.swt.SWT;
import org.eclipse.swt.browser.Browser;
import org.eclipse.swt.browser.LocationAdapter;
import org.eclipse.swt.browser.LocationEvent;
import org.eclipse.swt.graphics.Rectangle;
import org.eclipse.swt.widgets.Display;
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

    public LanternBrowser() {
        Display.setAppName("Lantern");
        this.display = new Display();
        //
        this.shell = new Shell(display);
        // this.shell = createShell(this.display);
        this.shell.setText("Lantern Installation");
        this.shell.setSize(720, 540);
        // shell.setFullScreen(true);

        final Monitor primary = this.display.getPrimaryMonitor();
        final Rectangle bounds = primary.getBounds();
        final Rectangle rect = shell.getBounds();

        final int x = bounds.x + (bounds.width - rect.width) / 2;
        final int y = bounds.y + (bounds.height - rect.height) / 2;

        shell.setLocation(x, y);

        this.browser = new Browser(shell, SWT.NONE);
        // browser.setSize(700, 500);
        browser.setBounds(0, 0, 700, 560);
        // browser.setBounds(5, 75, 600, 400);

    }
    public void install() {
        final File srv = new File("srv");
        final File tmp;
        try {
            tmp = createTempDirectory();
            FileUtils.copyDirectory(srv, tmp);
        } catch (final IOException e) {
            log.error("Could not copy to temp dir", e);
            return;
        }
        log.info("tmp files: "+Arrays.asList(tmp.listFiles()));
        
        final String startFile;
        if (LanternUtils.isCensored()) {
            startFile = "install0Censored.html";
        } else {
            startFile = "install0Uncensored.html";
        }
        final File file = new File(tmp, startFile).getAbsoluteFile();
        final String url = file.toURI().toASCIIString();
        log.info("Setting url to:\n{}", url);
        
        browser.setUrl(url);
        browser.addLocationListener(new LocationAdapter() {
            public void changing(final LocationEvent event) {
                final String location = event.location;
                log.info("Got location: {}", location);
                if (location.endsWith("-copy.html")) {
                    return;
                }
                if (location.contains("loginUncensored")) {
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
                        final String contactsDiv = contactsDiv(email, pwd);
                        //browser.setText(contactsDiv, true);
                        final File file = 
                            new File(tmp, "installFinishedUncensored.html").getAbsoluteFile();
                        browser.setUrl(file.toURI().toASCIIString());
                        
                    } catch (final IOException e) {
                        log.warn("Error accessing contacts", e);
                        final File file = 
                            new File(tmp, "install1Uncensored.html");
                        
                        setUrl(file, "error_message", 
                            "Error logging in. E-mail or password incorrect?");
                    }
                } else if (location.contains("finished")) {
                    close();
                } else {
                    final String page = StringUtils.substringAfterLast(location, "/");
                    //log.info("Page: "+page);
                    final File file = new File(tmp, page);
                    setUrl(file, "error_message", "");
                }
                event.doit = false;
                //final File file = new File("srv/"+location).getAbsoluteFile();
                //browser.setUrl(file.toURI().toASCIIString());
                //event.doit = false;
            }
        });
        
        shell.open();
        //browser.setUrl("http://127.0.0.1:8383/install1.html");
        //browser.setUrl(LanternConstants.BASE_URL+"/install1?key="+
        //    LanternUtils.keyString());
        while (!shell.isDisposed()) {
            if (!this.display.readAndDispatch())
                this.display.sleep();
        }
        this.display.dispose();
    }

    protected void setUrl(final File file, final String token, 
        final String replacement) {
        String copyStr;
        try {
            copyStr = IOUtils.toString(new FileInputStream(file), "UTF-8");
        } catch (final IOException e2) {
            log.error("Could not read file to string?", e2);
            return;
        }
        //System.out.println("COPY: "+copyStr);
        copyStr = copyStr.replaceAll(token, replacement);
        
        final String name = 
            StringUtils.substringBefore(file.getName(), ".html") + "-copy.html";
        final File copy = new File(file.getParentFile(), name);
        FileWriter fw = null;
        try {
            fw = new FileWriter(copy);
            fw.write(copyStr);
        } catch (final IOException e1) {
            log.error("Could not write new file?", e1);
        } finally {
            IOUtils.closeQuietly(fw);
        }
        //FileUtils.copyFile(file, copy);
        browser.setUrl(copy.toURI().toASCIIString());
    }
    
    public void install2() {
        final File srv = new File("srv");
        File tmp;
        try {
            tmp = createTempDirectory();
            FileUtils.copyDirectory(srv, tmp);
        } catch (final IOException e) {
            log.error("Could not copy to temp dir", e);
        }
        final String startFile;
        if (LanternUtils.isCensored()) {
            startFile = "srv/install0Censored.html";
        } else {
            startFile = "srv/install0Uncensored.html";
        }
        final File file = new File(startFile).getAbsoluteFile();
        
        InputStream is = null;
        try {
            is = new FileInputStream(file);
            final String txt = IOUtils.toString(is, "UTF-8");
            final String baseDir = new File(".").getCanonicalFile().toURI().toASCIIString();
            final String baseHref = baseDir.replace("file:", "file://");
            final String str = txt.replaceAll("base_href", baseHref);
            browser.setText(str);
        } catch (final IOException e2) {
            // TODO Auto-generated catch block
            e2.printStackTrace();
        } finally {
            IOUtils.closeQuietly(is);
        }

        //browser.setUrl(file.toURI().toASCIIString());
        browser.addLocationListener(new LocationAdapter() {
            public void changing(final LocationEvent event) {
                final String location = event.location;
                log.info("Got location: {}", location);
                
                if (location.contains("srv/login")) {
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
                        final String contactsDiv = contactsDiv(email, pwd);
                        //browser.setText(contactsDiv, true);
                    } catch (final IOException e) {
                        log.warn("Error accessing contacts", e);
                    }
                    
                    final File file = new File("srv/installFinishedUncensored.html").getAbsoluteFile();
                    browser.setUrl(file.toURI().toASCIIString());
                    event.doit = false;
                } else if (location.contains("srv/finished")) {
                    close();
                }
                //final File file = new File("srv/"+location).getAbsoluteFile();
                //browser.setUrl(file.toURI().toASCIIString());
                //event.doit = false;
            }
        });
        /*
        new BrowserFunction(browser, "javaFunc") {
            
            @Override 
            public Object function (final Object[] arguments) {
                System.out.println ("theJavaFunction() called from javascript with args:");
                //int z = 3 / 0; // uncomment to cause a java error instead
                return new Object[] {};
            }
        };
        */
        shell.open();
        //browser.setUrl("http://127.0.0.1:8383/install1.html");
        //browser.setUrl(LanternConstants.BASE_URL+"/install1?key="+
        //    LanternUtils.keyString());
        while (!shell.isDisposed()) {
            if (!this.display.readAndDispatch())
                this.display.sleep();
        }
        this.display.dispose();
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
        display.syncExec(new Runnable() {
            public void run() {
                shell.dispose();
            }
        });
    }

    private String contactsDiv(final String email, final String pwd)
            throws IOException {
        if (StringUtils.isBlank(email)) {
            // sendError(response, "Please enter a valid e-mail address.");
        }
        if (StringUtils.isBlank(pwd)) {
            // sendError(response, "Please enter a valid password.");
        }
        final Collection<RosterEntry> entries;
        try {
            entries = LanternUtils.getRosterEntries(email, pwd);
        } catch (final IOException e) {
            final String str = "Error logging in. Are you sure you "
                    + "entered the correct user name and password?";
            // sendError(response, str);
            throw e;
        }

        final StringBuilder sb = new StringBuilder();
        sb.append("<div id='contacts'>\n");
        for (final RosterEntry entry : entries) {
            final String name = entry.getName();
            if (StringUtils.isBlank(name)) {
                continue;
            }
            final String user = entry.getUser();
            final String line = "<span class='contactName'>" + name
                    + "</span><input type='checkbox' name='" + user
                    + "' class='contactCheck'/>";
            sb.append("<div>");
            sb.append(line);
            sb.append("</div>\n");
            sb.append("<div style='clear: both'>");
            sb.append("</div>\n");
        }

        sb.append("</div>\n");
        return sb.toString();
    }
}
