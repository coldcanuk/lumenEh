#include "app.h"
#include "config.h"
#include "editor.h"
#include "remote_ssh.h"
#include "window.h"

/* Global app instance */
LumenehApp *app = NULL;

static void on_activate(GtkApplication *gtk_app, gpointer user_data);
static void on_open(GtkApplication *gtk_app, GFile **files, gint n_files,
                    const gchar *hint, gpointer user_data);
static void lumeneh_app_ensure_window(LumenehApp *self);

LumenehApp *lumeneh_app_new(void) {
  LumenehApp *self = g_new0(LumenehApp, 1);

  config = config_new();
  config_load(config);

  GApplicationFlags flags =
#if GLIB_CHECK_VERSION(2, 74, 0)
      G_APPLICATION_DEFAULT_FLAGS;
#else
      G_APPLICATION_FLAGS_NONE;
#endif
  flags = (GApplicationFlags)(flags | G_APPLICATION_NON_UNIQUE |
                              G_APPLICATION_HANDLES_OPEN);

  self->gtk_app = gtk_application_new("org.lumeneh.app", flags);

  g_signal_connect(self->gtk_app, "activate", G_CALLBACK(on_activate), self);
  g_signal_connect(self->gtk_app, "open", G_CALLBACK(on_open), self);

  app = self;
  return self;
}

void lumeneh_app_free(LumenehApp *self) {
  if (!self)
    return;

  if (self->window) {
    lumeneh_window_free(self->window);
  }

  g_object_unref(self->gtk_app);

  config_save(config);
  config_free(config);
  config = NULL;

  g_free(self);
  app = NULL;
}

int lumeneh_app_run(LumenehApp *self, int argc, char **argv) {
  return g_application_run(G_APPLICATION(self->gtk_app), argc, argv);
}

static void on_activate(GtkApplication *gtk_app, gpointer user_data) {
  LumenehApp *self = (LumenehApp *)user_data;

  (void)gtk_app;
  lumeneh_app_ensure_window(self);
  lumeneh_window_show(self->window);
}

static void on_open(GtkApplication *gtk_app, GFile **files, gint n_files,
                    const gchar *hint, gpointer user_data) {
  LumenehApp *self = (LumenehApp *)user_data;
  gboolean opened = FALSE;

  (void)gtk_app;
  (void)hint;

  lumeneh_app_ensure_window(self);

  for (gint i = 0; i < n_files; i++) {
    gchar *path = g_file_get_path(files[i]);
    if (!path) {
      continue;
    }
    if (lumeneh_app_open_file(self, path)) {
      opened = TRUE;
      g_free(path);
      break;
    }
    g_free(path);
  }

  if (!opened && n_files > 0) {
    g_printerr("lumenEh: unable to open provided file(s)\n");
  }

  lumeneh_window_show(self->window);
}

static void lumeneh_app_ensure_window(LumenehApp *self) {
  if (self->window) {
    return;
  }

  self->window = lumeneh_window_new(self);

  lumeneh_window_open_tab(self->window, NULL, "# lumenEh\n\nUse the Open button to load a markdown document.");
}

gboolean lumeneh_app_open_file(LumenehApp *self, const gchar *path) {
  gchar *content = NULL;
  GError *error = NULL;

  if (!self || !self->window || !path || path[0] == '\0') {
    return FALSE;
  }

  if (remote_ssh_is_remote_uri(path)) {
    RemoteSSHLocation *loc = remote_ssh_parse_uri(path);
    if (loc) {
      if (remote_ssh_fetch_file(loc, &content, NULL, &error)) {
        lumeneh_window_open_tab(self->window, path, content);
        g_free(content);
        remote_ssh_location_free(loc);
        return TRUE;
      }
      remote_ssh_location_free(loc);
    }
    if (error) {
      g_printerr("Failed to load remote markdown document '%s': %s\n", path,
                 error->message);
      g_error_free(error);
    }
    return FALSE;
  }

  if (!g_file_get_contents(path, &content, NULL, &error)) {
    if (error) {
      g_printerr("Failed to load markdown file '%s': %s\n", path, error->message);
      g_error_free(error);
    }
    return FALSE;
  }

  lumeneh_window_open_tab(self->window, path, content);
  g_free(content);

  return TRUE;
}

const gchar *lumeneh_app_get_current_path(LumenehApp *self) {
  if (self && self->window) {
    return lumeneh_window_get_current_path(self->window);
  }
  return NULL;
}
