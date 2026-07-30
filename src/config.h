#ifndef LUMENEH_CONFIG_H
#define LUMENEH_CONFIG_H

#include <glib.h>

/* Settings structure */
typedef struct _LumenehConfig {
  /* Window geometry */
  gint window_x;
  gint window_y;
  gint window_width;
  gint window_height;
  gboolean window_maximized;

  /* Appearance */
  gchar *font_family;
  gint font_size; /* in points */
  gchar *theme;   /* "dark", "light", "system" */

  /* Markdown accent colors */
  gchar *h1_color;
  gchar *h2_color;
  gchar *h3_color;
  gchar *list_bullet_color;

  /* Editor */
  gboolean line_numbers;
  gboolean word_wrap;
} LumenehConfig;

/* Global config instance */
extern LumenehConfig *config;

/* Lifecycle */
LumenehConfig *config_new(void);
void config_free(LumenehConfig *cfg);

/* Load/Save */
gboolean config_load(LumenehConfig *cfg);
gboolean config_save(LumenehConfig *cfg);

/* Get config file path */
const gchar *config_get_path(void);

#endif /* LUMENEH_CONFIG_H */
