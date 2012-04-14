package org.lantern.linux;

import com.sun.jna.Callback;
import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Pointer;

public interface Gobject extends Library {
    
    public interface GCallback extends Callback {
        public void callback(Pointer instance, Pointer data);
    }
    
    public void g_signal_connect_data(Pointer instance, String detailed_signal, GCallback c_handler,
                                      Pointer data, Pointer destroy_data, int connect_flags);
}
