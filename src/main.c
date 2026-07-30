#include "app.h"
#include <gtk/gtk.h>

int main(int argc, char **argv) {
  LumenehApp *application;
  int status;

  application = lumeneh_app_new();
  if (!application) {
    g_printerr("Failed to create application\n");
    return 1;
  }

  status = lumeneh_app_run(application, argc, argv);

  lumeneh_app_free(application);

  return status;
}
