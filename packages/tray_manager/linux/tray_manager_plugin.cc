#include "include/tray_manager/tray_manager_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gio/gio.h>
#include <sys/utsname.h>

#ifdef HAVE_AYATANA
#include <libayatana-appindicator/app-indicator.h>
#else
#include <libappindicator/app-indicator.h>
#endif
#include <algorithm>
#include <cstring>
#include <map>

#define TRAY_MANAGER_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), tray_manager_plugin_get_type(), \
                              TrayManagerPlugin))

TrayManagerPlugin* plugin_instance;

AppIndicator* indicator = nullptr;
GtkWidget* menu = nullptr;

struct _TrayManagerPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
  FlMethodChannel* channel;
};

G_DEFINE_TYPE(TrayManagerPlugin, tray_manager_plugin, g_object_get_type())

// Gets the window being controlled.
GtkWindow* get_window(TrayManagerPlugin* self) {
  FlView* view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr)
    return nullptr;

  return GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

void _on_activate(GtkMenuItem* item, gpointer user_data) {
  gint id = GPOINTER_TO_INT(user_data);

  g_autoptr(FlValue) result_data = fl_value_new_map();
  fl_value_set_string_take(result_data, "id", fl_value_new_int(id));
  fl_method_channel_invoke_method(plugin_instance->channel,
                                  "onTrayMenuItemClick", result_data, nullptr,
                                  nullptr, nullptr);
}

// Create a GdkPixbuf from base64-encoded PNG data, scaled to 16x16.
static GdkPixbuf* _pixbuf_from_base64(const char* base64_str) {
  gsize decoded_len = 0;
  guchar* decoded = g_base64_decode(base64_str, &decoded_len);
  if (!decoded || decoded_len == 0) {
    g_free(decoded);
    return nullptr;
  }

  GInputStream* stream = g_memory_input_stream_new_from_data(
      decoded, decoded_len, g_free);
  GError* error = nullptr;
  GdkPixbuf* pixbuf = gdk_pixbuf_new_from_stream(stream, nullptr, &error);
  g_object_unref(stream);

  if (error) {
    g_error_free(error);
    return nullptr;
  }
  if (!pixbuf) return nullptr;

  // Scale to 16x16
  GdkPixbuf* scaled = gdk_pixbuf_scale_simple(pixbuf, 16, 16,
                                                GDK_INTERP_BILINEAR);
  g_object_unref(pixbuf);
  return scaled;
}

GtkWidget* _create_menu(FlValue* args) {
  FlValue* items_value = fl_value_lookup_string(args, "items");

  GtkWidget* menu = gtk_menu_new();
  for (gint i = 0; i < fl_value_get_length(items_value); i++) {
    FlValue* item_value = fl_value_get_list_value(items_value, i);
    const int id = fl_value_get_int(fl_value_lookup_string(item_value, "id"));
    const char* type =
        fl_value_get_string(fl_value_lookup_string(item_value, "type"));
    const char* label =
        fl_value_get_string(fl_value_lookup_string(item_value, "label"));
    const bool disabled =
        fl_value_get_bool(fl_value_lookup_string(item_value, "disabled"));

    gint item_id = id;

    if (strcmp(type, "separator") == 0) {
      gtk_menu_shell_append(GTK_MENU_SHELL(menu),
                            gtk_separator_menu_item_new());
    } else {
      GtkWidget* item = nullptr;

      // Check for icon (base64-encoded PNG from Dart)
      FlValue* icon_value = fl_value_lookup_string(item_value, "icon");
      GdkPixbuf* pixbuf = nullptr;
      if (icon_value != nullptr &&
          fl_value_get_type(icon_value) == FL_VALUE_TYPE_STRING) {
        const char* icon_base64 = fl_value_get_string(icon_value);
        if (icon_base64 && strlen(icon_base64) > 0) {
          pixbuf = _pixbuf_from_base64(icon_base64);
        }
      }

      if (strcmp(type, "checkbox") == 0) {
        item = gtk_check_menu_item_new_with_label(label);
        const auto checked_value =
            fl_value_lookup_string(item_value, "checked");
        if (checked_value != nullptr) {
          const auto checked = fl_value_get_bool(checked_value);
          gtk_check_menu_item_set_active((GtkCheckMenuItem*)item, checked);
        }
        if (pixbuf) g_object_unref(pixbuf);
      } else {
        if (pixbuf) {
          // Use deprecated GtkImageMenuItem - still works in GTK3
          G_GNUC_BEGIN_IGNORE_DEPRECATIONS
          GtkWidget* image = gtk_image_new_from_pixbuf(pixbuf);
          item = gtk_image_menu_item_new_with_label(label);
          gtk_image_menu_item_set_image(GTK_IMAGE_MENU_ITEM(item), image);
          gtk_image_menu_item_set_always_show_image(
              GTK_IMAGE_MENU_ITEM(item), TRUE);
          G_GNUC_END_IGNORE_DEPRECATIONS
          g_object_unref(pixbuf);
        } else {
          item = gtk_menu_item_new_with_label(label);
        }

        if (strcmp(type, "submenu") == 0) {
          GtkWidget* sub_menu =
              _create_menu(fl_value_lookup_string(item_value, "submenu"));
          gtk_menu_item_set_submenu(GTK_MENU_ITEM(item), sub_menu);
        }
      }

      if (disabled) {
        gtk_widget_set_sensitive(item, FALSE);
      }

      g_signal_connect(G_OBJECT(item), "activate", G_CALLBACK(_on_activate),
                       GINT_TO_POINTER(item_id));

      gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
    }
  }
  return menu;
}

static FlMethodResponse* destroy(TrayManagerPlugin* self, FlValue* args) {
  if (!(!indicator)) {
    app_indicator_set_status(indicator, APP_INDICATOR_STATUS_PASSIVE);
  }
  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* set_icon(TrayManagerPlugin* self, FlValue* args) {
  const char* id = fl_value_get_string(fl_value_lookup_string(args, "id"));
  const char* icon_path =
      fl_value_get_string(fl_value_lookup_string(args, "iconPath"));

  if (!menu)
    menu = gtk_menu_new();

  if (!indicator) {
    indicator = app_indicator_new(id, icon_path,
                                  APP_INDICATOR_CATEGORY_APPLICATION_STATUS);

    app_indicator_set_menu(indicator, GTK_MENU(menu));
    gtk_widget_show_all(menu);
  }

  app_indicator_set_status(indicator, APP_INDICATOR_STATUS_ACTIVE);
  app_indicator_set_icon_full(indicator, icon_path, "");

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* set_title(TrayManagerPlugin* self, FlValue* args) {
  const char* title =
      fl_value_get_string(fl_value_lookup_string(args, "title"));

  app_indicator_set_label(indicator, title, NULL);

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* set_context_menu(TrayManagerPlugin* self,
                                          FlValue* args) {
  menu = _create_menu(fl_value_lookup_string(args, "menu"));

  app_indicator_set_menu(indicator, GTK_MENU(menu));
  gtk_widget_show_all(menu);

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

// Called when a method call is received from Flutter.
static void tray_manager_plugin_handle_method_call(TrayManagerPlugin* self,
                                                   FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "destroy") == 0) {
    response = destroy(self, args);
  } else if (strcmp(method, "setIcon") == 0) {
    response = set_icon(self, args);
  } else if (strcmp(method, "setTitle") == 0) {
    response = set_title(self, args);
  } else if (strcmp(method, "setContextMenu") == 0) {
    response = set_context_menu(self, args);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void tray_manager_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(tray_manager_plugin_parent_class)->dispose(object);
}

static void tray_manager_plugin_class_init(TrayManagerPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = tray_manager_plugin_dispose;
}

static void tray_manager_plugin_init(TrayManagerPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  TrayManagerPlugin* plugin = TRAY_MANAGER_PLUGIN(user_data);
  tray_manager_plugin_handle_method_call(plugin, method_call);
}

void tray_manager_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  TrayManagerPlugin* plugin = TRAY_MANAGER_PLUGIN(
      g_object_new(tray_manager_plugin_get_type(), nullptr));

  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "tray_manager", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      plugin->channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  plugin_instance = plugin;

  g_object_unref(plugin);
}
