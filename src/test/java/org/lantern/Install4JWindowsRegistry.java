package org.lantern;

import org.lantern.win.WindowsRegistry;

import com.install4j.api.windows.RegistryRoot;
import com.install4j.api.windows.WinRegistry;

public class Install4JWindowsRegistry implements WindowsRegistry {

    @Override
    public boolean writeREG_SZ(final String key, final String name, 
        final String value) {
        return WinRegistry.setValue(
            RegistryRoot.HKEY_CURRENT_USER, key, name, value);
    }

    @Override
    public Object readValue(final String key, final String name) {
        return WinRegistry.getValue(RegistryRoot.HKEY_CURRENT_USER, key, name);
    }

}
