#ifndef LUMENEH_WINDOW_H
#define LUMENEH_WINDOW_H

#include <gtk/gtk.h>

typedef struct _LumenehApp LumenehApp;
typedef struct _LumenehEditor LumenehEditor;

typedef struct _LumenehTab {
  LumenehEditor *editor;
  GtkWidget *scroll;
  gchar *file_path;
} LumenehTab;

typedef struct _LumenehWindow {
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
  LumenehTab *current_tab;

  LumenehEditor *editor;
  LumenehApp *app;
  GArray *search_matches;
  gint search_current_index;
} LumenehWindow;

/* Lifecycle */
LumenehWindow *lumeneh_window_new(LumenehApp *app);
void lumeneh_window_free(LumenehWindow *win);

/* Tab management */
LumenehTab *lumeneh_window_open_tab(LumenehWindow *win, const gchar *path, const gchar *content);
void lumeneh_window_close_tab(LumenehWindow *win, LumenehTab *tab);
const gchar *lumeneh_window_get_current_path(LumenehWindow *win);

/* Visibility */
void lumeneh_window_show(LumenehWindow *win);
void lumeneh_window_hide(LumenehWindow *win);
void lumeneh_window_toggle(LumenehWindow *win);
gboolean lumeneh_window_is_visible(LumenehWindow *win);

/* Styling */
void lumeneh_window_apply_css(LumenehWindow *win);

#endif /* LUMENEH_WINDOW_H */
