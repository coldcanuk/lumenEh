#include "remote_browser.h"
#include "remote_ssh.h"
#include "bookmarks.h"
#include "window.h"

enum {
  COL_ICON = 0,
  COL_NAME,
  COL_IS_DIR,
  NUM_COLS
};

typedef struct {
  MarkydWindow *window;
  GtkWidget *dialog;
  GtkWidget *tree_view;
  GtkListStore *list_store;
  GtkWidget *path_entry;
  GtkWidget *status_label;
  RemoteSSHLocation *current_loc;
} RemoteBrowserData;

static void load_directory(RemoteBrowserData *data, const gchar *path) {
  GPtrArray *items = NULL;
  GError *error = NULL;
  GtkTreeIter iter;

  gchar *new_path_str = g_strdup(path ? path : "");
  if (data->current_loc->path) {
    g_free(data->current_loc->path);
  }
  data->current_loc->path = new_path_str;
  gtk_entry_set_text(GTK_ENTRY(data->path_entry), new_path_str);
  gtk_label_set_text(GTK_LABEL(data->status_label), "Loading...");

  // Update UI first
  while (gtk_events_pending()) {
    gtk_main_iteration();
  }

  gtk_list_store_clear(data->list_store);

  // Add ".." parent directory if not at root
  if (g_strcmp0(new_path_str, "/") != 0 && strlen(new_path_str) > 1) {
    gtk_list_store_append(data->list_store, &iter);
    gtk_list_store_set(data->list_store, &iter, 
                       COL_ICON, "go-up-symbolic",
                       COL_NAME, "..",
                       COL_IS_DIR, TRUE,
                       -1);
  }

  if (remote_ssh_list_dir(data->current_loc, &items, &error)) {
    for (guint i = 0; i < items->len; i++) {
      const gchar *name = g_ptr_array_index(items, i);
      gboolean is_dir = g_str_has_suffix(name, "/");
      gchar *clean_name = g_utf8_make_valid(name, -1);
      
      if (!is_dir) {
        gchar *lower_name = g_utf8_strdown(clean_name, -1);
        gboolean is_md = g_str_has_suffix(lower_name, ".md") || g_str_has_suffix(lower_name, ".markdown");
        g_free(lower_name);
        if (!is_md) {
          g_free(clean_name);
          continue;
        }
      } else {
        clean_name[strlen(clean_name) - 1] = '\0';
      }

      const gchar *icon = is_dir ? "folder-symbolic" : "text-x-markdown-symbolic";
      
      gtk_list_store_append(data->list_store, &iter);
      gtk_list_store_set(data->list_store, &iter, 
                         COL_ICON, icon,
                         COL_NAME, clean_name,
                         COL_IS_DIR, is_dir,
                         -1);
      g_free(clean_name);
    }
    g_ptr_array_free(items, TRUE);
    gtk_label_set_text(GTK_LABEL(data->status_label), "");
  } else {
    gchar *err_msg = g_strdup_printf("Error: %s", error ? error->message : "Unknown error");
    gtk_label_set_text(GTK_LABEL(data->status_label), err_msg);
    g_free(err_msg);
    if (error) g_error_free(error);
  }
}

static void on_row_activated(GtkTreeView *tree_view, GtkTreePath *path, GtkTreeViewColumn *column, gpointer user_data) {
  RemoteBrowserData *data = (RemoteBrowserData *)user_data;
  GtkTreeIter iter;
  GtkTreeModel *model = GTK_TREE_MODEL(data->list_store);
  gchar *name = NULL;
  gboolean is_dir = FALSE;

  if (gtk_tree_model_get_iter(model, &iter, path)) {
    gtk_tree_model_get(model, &iter, COL_NAME, &name, COL_IS_DIR, &is_dir, -1);

    if (is_dir) {
      gchar *new_path;
      if (g_strcmp0(name, "..") == 0) {
        new_path = g_path_get_dirname(data->current_loc->path);
      } else {
        if (g_strcmp0(data->current_loc->path, "/") == 0) {
          new_path = g_strdup_printf("/%s", name);
        } else {
          new_path = g_strdup_printf("%s/%s", data->current_loc->path, name);
        }
      }
      load_directory(data, new_path);
      g_free(new_path);
    } else {
      // File selected
      gchar *full_path;
      if (g_strcmp0(data->current_loc->path, "/") == 0) {
        full_path = g_strdup_printf("/%s", name);
      } else {
        full_path = g_strdup_printf("%s/%s", data->current_loc->path, name);
      }
      
      GString *s = g_string_new("");
      if (data->current_loc->user && data->current_loc->user[0] != '\0') {
        g_string_append_printf(s, "%s@", data->current_loc->user);
      }
      g_string_append(s, data->current_loc->host);
      if (data->current_loc->port > 0) {
        g_string_append_printf(s, ":%d", data->current_loc->port);
      }
      
      g_string_append(s, ":");
      g_string_append(s, full_path);
      
      gchar *uri = g_string_free(s, FALSE);
      
      // Close dialog and open file
      gtk_dialog_response(GTK_DIALOG(data->dialog), GTK_RESPONSE_ACCEPT);
      markyd_app_open_file(data->window->app, uri);
      
      g_free(full_path);
      g_free(uri);
    }
    g_free(name);
  }
}

static void on_path_entry_activate(GtkEntry *entry, gpointer user_data) {
  RemoteBrowserData *data = (RemoteBrowserData *)user_data;
  const gchar *new_path = gtk_entry_get_text(entry);
  load_directory(data, new_path);
}

void remote_browser_dialog_run(MarkydWindow *window, const gchar *initial_host_uri) {
  RemoteBrowserData data;
  data.window = window;
  data.current_loc = remote_ssh_parse_uri(initial_host_uri);
  
  if (!data.current_loc) {
    // Fallback to localhost if parse fails
    data.current_loc = g_new0(RemoteSSHLocation, 1);
    data.current_loc->host = g_strdup("localhost");
    data.current_loc->path = g_strdup("/");
  }

  if (!data.current_loc->path || data.current_loc->path[0] == '\0') {
    data.current_loc->path = g_strdup("/");
  }

  data.dialog = gtk_dialog_new_with_buttons(
      "Remote File Browser", GTK_WINDOW(window->window),
      GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
      "_Cancel", GTK_RESPONSE_CANCEL,
      NULL);

  gtk_window_set_default_size(GTK_WINDOW(data.dialog), 500, 400);

  GtkWidget *content_area = gtk_dialog_get_content_area(GTK_DIALOG(data.dialog));
  gtk_box_set_spacing(GTK_BOX(content_area), 8);
  gtk_container_set_border_width(GTK_CONTAINER(content_area), 12);

  // Path Entry
  GtkWidget *path_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
  gtk_box_pack_start(GTK_BOX(content_area), path_box, FALSE, FALSE, 0);
  
  GtkWidget *path_label = gtk_label_new("Path:");
  gtk_box_pack_start(GTK_BOX(path_box), path_label, FALSE, FALSE, 0);
  
  data.path_entry = gtk_entry_new();
  gtk_widget_set_hexpand(data.path_entry, TRUE);
  g_signal_connect(data.path_entry, "activate", G_CALLBACK(on_path_entry_activate), &data);
  gtk_box_pack_start(GTK_BOX(path_box), data.path_entry, TRUE, TRUE, 0);

  // Tree View
  GtkWidget *scroll = gtk_scrolled_window_new(NULL, NULL);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_vexpand(scroll, TRUE);
  gtk_box_pack_start(GTK_BOX(content_area), scroll, TRUE, TRUE, 0);

  data.list_store = gtk_list_store_new(NUM_COLS, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_BOOLEAN);
  data.tree_view = gtk_tree_view_new_with_model(GTK_TREE_MODEL(data.list_store));
  gtk_tree_view_set_headers_visible(GTK_TREE_VIEW(data.tree_view), FALSE);
  g_signal_connect(data.tree_view, "row-activated", G_CALLBACK(on_row_activated), &data);

  GtkCellRenderer *renderer;
  GtkTreeViewColumn *column;

  // Icon column
  renderer = gtk_cell_renderer_pixbuf_new();
  column = gtk_tree_view_column_new_with_attributes("", renderer, "icon-name", COL_ICON, NULL);
  gtk_tree_view_append_column(GTK_TREE_VIEW(data.tree_view), column);

  // Name column
  renderer = gtk_cell_renderer_text_new();
  column = gtk_tree_view_column_new_with_attributes("Name", renderer, "text", COL_NAME, NULL);
  gtk_tree_view_append_column(GTK_TREE_VIEW(data.tree_view), column);

  gtk_container_add(GTK_CONTAINER(scroll), data.tree_view);

  // Status label
  data.status_label = gtk_label_new("");
  gtk_label_set_xalign(GTK_LABEL(data.status_label), 0.0);
  gtk_box_pack_start(GTK_BOX(content_area), data.status_label, FALSE, FALSE, 0);

  gtk_widget_show_all(data.dialog);

  load_directory(&data, data.current_loc->path);

  gtk_dialog_run(GTK_DIALOG(data.dialog));
  
  remote_ssh_location_free(data.current_loc);
  g_object_unref(data.list_store);
  if (GTK_IS_WIDGET(data.dialog)) {
    gtk_widget_destroy(data.dialog);
  }
}
