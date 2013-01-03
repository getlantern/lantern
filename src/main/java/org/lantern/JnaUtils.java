package org.lantern;

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class JnaUtils {

    public static List getFieldOrder(final Object obj) {
        final List<String> list = new ArrayList<String>();
        final Field[] fields = obj.getClass().getFields();
        
        for (final Field field : fields) {
            list.add(field.getName());
        }
        Collections.sort(list);
        return list;
    }

}
