#ifndef LUMENEH_APP_H
#define LUMENEH_APP_H

#include <gtk/gtk.h>

/* Forward declarations */
typedef struct _LumenehWindow LumenehWindow;
typedef struct _LumenehEditor LumenehEditor;

/* Application state */
typedef struct _LumenehApp {
  GtkApplication *gtk_app;
  LumenehWindow *window;
} LumenehApp;

/* Global app instance */
extern LumenehApp *app;

/* Lifecycle */
LumenehApp *lumeneh_app_new(void);
void lumeneh_app_free(LumenehApp *app);
int lumeneh_app_run(LumenehApp *app, int argc, char **argv);

/* Document management */
gboolean lumeneh_app_open_file(LumenehApp *app, const gchar *path);

/* Utility */
const gchar *lumeneh_app_get_current_path(LumenehApp *app);

#endif /* LUMENEH_APP_H */
