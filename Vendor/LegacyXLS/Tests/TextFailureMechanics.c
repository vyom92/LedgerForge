/* Nonfinancial text/error-status mechanics only. No file, OLE container,
 * workbook stream, statement, financial value, or financial DTO is created.
 * Zeroed libxls owner structs give the real string producers their ordinary
 * allocation and cleanup context. Only the bridge's open/parse entrypoints
 * are substituted; actual decoding, copies, SST continuation, cell production,
 * first-error guards, bridge validation/error mapping, and cleanup are used.
 * This does not qualify financial workbook parsing or source semantics. */
#include <assert.h>
#include <errno.h>
#include <iconv.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../Sources/CLegacyXLS/include/xls.h"

static void *owned_allocations[256];
static size_t owned_count;
static iconv_t owned_converters[16];
static size_t converter_count;
static int fail_malloc;
static int fail_calloc;
static int fail_realloc;
static int fail_conversion;
static int fail_converter_open;
static unsigned workbook_closes;
static unsigned worksheet_closes;
static unsigned producer_calls;

static void remember(void *pointer) {
    if (pointer != NULL) {
        assert(owned_count < sizeof(owned_allocations) / sizeof(owned_allocations[0]));
        owned_allocations[owned_count++] = pointer;
    }
}

static size_t owned_index(void *pointer) {
    for (size_t i = 0; i < owned_count; i++) {
        if (owned_allocations[i] == pointer)
            return i;
    }
    assert(!"free/realloc must retain its original owner");
    return 0;
}

static void *mechanics_malloc(size_t size) {
    if (fail_malloc) {
        fail_malloc = 0;
        return NULL;
    }
    void *pointer = malloc(size);
    remember(pointer);
    return pointer;
}

static void *mechanics_calloc(size_t count, size_t size) {
    if (fail_calloc) {
        fail_calloc = 0;
        return NULL;
    }
    void *pointer = calloc(count, size);
    remember(pointer);
    return pointer;
}

static void *mechanics_realloc(void *pointer, size_t size) {
    if (fail_realloc) {
        fail_realloc = 0;
        return NULL;
    }
    if (pointer == NULL) {
        void *result = realloc(NULL, size);
        remember(result);
        return result;
    }
    size_t index = owned_index(pointer);
    void *result = realloc(pointer, size);
    if (result != NULL)
        owned_allocations[index] = result;
    return result;
}

static void mechanics_free(void *pointer) {
    if (pointer == NULL)
        return;
    size_t index = owned_index(pointer);
    owned_allocations[index] = owned_allocations[--owned_count];
    free(pointer);
}

static iconv_t mechanics_iconv_open(const char *to, const char *from) {
    if (fail_converter_open) {
        fail_converter_open = 0;
        errno = EINVAL;
        return (iconv_t)-1;
    }
    iconv_t converter = iconv_open(to, from);
    if (converter != (iconv_t)-1) {
        assert(converter_count < sizeof(owned_converters) / sizeof(owned_converters[0]));
        owned_converters[converter_count++] = converter;
    }
    return converter;
}

static size_t mechanics_iconv(iconv_t converter, char **input,
                              size_t *input_left, char **output,
                              size_t *output_left) {
    if (fail_conversion) {
        fail_conversion = 0;
        errno = EILSEQ;
        return (size_t)-1;
    }
    return iconv(converter, input, input_left, output, output_left);
}

static int mechanics_iconv_close(iconv_t converter) {
    size_t i;
    for (i = 0; i < converter_count; i++) {
        if (owned_converters[i] == converter)
            break;
    }
    assert(i < converter_count);
    owned_converters[i] = owned_converters[--converter_count];
    return iconv_close(converter);
}

/* Macros apply to the real producer implementations, not to the C allocator
 * or iconv functions inside the wrappers above. Nothing is added to the API. */
#define malloc mechanics_malloc
#define calloc mechanics_calloc
#define realloc mechanics_realloc
#define free mechanics_free
#undef iconv
#undef iconv_open
#undef iconv_close
#define iconv mechanics_iconv
#define iconv_open mechanics_iconv_open
#define iconv_close mechanics_iconv_close
#include "../Sources/CLegacyXLS/src/xlstool.c"
#include "../Sources/CLegacyXLS/src/xls.c"

static xlsWorkBook *mechanics_open_buffer(const unsigned char *, size_t,
                                         const char *, xls_error_t *);
static xls_error_t mechanics_parse_worksheet(xlsWorkSheet *);
static void mechanics_close_workbook(xlsWorkBook *);
static void mechanics_close_worksheet(xlsWorkSheet *);

#define xls_open_buffer mechanics_open_buffer
#define xls_parseWorkSheet mechanics_parse_worksheet
#define xls_close_WB mechanics_close_workbook
#define xls_close_WS mechanics_close_worksheet
#include "../Sources/CLegacyXLS/legacy_xls_bridge.c"
#undef xls_open_buffer
#undef xls_parseWorkSheet
#undef xls_close_WB
#undef xls_close_WS

static void mechanics_close_workbook(xlsWorkBook *workbook) {
    workbook_closes++;
    xls_close_WB(workbook);
}

static void mechanics_close_worksheet(xlsWorkSheet *worksheet) {
    worksheet_closes++;
    xls_close_WS(worksheet);
}

typedef enum {
    SST_TEXT,
    SST_EMPTY,
    SST_UTF16_FAILURE,
    SST_CODEPAGE_FAILURE,
    SST_MALLOC_FAILURE,
    SST_EMPTY_COPY_FAILURE,
    SST_TABLE_FAILURE,
    SST_CONVERTER_FAILURE,
    SST_INVALID_UTF16,
    SST_CONVERTER_GROWTH_FAILURE,
    SST_CONTINUATION_FAILURE,
    SST_EMPTY_CONTINUATION,
    CELL_COPY_FAILURE,
    CELL_LABEL_FAILURE,
    CELL_RSTRING_FAILURE,
    CELL_CODEPAGE_FAILURE,
    CELL_EMPTY_UTF16,
    CELL_EMPTY_COMPRESSED,
    CELL_BIFF5_TEXT,
    CELL_COMPRESSED_TEXT,
    CELL_INVALID_SST_INDEX,
    PHYSICAL_BLANK
} Scenario;

static Scenario scenario;
static const char *literal_text = "alpha";

static xlsWorkBook *new_text_owner(void) {
    xlsWorkBook *workbook = calloc(1, sizeof(*workbook));
    assert(workbook != NULL);
    workbook->charset = xls_strdup("UTF-8", workbook);
    assert(workbook->charset != NULL);
    workbook->sheets.sheet = calloc(1, sizeof(struct st_sheet_data));
    assert(workbook->sheets.sheet != NULL);
    workbook->sheets.count = 1;
    workbook->sheets.sheet[0].name = xls_strdup("Text mechanics", workbook);
    assert(workbook->sheets.sheet[0].name != NULL);
    return workbook;
}

static xls_error_t add_shared_text(xlsWorkBook *workbook,
                                  const BYTE *fragment, size_t size) {
    BYTE record[160] = {0};
    assert(size <= sizeof(record) - offsetof(SST, strings));
    SST *sst = (SST *)record;
    sst->num = 1;
    sst->numofstr = 1;
    memcpy(sst->strings, fragment, size);
    producer_calls++;
    return xls_addSST(workbook, sst, (DWORD)(offsetof(SST, strings) + size));
}

static xls_error_t produce_shared_text(xlsWorkBook *workbook) {
    const BYTE wide[] = {1, 0, 1, 'A', 0};
    const BYTE invalid_wide[] = {1, 0, 1, 0, 0xD8};
    const BYTE euro[] = {1, 0, 1, 0xAC, 0x20};
    const BYTE empty[] = {0, 0, 0};
    const BYTE partial[] = {2, 0, 0, 'A'};
    const BYTE partial_empty[] = {1, 0, 1};
    const BYTE continuation[] = {0, 'B'};
    const BYTE wide_continuation[] = {1, 'A', 0};
    BYTE compressed[128] = {0};
    size_t length = strlen(literal_text);
    assert(length < sizeof(compressed) - 3);
    compressed[0] = (BYTE)length;
    memcpy(compressed + 3, literal_text, length);

    switch (scenario) {
    case SST_UTF16_FAILURE:
        fail_conversion = 1;
        return add_shared_text(workbook, wide, sizeof(wide));
    case SST_CODEPAGE_FAILURE:
        workbook->is5ver = 1;
        workbook->codepage = 1252;
        fail_conversion = 1;
        return add_shared_text(workbook, compressed, length + 3);
    case SST_MALLOC_FAILURE:
        fail_malloc = 1;
        return add_shared_text(workbook, compressed, length + 3);
    case SST_EMPTY_COPY_FAILURE:
        fail_malloc = 1;
        return add_shared_text(workbook, empty, sizeof(empty));
    case SST_TABLE_FAILURE:
        fail_calloc = 1;
        return add_shared_text(workbook, compressed, length + 3);
    case SST_CONVERTER_FAILURE:
        fail_converter_open = 1;
        return add_shared_text(workbook, wide, sizeof(wide));
    case SST_INVALID_UTF16:
        return add_shared_text(workbook, invalid_wide, sizeof(invalid_wide));
    case SST_CONVERTER_GROWTH_FAILURE:
        fail_realloc = 1;
        return add_shared_text(workbook, euro, sizeof(euro));
    case SST_CONTINUATION_FAILURE:
        assert(add_shared_text(workbook, partial, sizeof(partial)) == LIBXLS_OK);
        assert(workbook->sst.continued && strcmp(workbook->sst.string[0].str, "A") == 0);
        fail_realloc = 1;
        producer_calls++;
        return xls_appendSST(workbook, (BYTE *)continuation, sizeof(continuation));
    case SST_EMPTY_CONTINUATION:
        assert(add_shared_text(workbook, partial_empty, sizeof(partial_empty)) == LIBXLS_OK);
        assert(workbook->sst.continued && workbook->sst.lastln == 1);
        assert(workbook->sst.string[0].str != NULL && workbook->sst.string[0].str[0] == '\0');
        producer_calls++;
        return xls_appendSST(workbook, (BYTE *)wide_continuation, sizeof(wide_continuation));
    case SST_EMPTY:
        return add_shared_text(workbook, empty, sizeof(empty));
    default:
        return add_shared_text(workbook, compressed, length + 3);
    }
}

static xlsWorkBook *mechanics_open_buffer(const unsigned char *bytes, size_t size,
                                         const char *charset, xls_error_t *error) {
    /* This marker never enters an OLE/BIFF parser. It only selects the bridge
     * call under test while actual string producers supply the status. */
    assert(bytes != NULL && size == 1 && bytes[0] == 'T');
    assert(strcmp(charset, "UTF-8") == 0);
    xlsWorkBook *workbook = new_text_owner();
    if (scenario == CELL_BIFF5_TEXT || scenario == CELL_CODEPAGE_FAILURE) {
        workbook->is5ver = 1;
        workbook->codepage = 1252;
    }
    xls_error_t result = LIBXLS_OK;
    if (scenario <= CELL_COPY_FAILURE || scenario == CELL_INVALID_SST_INDEX)
        result = produce_shared_text(workbook);
    if (result != LIBXLS_OK) {
        if (workbook->string_error != LIBXLS_OK)
            assert(xls_parseWorkBook(workbook) == result);
        mechanics_close_workbook(workbook);
        *error = result;
        return NULL;
    }
    *error = LIBXLS_OK;
    return workbook;
}

static xls_error_t mechanics_parse_worksheet(xlsWorkSheet *worksheet) {
    assert(xls_makeTable(worksheet) == LIBXLS_OK);
    if (scenario == PHYSICAL_BLANK)
        return LIBXLS_OK;

    BYTE record[16] = {0};
    BOF bof = {.id = XLS_RECORD_LABELSST, .size = 10};
    switch (scenario) {
    case CELL_COPY_FAILURE:
        fail_malloc = 1;
        break;
    case CELL_INVALID_SST_INDEX:
        record[6] = 1;
        break;
    case CELL_LABEL_FAILURE:
    case CELL_RSTRING_FAILURE:
    case CELL_EMPTY_UTF16:
        bof.id = scenario == CELL_RSTRING_FAILURE ? XLS_RECORD_RSTRING : XLS_RECORD_LABEL;
        bof.size = scenario == CELL_EMPTY_UTF16 ? 9 : 11;
        record[8] = 1;
        if (scenario != CELL_EMPTY_UTF16) {
            record[6] = 1;
            record[9] = 'A';
            fail_conversion = 1;
        }
        break;
    case CELL_EMPTY_COMPRESSED:
        bof.id = XLS_RECORD_LABEL;
        bof.size = 9;
        break;
    case CELL_BIFF5_TEXT:
    case CELL_CODEPAGE_FAILURE:
        bof.id = XLS_RECORD_LABEL;
        bof.size = 9;
        record[6] = 1;
        record[8] = 0xE9;
        if (scenario == CELL_CODEPAGE_FAILURE)
            fail_conversion = 1;
        break;
    case CELL_COMPRESSED_TEXT:
        bof.id = XLS_RECORD_LABEL;
        bof.size = 10;
        record[6] = 1;
        record[9] = 0xE9;
        break;
    default:
        break;
    }
    producer_calls++;
    struct st_cell_data *cell = xls_addCell(worksheet, &bof, record);
    if (cell == NULL) {
        /* The real producer, not this harness, has set the first error. The
         * real worksheet entry guard must return it without using a stream. */
        assert(worksheet->workbook->string_error != LIBXLS_OK);
        return xls_parseWorkSheet(worksheet);
    }
    assert(worksheet->workbook->string_error == LIBXLS_OK);
    return LIBXLS_OK;
}

static LF_XLS_DOCUMENT *open_scenario(Scenario selected, LF_XLS_ERROR *error) {
    assert(owned_count == 0 && converter_count == 0);
    assert(!fail_malloc && !fail_calloc && !fail_realloc && !fail_conversion && !fail_converter_open);
    scenario = selected;
    workbook_closes = worksheet_closes = producer_calls = 0;
    const uint8_t marker = 'T';
    return lf_xls_open_buffer(&marker, 1, error);
}

static void expect_failure(Scenario selected, LF_XLS_ERROR expected,
                           unsigned expected_worksheet_closes) {
    LF_XLS_ERROR error = LF_XLS_ERROR_OK;
    assert(open_scenario(selected, &error) == NULL);
    assert(error == expected && producer_calls != 0);
    assert(workbook_closes == 1 && worksheet_closes == expected_worksheet_closes);
    assert(owned_count == 0 && converter_count == 0);
    assert(!fail_malloc && !fail_calloc && !fail_realloc && !fail_conversion && !fail_converter_open);
}

static void expect_text(Scenario selected, const char *expected) {
    LF_XLS_ERROR error = LF_XLS_ERROR_MALFORMED;
    LF_XLS_DOCUMENT *document = open_scenario(selected, &error);
    assert(document != NULL && error == LF_XLS_ERROR_OK);
    assert(lf_xls_cell_kind(document, 0, 0) == LF_XLS_CELL_STRING);
    const char *text = lf_xls_cell_string(document, 0, 0);
    assert(text != NULL && strcmp(text, expected) == 0);
    assert(workbook_closes == 0 && worksheet_closes == 0);
    lf_xls_close(document);
    assert(workbook_closes == 1 && worksheet_closes == 1);
    assert(owned_count == 0 && converter_count == 0);
}

int main(void) {
    expect_failure(SST_UTF16_FAILURE, LF_XLS_ERROR_TEXT_CONVERSION, 0);
    expect_failure(SST_CODEPAGE_FAILURE, LF_XLS_ERROR_TEXT_CONVERSION, 0);
    expect_failure(SST_CONVERTER_FAILURE, LF_XLS_ERROR_TEXT_CONVERSION, 0);
    expect_failure(SST_INVALID_UTF16, LF_XLS_ERROR_TEXT_CONVERSION, 0);
    expect_failure(SST_MALLOC_FAILURE, LF_XLS_ERROR_ALLOCATION, 0);
    expect_failure(SST_EMPTY_COPY_FAILURE, LF_XLS_ERROR_ALLOCATION, 0);
    expect_failure(SST_TABLE_FAILURE, LF_XLS_ERROR_ALLOCATION, 0);
    expect_failure(SST_CONVERTER_GROWTH_FAILURE, LF_XLS_ERROR_ALLOCATION, 0);
    expect_failure(SST_CONTINUATION_FAILURE, LF_XLS_ERROR_ALLOCATION, 0);
    expect_failure(CELL_COPY_FAILURE, LF_XLS_ERROR_ALLOCATION, 1);
    expect_failure(CELL_LABEL_FAILURE, LF_XLS_ERROR_TEXT_CONVERSION, 1);
    expect_failure(CELL_RSTRING_FAILURE, LF_XLS_ERROR_TEXT_CONVERSION, 1);
    expect_failure(CELL_CODEPAGE_FAILURE, LF_XLS_ERROR_TEXT_CONVERSION, 1);
    expect_failure(CELL_INVALID_SST_INDEX, LF_XLS_ERROR_MALFORMED, 1);

    expect_text(SST_EMPTY, "");
    expect_text(CELL_EMPTY_UTF16, "");
    expect_text(CELL_EMPTY_COMPRESSED, "");
    expect_text(SST_EMPTY_CONTINUATION, "A");
    expect_text(CELL_BIFF5_TEXT, "\xC3\xA9");
    expect_text(CELL_COMPRESSED_TEXT, "\xC3\xA9");
    literal_text = "*failed to decode utf16*";
    expect_text(SST_TEXT, literal_text);
    literal_text = "*failed to decode BIFF5 string*";
    expect_text(SST_TEXT, literal_text);

    LF_XLS_ERROR error = LF_XLS_ERROR_MALFORMED;
    LF_XLS_DOCUMENT *blank = open_scenario(PHYSICAL_BLANK, &error);
    assert(blank != NULL && error == LF_XLS_ERROR_OK);
    assert(lf_xls_cell_kind(blank, 0, 0) == LF_XLS_CELL_BLANK);
    assert(lf_xls_cell_string(blank, 0, 0) == NULL);
    lf_xls_close(blank);
    assert(workbook_closes == 1 && worksheet_closes == 1);
    assert(owned_count == 0 && converter_count == 0);
    puts("LegacyXLS text/status fault-injection mechanics passed");
    return 0;
}
