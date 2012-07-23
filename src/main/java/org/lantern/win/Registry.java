package org.lantern.win;

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
            LOG.error("Cannot write to registry using JNA "+key, e);
            return readWithCommandReg(key, name);
        }
    }
    
    private static String readWithCommandReg(final String key, 
        final String name) {
        return WindowsRegCommand.read("HKCU\\"+key, name);
    }

    public static int readInt(final String key, final String name) {
        try {
            return Advapi32Util.registryGetIntValue(WinReg.HKEY_CURRENT_USER, 
                key, name);
        } catch (final Win32Exception e) {
            LOG.error("Cannot write to registry using JNA "+key, e);
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
            LOG.error("Cannot write to registry using JNA "+key, e);
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
            LOG.error("Cannot write to registry using JNA "+key, e);
            return writeWithCommandReg(key, name, value);
        }
    }
    
    
    private static boolean writeWithCommandReg(final String key, 
        final String name, final Integer value) {
        final int exit = 
                WindowsRegCommand.writeREG_DWORD("HKCU\\"+key, name, value);
            final boolean succeeded = exit == 0;
            if (!succeeded) {
                LOG.warn("Could not write to reg with REG command either: "+key);
            } else {
                LOG.info("Successfully wrote ot registry with REG command");
            }
            return succeeded;
    }
    
    private static boolean writeWithCommandReg(final String key, 
        final String name, final String value) {
        final int exit = 
            WindowsRegCommand.writeREG_SZ("HKCU\\"+key, name, value);
        final boolean succeeded = exit == 0;
        if (!succeeded) {
            LOG.warn("Could not write to reg with REG command either: "+key);
        } else {
            LOG.info("Successfully wrote ot registry with REG command");
        }
        return succeeded;
    }
}
