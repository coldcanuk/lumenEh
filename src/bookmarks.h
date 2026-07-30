#ifndef LUMENEH_BOOKMARKS_H
#define LUMENEH_BOOKMARKS_H

#include <glib.h>

typedef struct {
  gchar *host_uri;
  gchar *display_name;
  GPtrArray *paths; /* Array of gchar* */
} LumenehBookmarkHost;

void lumeneh_bookmarks_load(void);
void lumeneh_bookmarks_save(void);

/* Host operations */
LumenehBookmarkHost *lumeneh_bookmark_host_add(const gchar *host_uri, const gchar *display_name);
gboolean lumeneh_bookmark_host_remove(const gchar *host_uri);
LumenehBookmarkHost *lumeneh_bookmark_host_get(const gchar *host_uri);
GPtrArray *lumeneh_bookmarks_get_hosts(void); /* Array of LumenehBookmarkHost* */

/* Path operations */
gboolean lumeneh_bookmark_path_add(const gchar *host_uri, const gchar *path);
gboolean lumeneh_bookmark_path_remove(const gchar *host_uri, const gchar *path);

void lumeneh_bookmarks_free(void);

#endif
