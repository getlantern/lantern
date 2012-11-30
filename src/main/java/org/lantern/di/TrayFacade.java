package org.lantern.di;

import com.google.inject.BindingAnnotation;
import java.lang.annotation.Target;
import java.lang.annotation.Retention;
import static java.lang.annotation.RetentionPolicy.RUNTIME;
import static java.lang.annotation.ElementType.PARAMETER;
import static java.lang.annotation.ElementType.FIELD;
import static java.lang.annotation.ElementType.METHOD;
import static java.lang.annotation.ElementType.TYPE;;

@BindingAnnotation @Target({ FIELD, PARAMETER, METHOD, TYPE }) @Retention(RUNTIME)
public @interface TrayFacade {

}
