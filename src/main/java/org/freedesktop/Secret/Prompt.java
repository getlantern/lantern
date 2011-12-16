package org.freedesktop.Secret;

import java.util.Map;
import org.freedesktop.dbus.DBusInterface;
import org.freedesktop.dbus.DBusSignal;
import org.freedesktop.dbus.Variant;
import org.freedesktop.dbus.exceptions.DBusException;

public interface Prompt extends DBusInterface {

    public static class Completed extends DBusSignal {
        public final Boolean dismissed;
        public final Variant result;

        public Completed(String path, Boolean dismissed, Variant result) throws DBusException {
            super(path, dismissed, result);
            this.dismissed = dismissed;
            this.result = result;
        }
    }

    public void Dismiss();
    public void Prompt(String windowid);

}