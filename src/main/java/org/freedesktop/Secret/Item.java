package org.freedesktop.Secret;

import org.freedesktop.DBus;
import org.freedesktop.dbus.Path;

public interface Item extends DBus.Properties {

	public static final String INTERFACE_NAME      = "org.freedesktop.Secret.Item";

	// Property Names
	public static final String PROPERTY_ATTRIBUTES = "Attributes"; // Map<String, String> RW
    public static final String PROPERTY_CREATED    = "Created"; // UInt64 RO
    public static final String PROPERTY_LABEL      = "Label"; // String RW
    public static final String PROPERTY_LOCKED     = "Locked"; // Boolean RO
    public static final String PROPERTY_MODIFIED   = "Modified"; // UInt64 RO

	public Path Delete();
	public Secret GetSecret(Path session);
	public void SetSecret(Secret secret);
}
