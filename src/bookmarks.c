#include "bookmarks.h"
#include <glib/gstdio.h>
#include <stdlib.h>

static GPtrArray *hosts = NULL;

static gchar *get_bookmarks_file_path(void) {
  gchar *config_dir = g_build_filename(g_get_user_config_dir(), "lumeneh", NULL);
  g_mkdir_with_parents(config_dir, 0700);
  gchar *path = g_build_filename(config_dir, "bookmarks.ini", NULL);
  g_free(config_dir);
  return path;
}

static void free_bookmark_host(gpointer data) {
  LumenehBookmarkHost *host = (LumenehBookmarkHost *)data;
  if (host) {
    g_free(host->host_uri);
    g_free(host->display_name);
    if (host->paths) {
      g_ptr_array_free(host->paths, TRUE);
    }
    g_free(host);
  }
}

void lumeneh_bookmarks_load(void) {
  gchar *path = get_bookmarks_file_path();
  GKeyFile *kf = g_key_file_new();

  if (!hosts) {
    hosts = g_ptr_array_new_with_free_func(free_bookmark_host);
  } else {
    g_ptr_array_set_size(hosts, 0);
  }

  if (g_key_file_load_from_file(kf, path, G_KEY_FILE_NONE, NULL)) {
    gsize num_groups;
    gchar **groups = g_key_file_get_groups(kf, &num_groups);
    for (gsize i = 0; i < num_groups; i++) {
      gchar *host_uri = groups[i];
      gchar *display_name = g_key_file_get_string(kf, host_uri, "name", NULL);
      if (!display_name) {
        display_name = g_strdup(host_uri);
      }

      LumenehBookmarkHost *h = g_new0(LumenehBookmarkHost, 1);
      h->host_uri = g_strdup(host_uri);
      h->display_name = display_name;
      h->paths = g_ptr_array_new_with_free_func(g_free);

      gsize num_paths = 0;
      gchar **paths_list = g_key_file_get_string_list(kf, host_uri, "paths", &num_paths, NULL);
      if (paths_list) {
        for (gsize j = 0; j < num_paths; j++) {
          if (paths_list[j] && paths_list[j][0] != '\0') {
            g_ptr_array_add(h->paths, g_strdup(paths_list[j]));
          }
        }
        g_strfreev(paths_list);
      }
      g_ptr_array_add(hosts, h);
    }
    g_strfreev(groups);
  }
  g_key_file_free(kf);
  g_free(path);
}

void lumeneh_bookmarks_save(void) {
  if (!hosts) return;
  gchar *path = get_bookmarks_file_path();
  GKeyFile *kf = g_key_file_new();

  for (guint i = 0; i < hosts->len; i++) {
    LumenehBookmarkHost *h = g_ptr_array_index(hosts, i);
    g_key_file_set_string(kf, h->host_uri, "name", h->display_name);
    
    if (h->paths && h->paths->len > 0) {
      gchar **str_list = g_new0(gchar*, h->paths->len + 1);
      for (guint j = 0; j < h->paths->len; j++) {
        str_list[j] = g_ptr_array_index(h->paths, j);
      }
      g_key_file_set_string_list(kf, h->host_uri, "paths", (const gchar* const*)str_list, h->paths->len);
      g_free(str_list);
    }
  }

  g_key_file_save_to_file(kf, path, NULL);
  g_key_file_free(kf);
  g_free(path);
}

LumenehBookmarkHost *lumeneh_bookmark_host_get(const gchar *host_uri) {
  if (!hosts) {
    lumeneh_bookmarks_load();
  }
  for (guint i = 0; i < hosts->len; i++) {
    LumenehBookmarkHost *h = g_ptr_array_index(hosts, i);
    if (g_strcmp0(h->host_uri, host_uri) == 0) {
      return h;
    }
  }
  return NULL;
}

LumenehBookmarkHost *lumeneh_bookmark_host_add(const gchar *host_uri, const gchar *display_name) {
  LumenehBookmarkHost *h = lumeneh_bookmark_host_get(host_uri);
  if (h) {
    if (display_name && g_strcmp0(h->display_name, display_name) != 0) {
      g_free(h->display_name);
      h->display_name = g_strdup(display_name);
      lumeneh_bookmarks_save();
    }
    return h;
  }

  h = g_new0(LumenehBookmarkHost, 1);
  h->host_uri = g_strdup(host_uri);
  h->display_name = display_name ? g_strdup(display_name) : g_strdup(host_uri);
  h->paths = g_ptr_array_new_with_free_func(g_free);
  
  g_ptr_array_add(hosts, h);
  lumeneh_bookmarks_save();
  return h;
}

gboolean lumeneh_bookmark_host_remove(const gchar *host_uri) {
  if (!hosts) lumeneh_bookmarks_load();
  for (guint i = 0; i < hosts->len; i++) {
    LumenehBookmarkHost *h = g_ptr_array_index(hosts, i);
    if (g_strcmp0(h->host_uri, host_uri) == 0) {
      g_ptr_array_remove_index(hosts, i);
      lumeneh_bookmarks_save();
      return TRUE;
    }
  }
  return FALSE;
}

GPtrArray *lumeneh_bookmarks_get_hosts(void) {
  if (!hosts) {
    lumeneh_bookmarks_load();
  }
  return hosts;
}

gboolean lumeneh_bookmark_path_add(const gchar *host_uri, const gchar *path) {
  LumenehBookmarkHost *h = lumeneh_bookmark_host_get(host_uri);
  if (!h) {
    h = lumeneh_bookmark_host_add(host_uri, NULL);
  }
  
  for (guint i = 0; i < h->paths->len; i++) {
    if (g_strcmp0(g_ptr_array_index(h->paths, i), path) == 0) {
      return FALSE; // already exists
    }
  }
  
  g_ptr_array_add(h->paths, g_strdup(path));
  lumeneh_bookmarks_save();
  return TRUE;
}

gboolean lumeneh_bookmark_path_remove(const gchar *host_uri, const gchar *path) {
  LumenehBookmarkHost *h = lumeneh_bookmark_host_get(host_uri);
  if (!h) return FALSE;
  
  for (guint i = 0; i < h->paths->len; i++) {
    if (g_strcmp0(g_ptr_array_index(h->paths, i), path) == 0) {
      g_ptr_array_remove_index(h->paths, i);
      lumeneh_bookmarks_save();
      return TRUE;
    }
  }
  return FALSE;
}

void lumeneh_bookmarks_free(void) {
  if (hosts) {
    g_ptr_array_free(hosts, TRUE);
    hosts = NULL;
  }
}
