package org.lantern.linux;

import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Pointer;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/* bindings for libappindicator 0.1 */
public interface AppIndicator extends Library {
    
    public static final int CATEGORY_APPLICATION_STATUS = 0;
    public static final int CATEGORY_COMMUNICATIONS     = 1;
    public static final int CATEGORY_SYSTEM_SERVICES    = 2;
    public static final int CATEGORY_HARDWARE           = 3;
    public static final int CATEGORY_OTHER              = 4;

    public static final int STATUS_PASSIVE   = 0;
    public static final int STATUS_ACTIVE    = 1;
    public static final int STATUS_ATTENTION = 2;

    public Pointer app_indicator_new(String id, String icon_name, int category);
    public Pointer app_indicator_new_with_path(String id, String icon_name, int category, String icon_theme_path);
    public void app_indicator_set_status(Pointer self, int status);
    public void app_indicator_set_attention_icon(Pointer self, String icon_name);
    public void app_indicator_set_attention_icon_full(Pointer self, String name, String icon_desc);
    public void app_indicator_set_menu(Pointer self, Pointer menu);
    public void app_indicator_set_icon(Pointer self, String icon_name);
    public void app_indicator_set_icon_full(Pointer self, String icon_name, String icon_desc);
    public void app_indicator_set_label(Pointer self, String label, String guide);
    public void app_indicator_set_icon_theme_path(Pointer self, String icon_theme_path);
    public void app_indicator_set_ordering_index(Pointer self, int ordering_index);
    public void app_indicator_set_secondary_active_target(Pointer self, Pointer menuitem);
    
    public String app_indicator_get_id(Pointer self);
    public int    app_indicator_get_category(Pointer self);
    public int    app_indicator_get_status(Pointer self);
    
    public String app_indicator_get_icon(Pointer self);
    public String app_indicator_get_icon_desc(Pointer self);
    public String app_indicator_get_icon_theme_path(Pointer self);
    public String app_indicator_get_attention_icon(Pointer self);
    
    public Pointer app_indicator_get_menu(Pointer self);
    public String  app_indicator_get_label(Pointer self);
    public String  app_indicator_get_label_guide(Pointer self);
    public int     app_indicator_get_ordering_index(Pointer self);
    public Pointer app_indicator_get_secondary_active_target(Pointer self);
    
    public void app_indicator_build_menu_from_desktop(Pointer self, String desktop_file, String destkop_profile);
}