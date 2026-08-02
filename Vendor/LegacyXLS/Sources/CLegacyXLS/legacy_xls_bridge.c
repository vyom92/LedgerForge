#include "legacy_xls_bridge.h"

#include <stdlib.h>
#include <string.h>

#include "config.h"
#include "xls.h"

#define LF_XLS_MAX_SOURCE_BYTES (64U * 1024U * 1024U)
#define LF_XLS_MAX_STRING_BYTES (16U * 1024U * 1024U)

struct LF_XLS_DOCUMENT {
    xlsWorkBook *workbook;
    xlsWorkSheet *worksheet;
};

static void lf_xls_set_error(LF_XLS_ERROR *out_error, LF_XLS_ERROR error) {
    if (out_error != NULL) {
        *out_error = error;
    }
}

static LF_XLS_ERROR lf_xls_map_error(xls_error_t error) {
    switch (error) {
    case LIBXLS_OK:
        return LF_XLS_ERROR_OK;
    case LIBXLS_ERROR_OPEN:
        return LF_XLS_ERROR_INVALID_CONTAINER;
    case LIBXLS_ERROR_SEEK:
    case LIBXLS_ERROR_READ:
        return LF_XLS_ERROR_TRUNCATED;
    case LIBXLS_ERROR_MALLOC:
        return LF_XLS_ERROR_ALLOCATION;
    case LIBXLS_ERROR_UNSUPPORTED_ENCRYPTION:
        return LF_XLS_ERROR_UNSUPPORTED_ENCRYPTION;
    case LIBXLS_ERROR_NULL_ARGUMENT:
        return LF_XLS_ERROR_INVALID_ARGUMENT;
    case LIBXLS_ERROR_PARSE:
    default:
        return LF_XLS_ERROR_MALFORMED;
    }
}

static void lf_xls_release_parts(
    xlsWorkBook *workbook,
    xlsWorkSheet *worksheet
) {
    if (worksheet != NULL) {
        xls_close_WS(worksheet);
    }
    if (workbook != NULL) {
        xls_close_WB(workbook);
    }
}

static xlsCell *lf_xls_cell(
    const LF_XLS_DOCUMENT *document,
    uint32_t row,
    uint32_t column
) {
    if (document == NULL || document->worksheet == NULL
        || row >= lf_xls_row_count(document)
        || column >= lf_xls_column_count(document)) {
        return NULL;
    }
    return xls_cell(document->worksheet, (WORD)row, (WORD)column);
}

LF_XLS_DOCUMENT *lf_xls_open_buffer(
    const uint8_t *bytes,
    size_t byte_count,
    LF_XLS_ERROR *out_error
) {
    lf_xls_set_error(out_error, LF_XLS_ERROR_OK);
    if (bytes == NULL || byte_count == 0) {
        lf_xls_set_error(out_error, LF_XLS_ERROR_INVALID_ARGUMENT);
        return NULL;
    }
    if (byte_count > LF_XLS_MAX_SOURCE_BYTES) {
        lf_xls_set_error(out_error, LF_XLS_ERROR_SOURCE_TOO_LARGE);
        return NULL;
    }

    xls_error_t open_error = LIBXLS_OK;
    xlsWorkBook *workbook = xls_open_buffer(
        bytes,
        byte_count,
        "UTF-8",
        &open_error
    );
    if (workbook == NULL) {
        lf_xls_set_error(out_error, lf_xls_map_error(open_error));
        return NULL;
    }

    if (workbook->sheets.count != 1U) {
        lf_xls_release_parts(workbook, NULL);
        lf_xls_set_error(out_error, LF_XLS_ERROR_MULTIPLE_SHEETS);
        return NULL;
    }
    /* libxls 1.6.3 exposes the BIFF BOUNDSHEET type byte as visibility and
       the visibility byte as type; interpret the underlying bytes here. */
    if ((workbook->sheets.sheet[0].visibility & 0x0FU) != 0U) {
        lf_xls_release_parts(workbook, NULL);
        lf_xls_set_error(out_error, LF_XLS_ERROR_UNSUPPORTED_SHEET_KIND);
        return NULL;
    }
    if (workbook->sheets.sheet[0].type != 0U) {
        lf_xls_release_parts(workbook, NULL);
        lf_xls_set_error(out_error, LF_XLS_ERROR_HIDDEN_SHEET);
        return NULL;
    }

    xlsWorkSheet *worksheet = xls_getWorkSheet(workbook, 0);
    if (worksheet == NULL) {
        lf_xls_release_parts(workbook, NULL);
        lf_xls_set_error(out_error, LF_XLS_ERROR_ALLOCATION);
        return NULL;
    }

    xls_error_t parse_error = xls_parseWorkSheet(worksheet);
    if (parse_error != LIBXLS_OK) {
        LF_XLS_ERROR mapped = lf_xls_map_error(parse_error);
        uint64_t rows = (uint64_t)worksheet->rows.lastrow + 1U;
        uint64_t columns = (uint64_t)worksheet->rows.lastcol + 1U;
        if (rows > LEDGERFORGE_LIBXLS_MAX_ROWS
            || columns > LEDGERFORGE_LIBXLS_MAX_COLUMNS
            || rows * columns > LEDGERFORGE_LIBXLS_MAX_CELLS) {
            mapped = LF_XLS_ERROR_DIMENSIONS_EXCEEDED;
        }
        lf_xls_release_parts(workbook, worksheet);
        lf_xls_set_error(out_error, mapped);
        return NULL;
    }

    uint64_t rows = (uint64_t)worksheet->rows.lastrow + 1U;
    uint64_t columns = (uint64_t)worksheet->rows.lastcol + 1U;
    if (rows > LEDGERFORGE_LIBXLS_MAX_ROWS
        || columns > LEDGERFORGE_LIBXLS_MAX_COLUMNS
        || rows * columns > LEDGERFORGE_LIBXLS_MAX_CELLS) {
        lf_xls_release_parts(workbook, worksheet);
        lf_xls_set_error(out_error, LF_XLS_ERROR_DIMENSIONS_EXCEEDED);
        return NULL;
    }

    size_t string_bytes = 0;
    for (uint32_t row = 0; row < rows; row++) {
        for (uint32_t column = 0; column < columns; column++) {
            xlsCell *cell = xls_cell(worksheet, (WORD)row, (WORD)column);
            if (cell == NULL) {
                lf_xls_release_parts(workbook, worksheet);
                lf_xls_set_error(out_error, LF_XLS_ERROR_MALFORMED);
                return NULL;
            }
            if (cell->id == XLS_RECORD_FORMULA
                || cell->id == XLS_RECORD_FORMULA_ALT) {
                lf_xls_release_parts(workbook, worksheet);
                lf_xls_set_error(out_error, LF_XLS_ERROR_FORMULA_CELL);
                return NULL;
            }
            if (cell->id == XLS_RECORD_BOOLERR) {
                lf_xls_release_parts(workbook, worksheet);
                lf_xls_set_error(out_error, LF_XLS_ERROR_BOOLEAN_OR_ERROR_CELL);
                return NULL;
            }
            if (cell->isHidden != 0U) {
                lf_xls_release_parts(workbook, worksheet);
                lf_xls_set_error(out_error, LF_XLS_ERROR_HIDDEN_CELL);
                return NULL;
            }
            if (cell->str != NULL) {
                size_t length = strlen(cell->str);
                if (length > LF_XLS_MAX_STRING_BYTES - string_bytes) {
                    lf_xls_release_parts(workbook, worksheet);
                    lf_xls_set_error(
                        out_error,
                        LF_XLS_ERROR_STRING_ALLOCATION_EXCEEDED
                    );
                    return NULL;
                }
                string_bytes += length;
            }
        }
    }

    LF_XLS_DOCUMENT *document = calloc(1, sizeof(LF_XLS_DOCUMENT));
    if (document == NULL) {
        lf_xls_release_parts(workbook, worksheet);
        lf_xls_set_error(out_error, LF_XLS_ERROR_ALLOCATION);
        return NULL;
    }
    document->workbook = workbook;
    document->worksheet = worksheet;
    return document;
}

void lf_xls_close(LF_XLS_DOCUMENT *document) {
    if (document == NULL) {
        return;
    }
    lf_xls_release_parts(document->workbook, document->worksheet);
    document->workbook = NULL;
    document->worksheet = NULL;
    free(document);
}

const char *lf_xls_sheet_name(const LF_XLS_DOCUMENT *document) {
    if (document == NULL || document->workbook == NULL
        || document->workbook->sheets.count != 1U) {
        return NULL;
    }
    return document->workbook->sheets.sheet[0].name;
}

uint32_t lf_xls_row_count(const LF_XLS_DOCUMENT *document) {
    if (document == NULL || document->worksheet == NULL) {
        return 0;
    }
    return (uint32_t)document->worksheet->rows.lastrow + 1U;
}

uint32_t lf_xls_column_count(const LF_XLS_DOCUMENT *document) {
    if (document == NULL || document->worksheet == NULL) {
        return 0;
    }
    return (uint32_t)document->worksheet->rows.lastcol + 1U;
}

LF_XLS_CELL_KIND lf_xls_cell_kind(
    const LF_XLS_DOCUMENT *document,
    uint32_t row,
    uint32_t column
) {
    xlsCell *cell = lf_xls_cell(document, row, column);
    if (cell == NULL || cell->id == XLS_RECORD_BLANK) {
        return LF_XLS_CELL_BLANK;
    }
    if (cell->id == XLS_RECORD_RK || cell->id == XLS_RECORD_MULRK
        || cell->id == XLS_RECORD_NUMBER) {
        return LF_XLS_CELL_NUMBER;
    }
    if (cell->str != NULL) {
        return LF_XLS_CELL_STRING;
    }
    return LF_XLS_CELL_BLANK;
}

const char *lf_xls_cell_string(
    const LF_XLS_DOCUMENT *document,
    uint32_t row,
    uint32_t column
) {
    xlsCell *cell = lf_xls_cell(document, row, column);
    return cell == NULL ? NULL : cell->str;
}

double lf_xls_cell_number(
    const LF_XLS_DOCUMENT *document,
    uint32_t row,
    uint32_t column
) {
    xlsCell *cell = lf_xls_cell(document, row, column);
    return cell == NULL ? 0.0 : cell->d;
}
