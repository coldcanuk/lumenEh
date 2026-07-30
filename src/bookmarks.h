#ifndef VIEWMD_BOOKMARKS_H
#define VIEWMD_BOOKMARKS_H

#include <glib.h>

typedef struct {
  gchar *host_uri;
  gchar *display_name;
  GPtrArray *paths; /* Array of gchar* */
} ViewmdBookmarkHost;

void viewmd_bookmarks_load(void);
void viewmd_bookmarks_save(void);

/* Host operations */
ViewmdBookmarkHost *viewmd_bookmark_host_add(const gchar *host_uri, const gchar *display_name);
gboolean viewmd_bookmark_host_remove(const gchar *host_uri);
ViewmdBookmarkHost *viewmd_bookmark_host_get(const gchar *host_uri);
GPtrArray *viewmd_bookmarks_get_hosts(void); /* Array of ViewmdBookmarkHost* */

/* Path operations */
gboolean viewmd_bookmark_path_add(const gchar *host_uri, const gchar *path);
gboolean viewmd_bookmark_path_remove(const gchar *host_uri, const gchar *path);

void viewmd_bookmarks_free(void);

#endif
