"""Generate fictional native-text Amex mechanics fixtures for Sprint 76A.

All names, identity observations, references, dates, and money values below were
invented for this fixture. Nothing is copied from a private statement.
"""

from pathlib import Path

from reportlab.lib.pagesizes import A4
from reportlab.pdfgen.canvas import Canvas
from pypdf import PdfReader, PdfWriter
from pypdf.generic import ArrayObject, ByteStringObject


ROOT = Path(__file__).resolve().parent
UNLOCKED_OUTPUT = ROOT / "amex_credit_card_pdf_v1_synthetic.pdf"
ENCRYPTED_OUTPUT = ROOT / "amex_credit_card_pdf_v1_synthetic_encrypted.pdf"
SYNTHETIC_PASSWORD = "ledgerforge-fixture-only"
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
    canvas = Canvas(str(UNLOCKED_OUTPUT), pagesize=A4, pageCompression=0, invariant=1)
    canvas.setTitle("Fictional Amex Credit Card Mechanics Fixture")
    canvas.setAuthor("LedgerForge test fixture generator")

    page_one = header() + [
        "Previous Balance",
        "New Credits",
        "New Debits",
        "New Balance",
        "Due Date",
        "- (QAR) + (QAR) = (QAR) (QAR) 1,000.00 450.01 600.01 1,150.00 20/08/26",
        "Transaction Date Posting Date Details Non QAR Spending Amount in QAR",
        "30-Jun-2026 01-Jul-2026 FICTIONAL ACCOUNT PAYMENT",
        "Reference: PAY-FICTION-001",
        "400.00 CR",
        "New Transactions For AVERY EXAMPLE Card Account Number: 9999-XXXX",
        "02-Jul-2026 02-Jul-2026 FICTIONAL BOOKSHOP",
        "Reference: BUY-FICTION-002",
        "100.00",
        "04-Jul-2026 05-Jul-2026 FICTIONAL BAHRAIN MARKET",
        "Reference: BHD-FICTION-003",
        "1.234 BHD 20.00",
        "06-Jul-2026 08-Jul-2026 FICTIONAL FOREIGN REFUND",
        "Reference: BHD-REFUND-FICTION-004",
        "5.678 BHD CR 50.00 CR",
        "This Card is issued by AMEX (Middle East) B.S.C. (c)",
    ]
    draw_lines(canvas, page_one)
    canvas.showPage()

    continuation = header() + [
        "Total of New Transactions For AVERY EXAMPLE 70.00",
        "New Transactions For AVERY EXAMPLE Card Account Number: 3777-XXXXXX-20002",
        "19-Jul-2026 20-Jul-2026 FICTIONAL TINY PURCHASE",
        "Reference: TINY-DEBIT-FICTION-005",
        "0.01",
        "10-Jul-2026 12-Jul-2026 FICTIONAL NONMONOTONIC PURCHASE",
        "Reference: ORDER-FICTION-006",
        "30.00",
        "Total of New Transactions For AVERY EXAMPLE 30.01",
        "This Card is issued by AMEX (Middle East) B.S.C. (c)",
    ]
    draw_lines(canvas, continuation)
    canvas.showPage()

    third_section = header() + [
        "New Transactions For JORDAN SAMPLE Card Account Number: 3777-XXXXXX-30003",
        "21-Jul-2026 22-Jul-2026 FICTIONAL SEOUL MARKET",
        "Reference: KRW-FICTION-007",
        "1000 KRW 250.00",
        "15-Jul-2026 18-Jul-2026 FICTIONAL AIR JOURNEY",
        "TBD TO SAMPLE BAY",
        "TICKET 000-0000000000",
        "PASSENGER JORDAN SAMPLE",
        "Reference: TRAVEL-FICTION-008",
        "200.00",
        "24-Jul-2026 25-Jul-2026 FICTIONAL TINY CREDIT",
        "Reference: TINY-CREDIT-FICTION-009",
        "0.01 CR",
        "Total of New Transactions For JORDAN SAMPLE 449.99",
        "This Card is issued by AMEX (Middle East) B.S.C. (c)",
    ]
    draw_lines(canvas, third_section)
    canvas.showPage()

    rewards = header() + [
        "Membership Rewards Period",
        "01/07/26 to 31/07/26",
        "Membership Rewards Account Number",
        "MR-XXXX-7000",
        "New Points Card Type Account Number No. of Points",
        "The Platinum Card 3777-XXXXXX-30003 125",
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

    reader = PdfReader(str(UNLOCKED_OUTPUT))
    writer = PdfWriter()
    for page in reader.pages:
        writer.add_page(page)
    writer.add_metadata({
        "/Title": "Fictional Amex Credit Card Mechanics Fixture",
        "/Author": "LedgerForge test fixture generator",
    })
    identifier = bytes.fromhex("6c6564676572666f7267652d616d65782d76312d73796e7468657469632d3031")
    writer._ID = ArrayObject([ByteStringObject(identifier), ByteStringObject(identifier)])
    writer.encrypt(SYNTHETIC_PASSWORD, algorithm="RC4-128")
    with ENCRYPTED_OUTPUT.open("wb") as handle:
        writer.write(handle)


if __name__ == "__main__":
    generate()
