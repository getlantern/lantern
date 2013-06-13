package org.lantern.annotation;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Marker annotation for proguard
 *
 */
@Retention(RetentionPolicy.CLASS)
@Target({ElementType.TYPE})
@Keep
public @interface Keep {

}
