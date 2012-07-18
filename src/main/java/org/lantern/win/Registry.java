package org.lantern.win;

import org.littleshoot.util.WindowsRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.sun.jna.platform.win32.Advapi32Util;
import com.sun.jna.platform.win32.Win32Exception;
import com.sun.jna.platform.win32.WinReg;

/**
 * Registry helper class that uses various fallback methods to access the 
 * registry. This only accesses HKEY_CURRENT_USER because non-admin accounts
 * cannot read and write to anything else. It's therefore not necessary to
 * include the root key in any of these calls.
 */
public class Registry {
    
    private static final Logger LOG = LoggerFactory.getLogger(Registry.class);
    
    public static String read(final String key, final String name) {
        try {
            return Advapi32Util.registryGetStringValue(WinReg.HKEY_CURRENT_USER, 
                key, name);
        } catch (final Win32Exception e) {
            LOG.error("Cannot write to  using JNA", e);
            return readWithCommandReg(key, name);
        }
    }
    
    private static String readWithCommandReg(final String key, 
        final String name) {
        return WindowsRegistry.read("HKCU\\"+key, name);
    }

    public static int readInt(final String key, final String name) {
        try {
            return Advapi32Util.registryGetIntValue(WinReg.HKEY_CURRENT_USER, 
                key, name);
        } catch (final Win32Exception e) {
            LOG.error("Cannot write to  using JNA", e);
            return Integer.parseInt(readWithCommandReg(key, name));
        }
    }
    
    public static boolean write(final String key, final String name, 
        final String value) {
        try {
            Advapi32Util.registrySetStringValue(WinReg.HKEY_CURRENT_USER, key, 
                name, value);
            return true;
        
        } catch (final Win32Exception e) {
            LOG.error("Cannot write to  using JNA", e);
            return writeWithCommandReg(key, name, value);
        }
    }

    public static boolean write(final String key, final String name, 
        final Integer value) {
        try {
            Advapi32Util.registrySetIntValue(WinReg.HKEY_CURRENT_USER, key, 
                name, value);
            return true;
        
        } catch (final Win32Exception e) {
            LOG.error("Cannot write to  using JNA", e);
            return writeWithCommandReg(key, name, value);
        }
    }
    
    
    private static boolean writeWithCommandReg(final String key, 
        final String name, final Integer value) {
        return writeWithCommandReg(key, name, value.toString());
    }
    
    private static boolean writeWithCommandReg(final String key, 
        final String name, final String value) {
        final int exit = 
            WindowsRegistry.write("HKCU\\"+key, name, value.toString());
        return exit == 0;
    }
}
