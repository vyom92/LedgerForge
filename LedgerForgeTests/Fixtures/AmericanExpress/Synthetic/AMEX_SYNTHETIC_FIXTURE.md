# Amex Credit-Card Synthetic Mechanics Fixture

`amex_credit_card_pdf_v1_synthetic.pdf` is generated entirely from the adjacent
script. Its customer, membership observation, card observation, dates,
references, descriptions, currencies, and monetary values are fictional and
were invented specifically to exercise the `amex.credit-card.pdf@1` mechanics.

The fixture is native selectable text and covers one account-level payment, one
instrument section, a QAR purchase, a foreign-currency purchase, a refund, a
multiline travel row, a financial continuation page, a transaction date before
the statement period, exact summary reconciliation, a rewards page, and a final
informational page. The generator uses invariant PDF metadata so repeated runs
produce identical bytes.

It is not derived from, redacted from, or intended to reproduce any private
statement. Regenerate it with:

```sh
python3 LedgerForgeTests/Fixtures/AmericanExpress/Synthetic/generate_amex_credit_card_pdf_fixture.py
```
