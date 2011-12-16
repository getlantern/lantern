package org.freedesktop.Secret;
import org.freedesktop.dbus.DBusInterface;

public interface Session extends DBusInterface
{
	public void Close();
}
