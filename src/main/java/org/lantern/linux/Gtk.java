package org.lantern.linux;

import com.sun.jna.Callback;
import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Pointer;

public interface Gtk extends Library {
    
    public static final int FALSE = 0;
    public static final int TRUE = 1;
   
    public void gtk_init(int argc, String[] argv);
    public void gtk_main();
    public Pointer gtk_menu_new();
    public Pointer gtk_menu_item_new_with_label(String label);
    public void gtk_menu_item_set_label(Pointer menu_item, String label);
    public void gtk_menu_shell_append(Pointer menu_shell, Pointer child);
    public void gtk_widget_set_sensitive(Pointer widget, int sesitive);
    public void gtk_widget_show_all(Pointer widget);
}

