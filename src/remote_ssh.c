#include "remote_ssh.h"
#include <glib/gstdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef WIFEXITED
#define WIFEXITED(status) (((status)&0x7f) == 0)
#endif
#ifndef WEXITSTATUS
#define WEXITSTATUS(status) (((status)&0xff00) >> 8)
#endif

gboolean remote_ssh_is_remote_uri(const gchar *uri) {
  if (!uri || uri[0] == '\0') {
    return FALSE;
  }

  if (g_str_has_prefix(uri, "ssh://") || g_str_has_prefix(uri, "sftp://")) {
    return TRUE;
  }

  /* Check for SCP-style format: [user@]host:/path/to/file */
  const gchar *colon = strchr(uri, ':');
  const gchar *slash = strchr(uri, '/');

  if (colon != NULL && (slash == NULL || colon < slash)) {
    /* Avoid matching Windows drive letters e.g. C:\ */
    if ((colon - uri) > 1) {
      return TRUE;
    }
  }

  return FALSE;
}

RemoteSSHLocation *remote_ssh_parse_uri(const gchar *uri) {
  RemoteSSHLocation *loc;
  const gchar *p;
  gchar *user_host_port = NULL;

  if (!uri || !remote_ssh_is_remote_uri(uri)) {
    return NULL;
  }

  loc = g_new0(RemoteSSHLocation, 1);
  loc->raw_uri = g_strdup(uri);
  loc->port = 0;

  if (g_str_has_prefix(uri, "ssh://") || g_str_has_prefix(uri, "sftp://")) {
    p = strstr(uri, "://") + 3;
    const gchar *path_sep = strchr(p, '/');

    if (path_sep) {
      user_host_port = g_strndup(p, (gsize)(path_sep - p));
      loc->path = g_strdup(path_sep);
    } else {
      user_host_port = g_strdup(p);
      loc->path = g_strdup("");
    }
  } else {
    /* SCP format: [user@]host:path */
    const gchar *colon = strchr(uri, ':');
    user_host_port = g_strndup(uri, (gsize)(colon - uri));
    loc->path = g_strdup(colon + 1);
  }

  /* Parse user@host:port from user_host_port */
  gchar *at = strchr(user_host_port, '@');
  const gchar *host_port = user_host_port;

  if (at) {
    loc->user = g_strndup(user_host_port, (gsize)(at - user_host_port));
    host_port = at + 1;
  }

  gchar *colon = strchr(host_port, ':');
  if (colon) {
    loc->host = g_strndup(host_port, (gsize)(colon - host_port));
    loc->port = atoi(colon + 1);
  } else {
    loc->host = g_strdup(host_port);
  }

  g_free(user_host_port);
  return loc;
}

void remote_ssh_location_free(RemoteSSHLocation *loc) {
  if (!loc) {
    return;
  }
  g_free(loc->user);
  g_free(loc->host);
  g_free(loc->path);
  g_free(loc->raw_uri);
  g_free(loc);
}

static void build_ssh_args(const RemoteSSHLocation *loc, GPtrArray *args,
                          const gchar *remote_cmd) {
  g_ptr_array_add(args, g_strdup("ssh"));
  g_ptr_array_add(args, g_strdup("-o"));
  g_ptr_array_add(args, g_strdup("BatchMode=yes"));
  g_ptr_array_add(args, g_strdup("-o"));
  g_ptr_array_add(args, g_strdup("ConnectTimeout=10"));

  if (loc->port > 0) {
    g_ptr_array_add(args, g_strdup("-p"));
    g_ptr_array_add(args, g_strdup_printf("%d", loc->port));
  }

  if (loc->user && loc->user[0] != '\0') {
    g_ptr_array_add(args, g_strdup_printf("%s@%s", loc->user, loc->host));
  } else {
    g_ptr_array_add(args, g_strdup(loc->host));
  }

  g_ptr_array_add(args, g_strdup(remote_cmd));
  g_ptr_array_add(args, NULL);
}

gboolean remote_ssh_fetch_file(const RemoteSSHLocation *loc,
                               gchar **out_content,
                               gsize *out_len,
                               GError **error) {
  GPtrArray *args;
  gchar *remote_cmd;
  gchar *stdout_buf = NULL;
  gchar *stderr_buf = NULL;
  gsize length = 0;
  gint exit_status = 0;
  GError *spawn_err = NULL;

  if (!loc || !loc->host || !loc->path || !out_content) {
    if (error) {
      *error = g_error_new(G_SPAWN_ERROR, G_SPAWN_ERROR_FAILED,
                           "Invalid SSH location arguments");
    }
    return FALSE;
  }

  *out_content = NULL;
  if (out_len) {
    *out_len = 0;
  }

  /* Construct command e.g. cat '/remote/path' */
  remote_cmd = g_strdup_printf("cat '%s'", loc->path);

  args = g_ptr_array_new_with_free_func(g_free);
  build_ssh_args(loc, args, remote_cmd);
  g_free(remote_cmd);

  gboolean ok = g_spawn_sync(
      NULL, (gchar **)args->pdata, NULL, G_SPAWN_SEARCH_PATH, NULL, NULL,
      &stdout_buf, &stderr_buf, &exit_status, &spawn_err);

  g_ptr_array_free(args, TRUE);

  if (!ok) {
    if (error && spawn_err) {
      *error = spawn_err;
    } else if (spawn_err) {
      g_error_free(spawn_err);
    }
    g_free(stdout_buf);
    g_free(stderr_buf);
    return FALSE;
  }

  if (!WIFEXITED(exit_status) || WEXITSTATUS(exit_status) != 0) {
    if (error) {
      *error = g_error_new(G_SPAWN_ERROR, G_SPAWN_ERROR_FAILED,
                           "SSH process failed: %s",
                           (stderr_buf && stderr_buf[0]) ? stderr_buf
                                                         : "unknown SSH error");
    }
    g_free(stdout_buf);
    g_free(stderr_buf);
    return FALSE;
  }

  g_free(stderr_buf);
  length = stdout_buf ? strlen(stdout_buf) : 0;
  *out_content = stdout_buf;
  if (out_len) {
    *out_len = length;
  }
  return TRUE;
}

gchar *remote_ssh_fetch_image_asset(const RemoteSSHLocation *doc_loc,
                                    const gchar *relative_src,
                                    GError **error) {
  gchar *remote_dir;
  gchar *remote_image_path;
  RemoteSSHLocation img_loc;
  gchar *image_data = NULL;
  gsize image_len = 0;
  gchar *cache_dir;
  gchar *cache_path;
  gchar *sha1_hex;

  if (!doc_loc || !relative_src || relative_src[0] == '\0') {
    return NULL;
  }

  remote_dir = g_path_get_dirname(doc_loc->path);
  remote_image_path = g_build_filename(remote_dir, relative_src, NULL);
  g_free(remote_dir);

  img_loc = *doc_loc;
  img_loc.path = remote_image_path;

  if (!remote_ssh_fetch_file(&img_loc, &image_data, &image_len, error)) {
    g_free(remote_image_path);
    return NULL;
  }
  g_free(remote_image_path);

  /* Build local cache directory */
  cache_dir = g_build_filename(g_get_user_cache_dir(), "viewmd", "remote_cache", NULL);
  g_mkdir_with_parents(cache_dir, 0700);

  sha1_hex = g_compute_checksum_for_string(G_CHECKSUM_SHA1, relative_src, -1);
  gchar *basename = g_path_get_basename(relative_src);
  gchar *filename = g_strdup_printf("%s_%s", sha1_hex, basename);
  cache_path = g_build_filename(cache_dir, filename, NULL);

  g_free(sha1_hex);
  g_free(basename);
  g_free(filename);
  g_free(cache_dir);

  if (!g_file_set_contents(cache_path, image_data, (gssize)image_len, error)) {
    g_free(image_data);
    g_free(cache_path);
    return NULL;
  }

  g_free(image_data);
  return cache_path;
}

gboolean remote_ssh_list_dir(const RemoteSSHLocation *loc, GPtrArray **out_items, GError **error) {
  GPtrArray *args;
  gchar *remote_cmd;
  gchar *stdout_buf = NULL;
  gchar *stderr_buf = NULL;
  gint exit_status = 0;
  GError *spawn_err = NULL;

  if (!loc || !loc->host || !loc->path || !out_items) {
    if (error) {
      *error = g_error_new(G_SPAWN_ERROR, G_SPAWN_ERROR_FAILED, "Invalid SSH location arguments");
    }
    return FALSE;
  }

  if (!loc->path || loc->path[0] == '\0') {
    remote_cmd = g_strdup("/bin/ls -1p");
  } else {
    remote_cmd = g_strdup_printf("/bin/ls -1p '%s'", loc->path);
  }

  args = g_ptr_array_new_with_free_func(g_free);
  build_ssh_args(loc, args, remote_cmd);
  g_free(remote_cmd);

  gboolean ok = g_spawn_sync(
      NULL, (gchar **)args->pdata, NULL, G_SPAWN_SEARCH_PATH, NULL, NULL,
      &stdout_buf, &stderr_buf, &exit_status, &spawn_err);

  g_ptr_array_free(args, TRUE);

  if (!ok || !WIFEXITED(exit_status) || WEXITSTATUS(exit_status) != 0) {
    if (error) {
      if (spawn_err) {
        *error = spawn_err;
        spawn_err = NULL;
      } else {
        *error = g_error_new(G_SPAWN_ERROR, G_SPAWN_ERROR_FAILED,
                             "SSH list dir failed: %s",
                             (stderr_buf && stderr_buf[0]) ? stderr_buf : "unknown");
      }
    } else if (spawn_err) {
      g_error_free(spawn_err);
    }
    g_free(stdout_buf);
    g_free(stderr_buf);
    return FALSE;
  }
  g_free(stderr_buf);

  *out_items = g_ptr_array_new_with_free_func(g_free);
  if (stdout_buf) {
    gchar **lines = g_strsplit(stdout_buf, "\n", -1);
    for (gint i = 0; lines[i] != NULL; i++) {
      gchar *line = g_strstrip(lines[i]);
      if (line[0] != '\0') {
        g_ptr_array_add(*out_items, g_strdup(line));
      }
    }
    g_strfreev(lines);
  }
  g_free(stdout_buf);

  return TRUE;
}

