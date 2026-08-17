# CBQ Current-Account XLS Synthetic Mechanics Fixture

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
