package org.lantern.linux;

import com.sun.jna.Library;
import com.sun.jna.Pointer;

public interface Unique extends Library {
    
    
    Pointer unique_app_new(String name, String startup_id);
    void unique_app_add_command(Pointer app, String command_name, int command_id);
    boolean unique_app_is_running(Pointer app);
    int unique_app_send_message(Pointer app, int command_id, Pointer message_data);
    
    /*
enum                UniqueCommand;
struct              UniqueApp;
struct              UniqueAppClass;
UniqueApp *         unique_app_new                      (const gchar *name,
                                                         const gchar *startup_id);
UniqueApp *         unique_app_new_with_commands        (const gchar *name,
                                                         const gchar *startup_id,
                                                         const gchar *first_command_name,
                                                         ...);
void                unique_app_add_command              (UniqueApp *app,
                                                         const gchar *command_name,
                                                         gint command_id);
void                unique_app_watch_window             (UniqueApp *app,
                                                         GtkWindow *window);
gboolean            unique_app_is_running               (UniqueApp *app);
enum                UniqueResponse;
UniqueResponse      unique_app_send_message             (UniqueApp *app,
                                                         gint command_id,
                                                         UniqueMessageData *message_data);
*/    
}
