#!/usr/bin/env python3
"""Generate fictional, mechanics-only CBQ current-account PDF fixtures."""

from pathlib import Path
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

ROOT = Path(__file__).resolve().parent
HISTORY = ROOT / "cbq_current_account_history_pdf_v1_synthetic.pdf"
MONTHLY = ROOT / "cbq_current_account_monthly_pdf_v1_synthetic.pdf"
MONTHLY_VARIANT = ROOT / "cbq_current_account_monthly_pdf_v1_synthetic_variant.pdf"

FULL_ACCOUNT = "4700123456001"
MASKED_ACCOUNT = "4700-1XXXX6-001"
MASKED_IBAN = "QA62CBQA0000000047001XXXX6001"

EVENTS_ASC = [
    ("01/07/2026", "01-Jul-26", "OPENING CREDIT REF 700001", 600.00, 600.00),
    ("02/07/2026", "02-Jul-26", "TRANSFER REF 700002", -100.00, 500.00),
    ("03/07/2026", "03-Jul-26", "SALARY REF 700003", 500.00, 1000.00),
    ("05/07/2026", "05-Jul-26", "SHOP REF 700004", -25.00, 975.00),
]


def money(value: float) -> str:
    return f"{abs(value):,.2f}"


def base(c: canvas.Canvas) -> None:
    c.setTitle("LedgerForge synthetic CBQ fixture")
    c.setAuthor("LedgerForge Tests")
    c.setFont("Helvetica", 9)


def make_history() -> None:
    c = canvas.Canvas(str(HISTORY), pagesize=A4, pageCompression=1, invariant=1)
    width, height = A4
    events = list(reversed(EVENTS_ASC))
    chunks = [events[:2], events[2:]]
    for page_number, chunk in enumerate(chunks, start=1):
        base(c)
        c.drawString(74, height - 38, "Transaction History")
        if page_number == 1:
            c.drawString(74, height - 63, FULL_ACCOUNT)
            c.drawString(74, height - 83, "CURRENT ACCOUNT-RETAIL - FICTIONAL HOLDER")
        if page_number == 1:
            c.drawString(74, height - 112, "Date")
            c.drawString(173, height - 112, "Details")
            c.drawString(317, height - 112, "Amount")
            c.drawString(439, height - 112, "Balance")
        y = height - 132
        for history_date, _, description, amount, balance in chunk:
            c.drawString(74, y, history_date)
            c.drawString(173, y, description)
            c.drawRightString(375, y, f"{amount:,.2f}")
            c.drawRightString(490, y, f"{balance:,.2f}")
            c.drawString(173, y - 12, "SYNTHETIC SOURCE EVIDENCE ONLY")
            y -= 46
        c.drawRightString(width - 50, 30, f"{page_number}/2")
        c.showPage()
    c.save()


def make_monthly(path: Path, variant: bool = False) -> None:
    c = canvas.Canvas(str(path), pagesize=A4, pageCompression=1, invariant=1)
    width, height = A4
    base(c)
    c.drawString(60, height - 145, "ACCOUNT STATEMENT")
    c.drawString(345, height - 133, "Account Type: Current Account-Retail")
    c.drawString(60, height - 167, "FICTIONAL HOLDER")
    c.drawString(345, height - 149, f"IBAN: {MASKED_IBAN}")
    c.drawString(345, height - 165, f"Account No.: {MASKED_ACCOUNT}")
    c.drawString(345, height - 181, "Statement Date: 05 Jul 26")
    c.drawString(345, height - 197, "Branch: Fictional Branch")
    c.drawString(345, height - 213, "Currency: QATARI RIYAL")
    y_header = height - 253
    c.setFont("Helvetica", 8)
    c.drawString(28, y_header, "Posting Date")
    c.drawString(90, y_header, "Transaction Description")
    c.drawString(268, y_header, "Transaction Date")
    c.drawString(374, y_header, "Debit")
    c.drawString(463, y_header, "Credit")
    c.drawString(530, y_header, "Balance")
    y = y_header - 20
    c.drawString(28, y, "01-Jul-26")
    c.drawString(90, y, "BROUGHT FORWARD")
    c.drawRightString(580, y, "0.00")
    y -= 38
    for _, monthly_date, description, amount, balance in EVENTS_ASC:
        c.drawString(28, y, monthly_date)
        c.drawString(90, y, description)
        c.drawString(282, y, monthly_date)
        if amount < 0:
            c.drawRightString(430, y, money(amount))
        else:
            c.drawRightString(510, y, money(amount))
        c.drawRightString(580, y, f"{balance:,.2f}")
        c.drawString(90, y - 12, "SYNTHETIC EVIDENCE")
        y -= 42
    c.drawRightString(520, y - 4, "* CREDIT BALANCE")
    c.drawRightString(580, y - 4, "975.00")
    c.drawRightString(width - 50, 30, "1/1")
    c.showPage()

    base(c)
    c.setFont("Helvetica-Bold", 18)
    c.drawString(70, height - 120, "FICTIONAL PROMOTIONAL PAGE")
    c.setFont("Helvetica", 11)
    c.drawString(70, height - 155, "This page contains no account activity or financial table.")
    promo = "It also makes this source byte-distinct for mask-to-mask order testing." if variant else "It exists only to verify bounded non-financial page exclusion."
    c.drawString(70, height - 175, promo)
    c.showPage()
    c.save()


if __name__ == "__main__":
    make_history()
    make_monthly(MONTHLY)
    make_monthly(MONTHLY_VARIANT, variant=True)
