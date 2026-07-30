#ifndef LUMENEH_REMOTE_SSH_H
#define LUMENEH_REMOTE_SSH_H

#include <glib.h>

typedef struct {
  gchar *user;     /* Remote username, or NULL if default */
  gchar *host;     /* Remote host or IP */
  gint port;       /* SSH port, e.g. 22, or 0 if default */
  gchar *path;     /* Remote file path */
  gchar *raw_uri;  /* Original input string */
} RemoteSSHLocation;

/* Returns TRUE if uri matches ssh://, sftp://, or user@host:path format */
gboolean remote_ssh_is_remote_uri(const gchar *uri);

/* Parses a remote URI into a RemoteSSHLocation struct. Caller owns result. */
RemoteSSHLocation *remote_ssh_parse_uri(const gchar *uri);

/* Frees a RemoteSSHLocation struct */
void remote_ssh_location_free(RemoteSSHLocation *loc);

/* Fetches a remote text file over SSH using 'ssh cat'. Out content caller-freed. */
gboolean remote_ssh_fetch_file(const RemoteSSHLocation *loc,
                               gchar **out_content,
                               gsize *out_len,
                               GError **error);

/* Fetches a remote relative image file over SSH and saves to local cache.
   Returns local cached file path (caller-freed) or NULL on error. */
gchar *remote_ssh_fetch_image_asset(const RemoteSSHLocation *doc_loc,
                                    const gchar *relative_src,
                                    GError **error);

/* Lists contents of a remote directory over SSH. */
gboolean remote_ssh_list_dir(const RemoteSSHLocation *loc,
                             GPtrArray **out_items,
                             GError **error);

#endif /* LUMENEH_REMOTE_SSH_H */
