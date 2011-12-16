package org.freedesktop.Secret;

import org.freedesktop.dbus.Position;
import org.freedesktop.dbus.Tuple;

/** Just a typed container class */
public final class Pair <A,B> extends Tuple {
	@Position(0)
   	public final A a;
   	@Position(1)
   	public final B b;
   	public Pair(A a, B b) {
    	this.a = a;
      	this.b = b;
   	}
}
