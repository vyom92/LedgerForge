# Reader mechanics fixture

`reader-mechanics.xls` is an invented, nonfinancial BIFF8 workbook. It contains
one visible sheet named `Reader mechanics` and exactly these cells:

| Label | Value |
| --- | --- |
| Example | 42 |

Generated with xlwt 1.3.0 (`Workbook`, `add_sheet`, four `write` calls, `save`).
The dependency is not needed to build or run LedgerForge. The file exercises
real libxls open/copy/serialization/cancellation paths. It does not represent
an institution statement and does not qualify any financial source support.
