# LegacyXLS Third-Party Notice

LedgerForge vendors the required library portion of `libxls/libxls` version
1.6.3 at commit `c199d132494833da696b58aa4acf3fc5a36d930b` under the BSD
2-clause license reproduced verbatim in `LICENSE`.

Included upstream files are limited to `src/xlstool.c`, `src/endian.c`,
`src/locale.c`, `src/ole.c`, `src/xls.c`, and their required public/internal
headers as private build inputs. Only the LedgerForge bridge header is exposed
to Swift. Upstream command-line tools, tests, fuzzing inputs, examples,
prebuilt binaries, and dynamic libraries are excluded.

LedgerForge adds a narrow C bridge, a checked-in macOS configuration, and a
local safety guard in `src/xls.c` that rejects worksheet dimensions exceeding
10,000 rows, 256 columns, or 1,000,000 cells before libxls allocates its cell
table. The package builds a static library and links only the macOS system
`iconv` boundary. A package-local `.gitattributes` preserves upstream source
whitespace without weakening whitespace checks for LedgerForge-authored files.
