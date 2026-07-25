#include "bookmarks.h"
#include <glib/gstdio.h>
#include <stdlib.h>

static GPtrArray *bookmarks = NULL;

static gchar *get_bookmarks_file_path(void) {
  gchar *config_dir = g_build_filename(g_get_user_config_dir(), "viewmd", NULL);
  g_mkdir_with_parents(config_dir, 0700);
  gchar *path = g_build_filename(config_dir, "bookmarks.txt", NULL);
  g_free(config_dir);
  return path;
}

static void free_bookmark(gpointer data) {
  ViewmdBookmark *bm = (ViewmdBookmark *)data;
  if (bm) {
    g_free(bm->uri);
    g_free(bm->display_name);
    g_free(bm);
  }
}

void viewmd_bookmarks_load(void) {
  gchar *path = get_bookmarks_file_path();
  gchar *contents = NULL;
  gsize length = 0;

  if (!bookmarks) {
    bookmarks = g_ptr_array_new_with_free_func(free_bookmark);
  } else {
    g_ptr_array_set_size(bookmarks, 0);
  }

  if (g_file_get_contents(path, &contents, &length, NULL)) {
    gchar **lines = g_strsplit(contents, "\n", -1);
    for (gint i = 0; lines[i] != NULL; i++) {
      gchar *line = g_strstrip(lines[i]);
      if (line[0] != '\0') {
        ViewmdBookmark *bm = g_new0(ViewmdBookmark, 1);
        bm->uri = g_strdup(line);
        bm->display_name = g_strdup(line); // Just use URI for now
        g_ptr_array_add(bookmarks, bm);
      }
    }
    g_strfreev(lines);
    g_free(contents);
  }
  g_free(path);
}

void viewmd_bookmarks_save(void) {
  if (!bookmarks) return;
  gchar *path = get_bookmarks_file_path();
  GString *str = g_string_new("");

  for (guint i = 0; i < bookmarks->len; i++) {
    ViewmdBookmark *bm = g_ptr_array_index(bookmarks, i);
    g_string_append_printf(str, "%s\n", bm->uri);
  }

  g_file_set_contents(path, str->str, str->len, NULL);
  g_string_free(str, TRUE);
  g_free(path);
}

void viewmd_bookmark_add(const gchar *uri) {
  if (!bookmarks) {
    viewmd_bookmarks_load();
  }
  
  // Check if it already exists
  for (guint i = 0; i < bookmarks->len; i++) {
    ViewmdBookmark *bm = g_ptr_array_index(bookmarks, i);
    if (g_strcmp0(bm->uri, uri) == 0) {
      return; // Already bookmarked
    }
  }

  ViewmdBookmark *bm = g_new0(ViewmdBookmark, 1);
  bm->uri = g_strdup(uri);
  bm->display_name = g_strdup(uri);
  g_ptr_array_add(bookmarks, bm);
  viewmd_bookmarks_save();
}

gboolean viewmd_bookmark_remove(const gchar *uri) {
  if (!bookmarks) {
    viewmd_bookmarks_load();
  }
  for (guint i = 0; i < bookmarks->len; i++) {
    ViewmdBookmark *bm = g_ptr_array_index(bookmarks, i);
    if (g_strcmp0(bm->uri, uri) == 0) {
      g_ptr_array_remove_index(bookmarks, i);
      viewmd_bookmarks_save();
      return TRUE;
    }
  }
  return FALSE;
}

GPtrArray *viewmd_bookmarks_get_all(void) {
  if (!bookmarks) {
    viewmd_bookmarks_load();
  }
  return bookmarks;
}

void viewmd_bookmarks_free(void) {
  if (bookmarks) {
    g_ptr_array_free(bookmarks, TRUE);
    bookmarks = NULL;
  }
}
