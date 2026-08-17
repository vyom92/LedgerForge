"""Generate the fictional native-text Amex mechanics fixture for Sprint 76.

All names, identity observations, references, dates, and money values below were
invented for this fixture. Nothing is copied from a private statement.
"""

from pathlib import Path

from reportlab.lib.pagesizes import A4
from reportlab.pdfgen.canvas import Canvas


ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "amex_credit_card_pdf_v1_synthetic.pdf"
WIDTH, HEIGHT = A4


def draw_lines(canvas: Canvas, lines: list[str], start_y: float = HEIGHT - 54) -> None:
    text = canvas.beginText(42, start_y)
    text.setFont("Helvetica", 9)
    text.setLeading(12)
    for line in lines:
        text.textLine(line)
    canvas.drawText(text)


def header() -> list[str]:
    return [
        "The Platinum Card (QAR)",
        "Statement of Account",
        "AMEX (MIDDLE EAST) B.S.C. (C)",
        "Membership Number",
        "Statement date",
        "Statement Period",
        "9999-XXXX",
        "31/07/26",
        "01/07/26 to 31/07/26",
    ]


def generate() -> None:
    canvas = Canvas(str(OUTPUT), pagesize=A4, pageCompression=0, invariant=1)
    canvas.setTitle("Fictional Amex Credit Card Mechanics Fixture")
    canvas.setAuthor("LedgerForge test fixture generator")

    page_one = header() + [
        "Previous Balance",
        "New Credits",
        "New Debits",
        "New Balance",
        "Due Date",
        "- (QAR) + (QAR) = (QAR) 1,000.00 450.00 450.00 1,000.00 20/08/26",
        "Transaction Date Posting Date Details Non QAR Spending Amount in QAR",
        "30-Jun-2026 01-Jul-2026 FICTIONAL ACCOUNT PAYMENT",
        "Reference: PAY-FICTION-001",
        "400.00 CR",
        "New Transactions For AVERY EXAMPLE Card Account Number: 3777-XXXXXX-10001",
        "02-Jul-2026 02-Jul-2026 FICTIONAL BOOKSHOP",
        "Reference: BUY-FICTION-002",
        "100.00",
        "04-Jul-2026 05-Jul-2026 FICTIONAL FOREIGN MARKET",
        "Reference: FX-FICTION-003",
        "40.00 USD 150.00",
        "This Card is issued by AMEX (Middle East) B.S.C. (c)",
    ]
    draw_lines(canvas, page_one)
    canvas.showPage()

    continuation = header() + [
        "08-Jul-2026 08-Jul-2026 FICTIONAL MERCHANT REFUND",
        "Reference: REFUND-FICTION-004",
        "50.00 CR",
        "11-Jul-2026 12-Jul-2026 FICTIONAL RAIL JOURNEY",
        "EXAMPLE CITY TO SAMPLE BAY",
        "PASSENGER AVERY EXAMPLE",
        "Reference: TRAVEL-FICTION-005",
        "200.00",
        "Total of New Transactions For AVERY EXAMPLE 400.00",
        "This Card is issued by AMEX (Middle East) B.S.C. (c)",
    ]
    draw_lines(canvas, continuation)
    canvas.showPage()

    rewards = header() + [
        "Membership Rewards Period",
        "01/07/26 to 31/07/26",
        "Membership Rewards Account Number",
        "MR-XXXX-7000",
        "New Points Card Type Account Number No. of Points",
        "The Platinum Card 3777-XXXXXX-10001 125",
        "Total New Paid Points 125",
        "Total Adjustments 0",
        "Rewards information is non-financial in this fictional fixture.",
    ]
    draw_lines(canvas, rewards)
    canvas.showPage()

    information = header() + [
        "Important Information",
        "This fictional page contains no transaction table or rewards valuation.",
        "This Card is issued by AMEX (Middle East) B.S.C. (c)",
    ]
    draw_lines(canvas, information)
    canvas.showPage()
    canvas.save()


if __name__ == "__main__":
    generate()
