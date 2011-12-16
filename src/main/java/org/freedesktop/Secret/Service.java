package org.freedesktop.Secret;

import java.util.List;
import java.util.Map;
import org.freedesktop.DBus;
import org.freedesktop.dbus.DBusInterface;
import org.freedesktop.dbus.DBusSignal;
import org.freedesktop.dbus.Path;
import org.freedesktop.dbus.Variant;
import org.freedesktop.dbus.exceptions.DBusException;

public interface Service extends DBus.Properties {

    public static final String INTERFACE_NAME = "org.freedesktop.Secret.Service";
    public static final String PROPERTY_COLLECTIONS = "Collections"; // List<Collection> RO

    public static class CollectionCreated extends DBusSignal {
        public final DBusInterface collection;
        public CollectionCreated(String path, DBusInterface collection) throws DBusException {
            super(path, collection);
            this.collection = collection;
        }
    }
    public static class CollectionDeleted extends DBusSignal {
        public final DBusInterface collection;
        public CollectionDeleted(String path, DBusInterface collection) throws DBusException {
            super(path, collection);
            this.collection = collection;
        }
    }
   
    public static class CollectionChanged extends DBusSignal {
        public final DBusInterface collection;
        public CollectionChanged(String path, DBusInterface collection) throws DBusException {
            super(path, collection);
            this.collection = collection;
        }
    }

  public Pair<Variant, Path> OpenSession(String algorithm, Variant input);
  public Pair<Path, Path> CreateCollection(Map<String,Variant> properties, String alias);
  public Pair<List<Path>, List<Path>> SearchItems(Map<String,String> attributes);
  public Pair<List<Path>, Path> Unlock(List<Path> objects);
  public Pair<List<Path>, Path> Lock(List<Path> objects);
  public Map<Item,Secret> GetSecrets(List<Path> items, Path session);
  public Collection ReadAlias(String name);
  public void SetAlias(String name, Collection collection);

}
