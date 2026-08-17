# Amex Credit-Card Synthetic Mechanics Fixture

`amex_credit_card_pdf_v1_synthetic.pdf` and its byte-distinct encrypted form,
`amex_credit_card_pdf_v1_synthetic_encrypted.pdf`, are generated entirely from
the adjacent script. Their customer, membership observation, card observations, dates,
references, descriptions, currencies, and monetary values are fictional and
were invented specifically to exercise the `amex.credit-card.pdf@1` mechanics.

The fixtures are native selectable text and cover one account-level payment,
three instrument sections, repeated and distinct holder labels, a signed section
total on a continuation page, BHD three-decimal and KRW integer original Money,
tiny debit and credit amounts, a foreign refund with matching credit markers,
non-monotonic posting dates, multiline placeholder travel data, exact statement
and section reconciliation, rewards identity bait, and a final informational
page. The synthetic encrypted form uses the fictional test-only password
`ledgerforge-fixture-only`. The generator fixes PDF identifiers and metadata so
repeated runs produce deterministic bytes.

It is not derived from, redacted from, or intended to reproduce any private
statement. Regenerate it with:

```sh
python3 LedgerForgeTests/Fixtures/AmericanExpress/Synthetic/generate_amex_credit_card_pdf_fixture.py
```
