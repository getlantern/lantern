package org.lantern;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.util.Enumeration;
import java.util.ResourceBundle;

import org.apache.commons.lang.StringUtils;
import org.junit.Test;


public class ResourceBundleTest {

    public class PoFileResourceBundle extends ResourceBundle {

        @Override
        protected Object handleGetObject(final String key) {
            // TODO Auto-generated method stub
            return null;
        }

        @Override
        public Enumeration<String> getKeys() {
            // TODO Auto-generated method stub
            return null;
        }
        
    }
    
    @Test public void convertBasePo() throws Exception {
        final File po = new File("po/en.po");
        final File rb = new File("resourcebundle_en");
        
        final BufferedWriter bw = new BufferedWriter(new FileWriter(rb));
        final BufferedReader br = new BufferedReader(new FileReader(po));
        String line = br.readLine();
        while (line != null) {
            System.out.println(line);
            if (line.startsWith("#")) {
            }
            if (StringUtils.isBlank(line)) {
            }
            if (line.startsWith("msgid")) {
                line = StringUtils.substringBetween(line, "\"", "\"");
                String valLine = br.readLine();
                while (!valLine.startsWith("msgstr")) {
                    //line += "\n";
                    line += StringUtils.substringBetween(valLine, "\"", "\"");
                    valLine = br.readLine();
                }
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
                final String full = key.substring(0, length) + "=" + line+"\n";
                bw.write(full);
            }
            line = br.readLine();
        }
        bw.close();
        br.close();
    }
    
    @Test public void convertPo() throws Exception {
        final File po = new File("po/zh.po");
        final File rb = new File("resourcebundle_zh");
        
        final BufferedWriter bw = new BufferedWriter(new FileWriter(rb));
        final BufferedReader br = new BufferedReader(new FileReader(po));
        String line = br.readLine();
        while (line != null) {
            System.out.println(line);
            if (line.startsWith("#")) {
            }
            if (StringUtils.isBlank(line)) {
            }
            if (line.startsWith("msgid")) {
                line = StringUtils.substringBetween(line, "\"", "\"");
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
                final String full = key.substring(0, length) + "=" + trans+"\n";
                bw.write(full);
            }
            line = br.readLine();
        }
        bw.close();
        br.close();
    }
}
