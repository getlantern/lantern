package org.lantern.linux;

import com.sun.jna.Callback;
import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Pointer;

public interface Glib extends Library {
    Pointer g_main_context_new();
    Pointer g_main_loop_new(Pointer context, int is_running);
    void g_main_loop_run(Pointer main_loop);
}
