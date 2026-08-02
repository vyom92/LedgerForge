# Legacy XLS rejection fixtures

These privacy-safe BIFF8 workbooks contain only synthetic labels and numbers.
They were generated once for Sprint 71 with `xlwt` 1.3.0, then committed as
fixed binary evidence; neither the application nor its tests depend on Python
or `xlwt` at build or runtime.

| Fixture | Rejection boundary | SHA-256 |
|---|---|---|
| `boolean_cell.xls` | Boolean/error cell | `9dd598c290c09329728ad3ddc85fe19fa7230aed71ed5477d1501aea4824e480` |
| `formula_cell.xls` | Formula cell | `a2cef24f249eeb3bbfaacea086979ee91d3e589c8f6d78e77b08d890caa584ad` |
| `hidden_worksheet.xls` | Hidden worksheet | `92583afc13fa013677f2c59be58a9fefd07fc8d50c08484e8c0d7c3dbd477675` |
| `multiple_worksheets.xls` | More than one worksheet | `42802ee953f10c590b35c4ba10fe6f461750afb6b4181cf60e04845d6bfe4530` |
| `unsupported_encryption.xls` | BIFF `FILEPASS` record | `bd98eeda4062c846bf0f0670c349651834cfbf11bbb2201d838eead0393438f4` |
