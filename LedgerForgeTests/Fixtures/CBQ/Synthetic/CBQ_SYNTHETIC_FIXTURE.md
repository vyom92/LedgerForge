# CBQ Current-Account Synthetic Mechanics Fixtures

`cbq_current_account_xls_v1_synthetic.xls` is an invented BIFF8 workbook for
the exact `cbq.current-account.xls@1` mechanics. It contains an invented
account number, holder, dates, descriptions, signed amounts and row-associated
balances. Its blank merged-cell placeholders exercise the retained physical
grid without carrying hidden source values. It contains no value from a private
source and is not a financial oracle.

The fixed binary was generated once with `xlwt` 1.3.0, matching the existing
legacy-XLS fixture approach. Neither the application nor its tests require
Python or `xlwt` at build or runtime.

SHA-256:

- `427a65b81b91d8072d6c5f8f7b85f77c3436538d5126b2240428ccea311d4522`

The same directory also contains invented selectable-text PDF mechanics for:

- `cbq.current-account.history.pdf@1`;
- `cbq.current-account.monthly.pdf@1`;
- one byte-distinct monthly PDF variant with the same invented financial and
  masked-identity evidence.

The history PDF exercises descending rows, repeated/retained table geometry,
signed QAR amounts, row-associated balances and a full invented account
identifier without a statement period or value date. The monthly fixtures
exercise posting date versus separate source Transaction Date, masked account
and IBAN evidence, brought-forward opening balance, closing evidence,
multiline rows and exact non-financial promotional-page exclusion.

`generate_cbq_pdf_fixtures.py` deterministically regenerates only these
invented PDF mechanics. The PDFs and generator are self-contained and include
no private-source-derived value, date, identifier, description, reference,
filename or object identity. They are not financial oracles for private
acceptance.
