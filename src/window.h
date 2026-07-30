#ifndef MARKYD_WINDOW_H
#define MARKYD_WINDOW_H

#include <gtk/gtk.h>

typedef struct _MarkydApp MarkydApp;
typedef struct _MarkydEditor MarkydEditor;

typedef struct _MarkydTab {
  MarkydEditor *editor;
  GtkWidget *scroll;
  gchar *file_path;
} MarkydTab;

typedef struct _MarkydWindow {
  GtkWidget *window;
  GtkWidget *header_bar;
  GtkWidget *btn_open;
  GtkWidget *btn_open_remote;
  GtkWidget *btn_refresh;
  GtkWidget *btn_settings;
  GtkWidget *search_revealer;
  GtkWidget *search_entry;
  GtkWidget *btn_search_prev;
  GtkWidget *btn_search_next;
  GtkWidget *lbl_search_status;
  GtkWidget *lbl_title;
  
  GtkWidget *notebook;
  GtkWidget *empty_state_box;
  GList *tabs;
  MarkydTab *current_tab;

  MarkydEditor *editor;
  MarkydApp *app;
  GArray *search_matches;
  gint search_current_index;
} MarkydWindow;

/* Lifecycle */
MarkydWindow *markyd_window_new(MarkydApp *app);
void markyd_window_free(MarkydWindow *win);

/* Tab management */
MarkydTab *markyd_window_open_tab(MarkydWindow *win, const gchar *path, const gchar *content);
void markyd_window_close_tab(MarkydWindow *win, MarkydTab *tab);
const gchar *markyd_window_get_current_path(MarkydWindow *win);

/* Visibility */
void markyd_window_show(MarkydWindow *win);
void markyd_window_hide(MarkydWindow *win);
void markyd_window_toggle(MarkydWindow *win);
gboolean markyd_window_is_visible(MarkydWindow *win);

/* Styling */
void markyd_window_apply_css(MarkydWindow *win);

#endif /* MARKYD_WINDOW_H */
