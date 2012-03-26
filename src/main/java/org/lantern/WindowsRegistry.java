package org.lantern;

import java.io.IOException;
import java.io.InputStream;
import java.io.StringWriter;
import java.util.Scanner;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Utility class for reading from the registry.
 * 
 * Here's the documentation for adding entries:
 *  
 
  REG ADD KeyName [/v ValueName | /ve] [/t Type] [/s Separator] [/d Data] [/f]

  KeyName  [\\Machine\]FullKey
           Machine  Name of remote machine - omitting defaults to the
                    current machine. Only HKLM and HKU are available on remote
                    machines.
           FullKey  ROOTKEY\SubKey
           ROOTKEY  [ HKLM | HKCU | HKCR | HKU | HKCC ]
           SubKey   The full name of a registry key under the selected ROOTKEY.

  /v       The value name, under the selected Key, to add.

  /ve      adds an empty value name (Default) for the key.

  /t       RegKey data types
           [ REG_SZ    | REG_MULTI_SZ | REG_EXPAND_SZ |
             REG_DWORD | REG_QWORD    | REG_BINARY    | REG_NONE ]
           If omitted, REG_SZ is assumed.

  /s       Specify one character that you use as the separator in your data
           string for REG_MULTI_SZ. If omitted, use "\0" as the separator.

  /d       The data to assign to the registry ValueName being added.

  /f       Force overwriting the existing registry entry without prompt.

Examples:

  REG ADD \\ABC\HKLM\Software\MyCo
    Adds a key HKLM\Software\MyCo on remote machine ABC

  REG ADD HKLM\Software\MyCo /v Data /t REG_BINARY /d fe340ead
    Adds a value (name: Data, type: REG_BINARY, data: fe340ead)

  REG ADD HKLM\Software\MyCo /v MRU /t REG_MULTI_SZ /d fax\0mail
    Adds a value (name: MRU, type: REG_MULTI_SZ, data: fax\0mail\0\0)

  REG ADD HKLM\Software\MyCo /v Path /t REG_EXPAND_SZ /d ^%systemroot^%
    Adds a value (name: Path, type: REG_EXPAND_SZ, data: %systemroot%)
    Notice:  Use the caret symbol ( ^ ) inside the expand string
 */
public class WindowsRegistry {

    private static final Logger LOG = 
        LoggerFactory.getLogger(WindowsRegistry.class);
    
    /**
     * Reads the value of a registry key.
     * 
     * @param key The registry key to query.
     * @param valueName Name of the registry value.
     * @param valueData The data for the value name.
     * @return registry value or the empty string if not found.
     */
    public static final int writeREG_SZ(final String key, 
        final String valueName, final String valueData) {
        return write(key, valueName, valueData, "REG_SZ");
    }
    
    /**
     * Reads the value of a registry key.
     * 
     * @param key The registry key to query.
     * @param valueName Name of the registry value.
     * @param valueData The data for the value name.
     * @return registry value or the empty string if not found.
     */
    public static final int writeREG_DWORD(final String key, 
        final String valueName, final String valueData) {
        return write(key, valueName, valueData, "REG_DWORD");
    }
    
    /**
     * Writes to the specified registry key.
     * 
     * @param key The registry key to query.
     * @param valueName Name of the registry value.
     * @param valueData The data for the value name.
     * @param type The type of data.
     * @return registry value or the empty string if not found.
     */
    private static final int write(final String key, 
        final String valueName, final String valueData, final String type) {
        
        // Setting something to the pure empty string will cause this to hang,
        // so we just write a single space.
        final String finalValue;
        if (valueData.isEmpty()) {
            finalValue = " ";
        }
        else {
            finalValue = valueData;
        }
        final ProcessBuilder pb = 
            new ProcessBuilder("reg", "add", "\""+ key + "\"", "/v", 
                valueName, "/t", type, "/d", finalValue, "/f");
        pb.redirectErrorStream(true);
        try {
            final Process process = pb.start();
            
            final InputStream is = process.getInputStream();
            final StringWriter sw = new StringWriter();;
            final Runnable runner = new Runnable() {
                @Override
                public void run() {
                    try {
                        int c;
                        while ((c = is.read()) != -1) {
                            sw.write(c);
                        }
                    }
                    catch (final IOException e) { 
                        LOG.error("Error reading reg with key '"+key+
                            "' and val '"+ valueName+"'", e);
                    }
                }
            };
            final Thread t = new Thread(runner, "Registry-Reading-Thread");
            t.setDaemon(true);
            t.start();
            final int result = process.waitFor();
            t.join();
            final String output = sw.toString();
            if (output.startsWith("ERROR")) {
                LOG.error("GOT ERROR FROM NATIVE REG CALL FOR KEY '"+key+
                    "':\n"+output);
            }
            //System.out.println("WRITE OUTPUT:\n"+output);
            return result;
        } catch (IOException e) {
            e.printStackTrace();
            LOG.error("Error writing to registry", e);
        } catch (InterruptedException e) {
            e.printStackTrace();
            LOG.error("Error writing to registry", e);
        }
        LOG.info("Registry call failed -- should have reported error");
        return 1;
    }
    
    /**
     * Reads the value of a registry key.
     * 
     * @param key The registry key to query.
     * @param valueName Name of the registry value.
     * @return registry value or the empty string if not found.
     */
    public static final String read(final String key, 
        final String valueName) {
        
        try {
            final Process process = Runtime.getRuntime().exec("reg query " + 
                "\""+ key + "\" /v " + valueName);
            
            final InputStream is = process.getInputStream();
            final StringWriter sw = new StringWriter();;
            final Runnable runner = new Runnable() {
                @Override
                public void run() {
                    try {
                        int c;
                        while ((c = is.read()) != -1) {
                            sw.write(c);
                        }
                    }
                    catch (final IOException e) { 
                        LOG.error("Error reading reg with key '"+key+
                            "' and val '"+ valueName+"'", e);
                    }
                }
            };
            final Thread t = new Thread(runner, "Registry-Reading-Thread");
            t.setDaemon(true);
            t.start();
            process.waitFor();
            t.join();
            final String output = sw.toString();
            
            // This seems like slight overkill, but we want to handle generic
            // whitespace separators to accommodate OS-specific differences.
            final Scanner scan = new Scanner(output);
            String type = "";
            String value = "";
            while (scan.hasNext()) {
                type = value;
                value = scan.next().trim();
            }
            
            // If the value is a registry type, it means it's empty (there is
            // no last token). Just return the empty string.
            if (value.startsWith("REG_")) {
                return "";
            }
            
            // Do auto-conversion from hex.
            if (type.equals("REG_DWORD")) {
                final String parsed;
                if (value.startsWith("0x")) {
                    parsed = value.substring(2);
                }
                else {
                    parsed = value;
                }
                final long longValue = Long.parseLong(parsed, 16);
                return String.valueOf(longValue);
            }
            return value.trim();
        } catch (final IOException e) {
            LOG.error("Error reading reg with key '"+key+"' and val '"+
                valueName+"'", e);
            return "";
        } catch (final InterruptedException e) {
            LOG.error("Error reading reg with key '"+key+"' and val '"+
                valueName+"'", e);
            return "";
        }
    }

    /*
    public static void main(String[] args) {
        final String key = 
            "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\" +
            "Internet Settings";
        
        final String ps = "ProxyServer";
        final String pe = "ProxyEnable";
        
        String value = WindowsRegistry.read(key, "ProxyServer");
        System.out.println("'"+value+"'");
        
        String val = WindowsRegistry.read(key, "ProxyEnable");
        System.out.println("'"+val+"'");
        
        
        int result = WindowsRegistry.writeREG_DWORD(key, "ProxyEnableTest", "11");
        System.out.println(result);
        
        val = WindowsRegistry.read(
            "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\"  + 
            "Internet Settings", "ProxyEnableTest");
        System.out.println("'"+val+"'");
        
        System.out.println("Setting proxy server to empty string!!");
        WindowsRegistry.writeREG_SZ(key, ps, " ");
        System.out.println("DONE!!");
        
    }
    */
}