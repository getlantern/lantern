#include <gio/gio.h>
#include <stdio.h>
#include "common.h"

int togglePac(bool turnOn, const char* pacUrl)
{
  int ret = RET_NO_ERROR;

#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
  // deprecated since version 2.36, must leave here or prior glib will crash
  g_type_init();
#pragma GCC diagnostic warning "-Wdeprecated-declarations"
  GSettings* setting = g_settings_new("org.gnome.system.proxy");
  if (turnOn == true) {
    gboolean success = g_settings_set_string(setting, "mode", "auto");
    if (!success) {
      fprintf(stderr, "error setting mode to auto\n");
      ret = SYSCALL_FAILED;
      goto cleanup;
    }
    success = g_settings_set_string(setting, "autoconfig-url", pacUrl);
    if (!success) {
      fprintf(stderr, "error setting autoconfig-url to %s\n", pacUrl);
      ret = SYSCALL_FAILED;
      goto cleanup;
    }
  }
  else {
    gboolean success = g_settings_set_string(setting, "mode", "none");
    if (!success) {
      fprintf(stderr, "error setting mode to none\n");
      ret = SYSCALL_FAILED;
      goto cleanup;
    }
    g_settings_reset(setting, "autoconfig-url");
  }
cleanup:
  g_settings_sync();
  g_object_unref(setting);

  return ret;
}
