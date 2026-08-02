#ifndef LEDGERFORGE_LEGACY_XLS_BRIDGE_H
#define LEDGERFORGE_LEGACY_XLS_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LF_XLS_DOCUMENT LF_XLS_DOCUMENT;

typedef enum LF_XLS_ERROR {
    LF_XLS_ERROR_OK = 0,
    LF_XLS_ERROR_INVALID_ARGUMENT,
    LF_XLS_ERROR_SOURCE_TOO_LARGE,
    LF_XLS_ERROR_INVALID_CONTAINER,
    LF_XLS_ERROR_TRUNCATED,
    LF_XLS_ERROR_MALFORMED,
    LF_XLS_ERROR_ALLOCATION,
    LF_XLS_ERROR_UNSUPPORTED_ENCRYPTION,
    LF_XLS_ERROR_MULTIPLE_SHEETS,
    LF_XLS_ERROR_HIDDEN_SHEET,
    LF_XLS_ERROR_UNSUPPORTED_SHEET_KIND,
    LF_XLS_ERROR_DIMENSIONS_EXCEEDED,
    LF_XLS_ERROR_FORMULA_CELL,
    LF_XLS_ERROR_BOOLEAN_OR_ERROR_CELL,
    LF_XLS_ERROR_HIDDEN_CELL,
    LF_XLS_ERROR_STRING_ALLOCATION_EXCEEDED
} LF_XLS_ERROR;

typedef enum LF_XLS_CELL_KIND {
    LF_XLS_CELL_BLANK = 0,
    LF_XLS_CELL_STRING,
    LF_XLS_CELL_NUMBER
} LF_XLS_CELL_KIND;

LF_XLS_DOCUMENT *lf_xls_open_buffer(
    const uint8_t *bytes,
    size_t byte_count,
    LF_XLS_ERROR *out_error
);

void lf_xls_close(LF_XLS_DOCUMENT *document);

const char *lf_xls_sheet_name(const LF_XLS_DOCUMENT *document);
uint32_t lf_xls_row_count(const LF_XLS_DOCUMENT *document);
uint32_t lf_xls_column_count(const LF_XLS_DOCUMENT *document);

LF_XLS_CELL_KIND lf_xls_cell_kind(
    const LF_XLS_DOCUMENT *document,
    uint32_t row,
    uint32_t column
);

const char *lf_xls_cell_string(
    const LF_XLS_DOCUMENT *document,
    uint32_t row,
    uint32_t column
);

double lf_xls_cell_number(
    const LF_XLS_DOCUMENT *document,
    uint32_t row,
    uint32_t column
);

#ifdef __cplusplus
}
#endif

#endif
