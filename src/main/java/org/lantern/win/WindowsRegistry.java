package org.lantern.win;


public interface WindowsRegistry {

    Object readValue(String key, String name);
    
    boolean writeREG_SZ(String key, String name, String value);
}
