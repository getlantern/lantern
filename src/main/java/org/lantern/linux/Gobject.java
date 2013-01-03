package org.lantern.linux;

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import com.sun.jna.Callback;
import com.sun.jna.Library;
import com.sun.jna.NativeLong;
import com.sun.jna.Pointer;
import com.sun.jna.Structure;

public interface Gobject extends Library {
    

    public class GTypeClassStruct extends Structure {
        public class ByValue extends GTypeClassStruct implements Structure.ByValue {}
        public class ByReference extends GTypeClassStruct implements Structure.ByReference {}
        public NativeLong g_type;
        
        protected List getFieldOrder() {
            final List<String> list = new ArrayList<String>();
            final Field[] fields = getClass().getFields();
            
            for (final Field field : fields) {
                list.add(field.getName());
            }
            Collections.sort(list);
            return list;
        }
    };

    public class GTypeInstanceStruct extends Structure {
        public class ByValue extends GTypeInstanceStruct implements Structure.ByValue {}
        public class ByReference extends GTypeInstanceStruct implements Structure.ByReference {}
        public Pointer g_class;
        
        protected List getFieldOrder() {
            final List<String> list = new ArrayList<String>();
            final Field[] fields = getClass().getFields();
            
            for (final Field field : fields) {
                list.add(field.getName());
            }
            Collections.sort(list);
            return list;
        }
    }

    public class GObjectStruct extends Structure {
        public class ByValue extends GObjectStruct implements Structure.ByValue {}
        public class ByReference extends GObjectStruct implements Structure.ByReference {}

        public GTypeInstanceStruct g_type_instance;
        public int ref_count;
        public Pointer qdata;
        
        protected List getFieldOrder() {
            final List<String> list = new ArrayList<String>();
            final Field[] fields = getClass().getFields();
            
            for (final Field field : fields) {
                list.add(field.getName());
            }
            Collections.sort(list);
            return list;
        }
    }

    public class GObjectClassStruct extends Structure {
        public class ByValue extends GObjectClassStruct implements Structure.ByValue {}
        public class ByReference extends GObjectClassStruct implements Structure.ByReference {}
        
        public GTypeClassStruct g_type_class;
        public Pointer construct_properties;
        public Pointer constructor;
        public Pointer set_property;
        public Pointer get_property;
        public Pointer dispose;
        public Pointer finalize;
        public Pointer dispatch_properties_changed;
        public Pointer notify;
        public Pointer constructed;
        public NativeLong flags;
        public Pointer dummy1;
        public Pointer dummy2;
        public Pointer dummy3;
        public Pointer dummy4;
        public Pointer dummy5;
        public Pointer dummy6;
        
        protected List getFieldOrder() {
            final List<String> list = new ArrayList<String>();
            final Field[] fields = getClass().getFields();
            
            for (final Field field : fields) {
                list.add(field.getName());
            }
            Collections.sort(list);
            return list;
        }
    };

    public interface GCallback extends Callback {
        public void callback(Pointer instance, Pointer data);
    }
    
    public void g_signal_connect_data(Pointer instance, String detailed_signal, GCallback c_handler,
                                      Pointer data, Pointer destroy_data, int connect_flags);
}
