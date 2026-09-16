/* Nonfinancial integer/buffer checks. No workbook or statement is constructed.
 * Include the implementation to exercise its private allocation/sentinel paths
 * without adding a testing API to the shipped reader. */
#include <assert.h>
#include "../Sources/CLegacyXLS/src/ole.c"
#include "../Sources/CLegacyXLS/src/xlstool.c"

int main(void) {
    _Static_assert(sizeof(((OLE2Stream *)0)->fatpos) == sizeof(DWORD),
                   "A sector ID retains the CFB width");
    BYTE input[1] = {0x41}, output[1] = {0};
    DWORD next[1] = {ENDOFCHAIN};
    OLE2 ole = {0};
    ole.SSAT = input;
    ole.SSATCount = sizeof(input);
    ole.SSecID = next;
    ole.SSecIDCount = 1;
    ole.lssector = 64;
    OLE2Stream stream = {0};
    stream.ole = &ole;
    stream.buf = output;
    stream.bufsize = 1;
    stream.sfat = 1;
    assert(ole2_bufread(&stream) == 0 && output[0] == input[0]);
    assert(stream.fatpos == ENDOFCHAIN);
    assert(ole2_bufread(&stream) == 0);
    stream.fatpos = FREESECT;
    assert(ole2_bufread(&stream) == -1);
    stream.fatpos = UINT32_MAX - 2;
    assert(ole2_bufread(&stream) == -1); /* unsigned ID exceeds this buffer */
    ole.csfat = UINT32_MAX;
    ole.lsector = 4096;
    ole.SSecID = NULL;
    assert(read_MSAT_trailer(&ole) == -1 && ole.SSecID == NULL);

    assert(transcode_latin1_to_utf8("a", SIZE_MAX) == NULL);
    assert(transcode_latin1_to_utf8("a", SIZE_MAX - 1) == NULL);
    char *latin = transcode_latin1_to_utf8("A\xE9", 2);
    assert(latin != NULL && strcmp(latin, "A\xC3\xA9") == 0);
    free(latin);
    xls_locale_t locale = xls_createlocale();
    assert(locale != NULL);
    assert(unicode_decode_wcstombs("a", SIZE_MAX, locale) == NULL);
    const char invalid_utf16[] = {0, (char)0xD8};
    assert(unicode_decode_wcstombs(invalid_utf16, sizeof(invalid_utf16), locale) == NULL);
    const char ascii_utf16[] = {'A', 0};
    char *wide = unicode_decode_wcstombs(ascii_utf16, sizeof(ascii_utf16), locale);
    assert(wide != NULL && strcmp(wide, "A") == 0);
    free(wide);
    xls_freelocale(locale);
#ifdef HAVE_ICONV
    iconv_t converter = iconv_open("UTF-8", "ISO-8859-1");
    assert(converter != (iconv_t)-1);
    assert(unicode_decode_iconv("a", SIZE_MAX, converter) == NULL);
    char *expanded = unicode_decode_iconv("\xE9\xE9", 2, converter);
    assert(expanded != NULL && strcmp(expanded, "\xC3\xA9\xC3\xA9") == 0);
    free(expanded);
    iconv_close(converter);
#endif
    puts("LegacyXLS integer/buffer mechanics passed");
    return 0;
}
