#include <gio/gio.h>
#include <stdio.h>
#include <string.h>
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
    if (strlen(pacUrl) != 0) {
      // clear pac setting only if it's equal to pacUrl
      char* old_mode = g_settings_get_string(setting, "mode");
      char* old_pac_url = g_settings_get_string(setting, "autoconfig-url");
      if (strcmp(old_mode, "auto") != 0 || strcmp(old_pac_url, pacUrl) != 0 ) {
	      fprintf(stderr, "current pac url setting is not %s, skipping\n", pacUrl);
	      goto cleanup;
      }
    }
    g_settings_reset(setting, "autoconfig-url");
    gboolean success = g_settings_set_string(setting, "mode", "none");
    if (!success) {
	    fprintf(stderr, "error setting mode to none\n");
	    ret = SYSCALL_FAILED;
	    goto cleanup;
    }
}
cleanup:
g_settings_sync();
g_object_unref(setting);

return ret;
}
