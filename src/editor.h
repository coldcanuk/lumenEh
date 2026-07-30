#ifndef LUMENEH_EDITOR_H
#define LUMENEH_EDITOR_H

#include <gtk/gtk.h>

typedef struct _LumenehApp LumenehApp;

typedef struct _LumenehEditor {
  GtkWidget *text_view;
  GtkTextBuffer *buffer;
  LumenehApp *app;

  /* Original markdown content loaded into the viewer. */
  gchar *source_content;

  /* Prevent recursive tag application. */
  gboolean updating_tags;

  /* Coalesce markdown re-rendering to idle to avoid invalidating GTK iterators. */
  guint markdown_idle_id;
} LumenehEditor;

/* Lifecycle */
LumenehEditor *lumeneh_editor_new(LumenehApp *app);
void lumeneh_editor_free(LumenehEditor *editor);

/* Content management */
void lumeneh_editor_set_content(LumenehEditor *editor, const gchar *content);
gchar *lumeneh_editor_get_content(LumenehEditor *editor);

/* Widget access */
GtkWidget *lumeneh_editor_get_widget(LumenehEditor *editor);
void lumeneh_editor_focus(LumenehEditor *editor);

/* Force a refresh of markdown styling/rendering (e.g., after settings change). */
void lumeneh_editor_refresh(LumenehEditor *editor);

#endif /* LUMENEH_EDITOR_H */
