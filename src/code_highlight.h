#ifndef LUMENEH_CODE_HIGHLIGHT_H
#define LUMENEH_CODE_HIGHLIGHT_H

#include <glib.h>

#define LUMENEH_TAG_CODE_KW_A "code_kw_a"
#define LUMENEH_TAG_CODE_KW_B "code_kw_b"
#define LUMENEH_TAG_CODE_KW_C "code_kw_c"
#define LUMENEH_TAG_CODE_LITERAL "code_literal"

typedef struct _LumenehKeywordGroup {
  const gchar *tag_name;
  const gchar *const *keywords;
  gsize keyword_count;
} LumenehKeywordGroup;

typedef struct _LumenehCodeScanState {
  guint32 flags;
} LumenehCodeScanState;

typedef void (*LumenehCodeTokenCallback)(gint start_char_offset,
                                        gint end_char_offset,
                                        const gchar *tag_name,
                                        gpointer user_data);

struct _LumenehLanguageHighlight;

typedef void (*LumenehCodeScanLineFunc)(
    const struct _LumenehLanguageHighlight *language, const gchar *line,
    LumenehCodeScanState *state, LumenehCodeTokenCallback on_token,
    gpointer user_data);

typedef struct _LumenehLanguageHighlight {
  const gchar *language;
  const LumenehKeywordGroup *groups;
  gsize group_count;
  LumenehCodeScanLineFunc scan_line;
} LumenehLanguageHighlight;

/* Lookup by optional fenced code language (case-insensitive), e.g. "c". */
const LumenehLanguageHighlight *
lumeneh_code_lookup_language(const gchar *language);

/* Reset scan state, e.g. when entering/exiting fenced code blocks. */
void lumeneh_code_scan_state_reset(LumenehCodeScanState *state);

/* Scan one code line and emit syntax token ranges via callback. */
void lumeneh_code_scan_line(const LumenehLanguageHighlight *language,
                           const gchar *line, LumenehCodeScanState *state,
                           LumenehCodeTokenCallback on_token,
                           gpointer user_data);

#endif /* LUMENEH_CODE_HIGHLIGHT_H */
