package org.lantern.linux;

import com.sun.jna.Callback;
import com.sun.jna.Library;
import com.sun.jna.Pointer;
import com.sun.jna.Structure;

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

    public interface Fallback extends Callback {
        public Pointer callback(AppIndicatorInstanceStruct self);
    }

    public interface Unfallback extends Callback {
        public void callback(AppIndicatorInstanceStruct self, Pointer status_icon);
    }

    public class AppIndicatorClassStruct extends Structure {
        public class ByReference extends AppIndicatorClassStruct implements Structure.ByReference {}

        public Gobject.GObjectClassStruct parent_class;
        
        public Pointer new_icon; 
        public Pointer new_attention_icon; 
        public Pointer new_status; 
        public Pointer new_icon_theme;
        public Pointer new_label;
        public Pointer connection_changed;
        public Pointer scroll_event;
        public Pointer app_indicator_reserved_ats;
        //public Pointer fallback;
        public Fallback fallback;
        public Pointer unfallback;
        public Pointer app_indicator_reserved_1;
        public Pointer app_indicator_reserved_2;
        public Pointer app_indicator_reserved_3;
        public Pointer app_indicator_reserved_4;
        public Pointer app_indicator_reserved_5;
        public Pointer app_indicator_reserved_6;

        public AppIndicatorClassStruct() {}
        public AppIndicatorClassStruct(Pointer p) {
            super(p);
            useMemory(p);
            read();
        }
        
        /*
        @Override
        protected List getFieldOrder() {
            return Arrays.asList("new_icon", "new_attention_icon", "new_status", 
                "new_icon_theme", "new_label", "connection_changed", 
                "scroll_event", "app_indicator_reserved_ats", "",
                "fallback", "unfallback", "app_indicator_reserved_1", 
                "app_indicator_reserved_2", "app_indicator_reserved_3", 
                "app_indicator_reserved_4", "app_indicator_reserved_5", 
                "app_indicator_reserved_6");
        }
        */
    }

    public class AppIndicatorInstanceStruct extends Structure {
        public Gobject.GObjectStruct parent;
        public Pointer priv;
    }


    public AppIndicatorInstanceStruct app_indicator_new(String id, String icon_name, int category);
    public AppIndicatorInstanceStruct app_indicator_new_with_path(String id, String icon_name, int category, String icon_theme_path);
    public void app_indicator_set_status(AppIndicatorInstanceStruct self, int status);
    public void app_indicator_set_attention_icon(AppIndicatorInstanceStruct self, String icon_name);
    public void app_indicator_set_attention_icon_full(AppIndicatorInstanceStruct self, String name, String icon_desc);
    public void app_indicator_set_menu(AppIndicatorInstanceStruct self, Pointer menu);
    public void app_indicator_set_icon(AppIndicatorInstanceStruct self, String icon_name);
    public void app_indicator_set_icon_full(AppIndicatorInstanceStruct self, String icon_name, String icon_desc);
    public void app_indicator_set_label(AppIndicatorInstanceStruct self, String label, String guide);
    public void app_indicator_set_icon_theme_path(AppIndicatorInstanceStruct self, String icon_theme_path);
    public void app_indicator_set_ordering_index(AppIndicatorInstanceStruct self, int ordering_index);
    public void app_indicator_set_secondary_active_target(AppIndicatorInstanceStruct self, Pointer menuitem);
    
    public String app_indicator_get_id(AppIndicatorInstanceStruct self);
    public int    app_indicator_get_category(AppIndicatorInstanceStruct self);
    public int    app_indicator_get_status(AppIndicatorInstanceStruct self);
    
    public String app_indicator_get_icon(AppIndicatorInstanceStruct self);
    public String app_indicator_get_icon_desc(AppIndicatorInstanceStruct self);
    public String app_indicator_get_icon_theme_path(AppIndicatorInstanceStruct self);
    public String app_indicator_get_attention_icon(AppIndicatorInstanceStruct self);
    
    public Pointer app_indicator_get_menu(AppIndicatorInstanceStruct self);
    public String  app_indicator_get_label(AppIndicatorInstanceStruct self);
    public String  app_indicator_get_label_guide(AppIndicatorInstanceStruct self);
    public int     app_indicator_get_ordering_index(AppIndicatorInstanceStruct self);
    public Pointer app_indicator_get_secondary_active_target(AppIndicatorInstanceStruct self);
    
    public void app_indicator_build_menu_from_desktop(AppIndicatorInstanceStruct self, String desktop_file, String destkop_profile);
}