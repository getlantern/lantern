package org.lantern;

import static org.junit.Assert.assertTrue;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileFilter;
import java.io.FileReader;
import java.io.FileWriter;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.junit.Ignore;
import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Ignore
public class ResourceBundleTest {

    private final Logger log = LoggerFactory.getLogger(getClass());

    @Test
    public void convertBasePo() throws Exception {
        final File po = new File("po/en.po");
        final File rb =
            new File("src/main/resources/LanternResourceBundle.properties");

        final BufferedWriter bw = new BufferedWriter(new FileWriter(rb));
        final BufferedReader br = new BufferedReader(new FileReader(po));
        String line = br.readLine();
        while (line != null) {
            System.out.println(line);
            if (line.startsWith("msgid")) {
                final String startLine = StringUtils.substringBetween(line, "\"", "\"");
                line = startLine;
                String valLine = br.readLine();
                if (valLine == null) {
                    log.warn("no msgstr for msgid " + line);
                    //end of file, so break
                    break;
                }
                while (!valLine.startsWith("msgstr")) {
                    //line += "\n";
                    line += StringUtils.substringBetween(valLine, "\"", "\"");
                    valLine = br.readLine();
                }
                final String key = line.replaceAll(" ", "_");
                String trans = StringUtils.substringBetween(valLine, "\"", "\"");;
                valLine = br.readLine();
                while (valLine != null && valLine.trim().startsWith("\"")) {
                    trans += StringUtils.substringBetween(valLine, "\"", "\"");
                    valLine = br.readLine();
                }
                if (trans.trim().length() == 0) {
                    trans = line;
                }
                //final String value = StringUtils.substringBetween(valLine, "\"", "\"");
                final int length = Math.min(key.length(), LanternConstants.I18N_KEY_LENGTH);
                final String normalizedKey = key.substring(0, length);
                final String full = normalizedKey + "=" + trans+"\n";

                // Ignore it if it's the initial configuration line.
                if (!normalizedKey.isEmpty()) {
                    bw.write(full);
                }
            }
            line = br.readLine();
        }
        bw.close();
        br.close();
        final String text = IOUtils.toString(new FileReader(rb));
        assertTrue(text.contains("You_appear_to_be_r") && text.contains("You appear to be r"));
    }

    @Test
    public void convertPos() throws Exception {
        final File[] pos = new File("po").listFiles(new FileFilter() {

            @Override
            public boolean accept(final File pathname) {
                final String name = pathname.getName();
                return name.endsWith("po") && !name.equals("en.po") && !name.equals("zh.po");
            }
        });
        for (final File po : pos) {
            final String name = po.getName();
            final String localName =
                StringUtils.substringBeforeLast(name, ".po");
            final File dir = new File("src/main/resources");
            final File rb = new File(dir, "LanternResourceBundle_"+localName+".properties");
            convertPo(po, rb);
            final String text = IOUtils.toString(new FileReader(rb));
            assertTrue("Expected text not in: "+rb, text.contains("You_appear_to_be_r"));
        }
    }

    private void convertPo(final File po, final File rb) throws Exception {

        final BufferedWriter bw = new BufferedWriter(new FileWriter(rb));
        final BufferedReader br = new BufferedReader(new FileReader(po));
        String line = br.readLine();
        while (line != null) {
            System.out.println(line);
            if (line.startsWith("msgid")) {
                final String startLine = StringUtils.substringBetween(line, "\"", "\"");
                line = startLine;
                String valLine = br.readLine();
                while (!valLine.startsWith("msgstr")) {
                    //line += "\n";
                    line += StringUtils.substringBetween(valLine, "\"", "\"");
                    valLine = br.readLine();
                }
                //final String prelimKey = StringUtils.substringBetween(line, "\"", "\"");//StringUtils.substringAfter(line, "msgid ");
                final String key = line.replaceAll(" ", "_");
                String trans = StringUtils.substringBetween(valLine, "\"", "\"");
                valLine = br.readLine();
                while (valLine != null && valLine.trim().startsWith("\"")) {
                    //line += "\n";
                    trans += StringUtils.substringBetween(valLine, "\"", "\"");
                    valLine = br.readLine();
                }
                //final String value = StringUtils.substringBetween(valLine, "\"", "\"");
                final int length = Math.min(key.length(), LanternConstants.I18N_KEY_LENGTH);
                final String normalizedKey = key.substring(0, length);
                log.info("KEY: "+normalizedKey);
                final String full = normalizedKey + "=" + trans+"\n";

                // Ignore it if it's the initial configuration line.
                if (!normalizedKey.isEmpty()) {
                    bw.write(full);
                }
            }
            line = br.readLine();
        }
        bw.close();
        br.close();
    }
}
