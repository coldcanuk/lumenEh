#ifndef VIEWMD_BOOKMARKS_H
#define VIEWMD_BOOKMARKS_H

#include <glib.h>

typedef struct {
  gchar *uri;
  gchar *display_name;
} ViewmdBookmark;

void viewmd_bookmarks_load(void);
void viewmd_bookmarks_save(void);
void viewmd_bookmark_add(const gchar *uri);
gboolean viewmd_bookmark_remove(const gchar *uri);
GPtrArray *viewmd_bookmarks_get_all(void);
void viewmd_bookmarks_free(void);

#endif
