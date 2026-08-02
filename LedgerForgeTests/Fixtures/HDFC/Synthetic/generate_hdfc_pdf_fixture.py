#!/usr/bin/env python3
"""Generate the invented HDFC PDF/XLS equivalence mechanics fixture."""

from pathlib import Path
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfgen.canvas import Canvas

OUTPUT_DIRECTORY = Path(__file__).parent


def draw(
    output_name: str,
    *,
    reference_header: str = "Chq./Ref.No.",
    first_debit: str = "10.25",
    balances: tuple[str, str, str, str] = ("989.75", "1010.25", "1005.25", "1010.25"),
    debit_total: str = "15.25",
    closing_balance: str = "1010.25",
    split_pages: bool = False,
    dual_populated_first_amount: bool = False,
) -> None:
    canvas = Canvas(
        str(OUTPUT_DIRECTORY / output_name),
        pagesize=landscape(A4),
        pageCompression=0,
        invariant=1,
    )
    canvas.setTitle("Invented HDFC bank-account PDF mechanics fixture")
    canvas.setAuthor("LedgerForge fixture generator")
    canvas.setFont("Helvetica", 8)
    rows = [
        (
            "04/04/25",
            ["Synthetic debit", "event"],
            "REV0001",
            "03/04/25",
            first_debit,
            "1.00" if dual_populated_first_amount else "",
            balances[0],
        ),
        ("05/04/25", ["Synthetic credit event"], "CREDIT1", "05/04/25", "", "20.50", balances[1]),
        ("06/04/25", ["Synthetic reversal debit"], "REPEAT9", "06/04/25", "5.00", "", balances[2]),
        ("07/04/25", ["Synthetic reversal credit"], "REPEAT9", "07/04/25", "", "5.00", balances[3]),
    ]
    page_rows = [rows[:2], rows[2:]] if split_pages else [rows]
    for page_index, retained_rows in enumerate(page_rows):
        canvas.setFont("Helvetica", 8)
        if page_index == 0:
            canvas.drawString(34, 570, "HDFC BANK LIMITED")
            canvas.drawString(470, 570, "Statement of account")
            canvas.drawString(340, 548, "Account Branch : TEST BRANCH")
            canvas.drawString(340, 532, "Address : HDFC BANK ,TEST BRANCH")
            canvas.drawString(340, 516, "City : TEST CITY")
            canvas.drawString(340, 500, "State : TEST STATE")
            canvas.drawString(340, 484, "Phone no. : 000/00000000")
            canvas.drawString(340, 468, "Email :")
            canvas.drawString(340, 452, "OD Limit : 0.00 Currency : INR")
            canvas.drawString(340, 436, "Cust ID : 123456789")
            canvas.drawString(340, 420, "Account No : 11112222333344 NR Others")
            canvas.drawString(34, 404, "Statement From : 01/04/2025 To : 31/03/2026")
        canvas.drawString(290, 570, f"Page No . : {page_index + 1}")
        headers = [
            (34, "Date"),
            (68, "Narration"),
            (285, reference_header),
            (362, "Value Dt"),
            (442, "Withdrawal Amt."),
            (520, "Deposit Amt."),
            (590, "Closing Balance"),
        ]
        for x, value in headers:
            canvas.drawString(x, 380, value)

        for row_index, row in enumerate(retained_rows):
            y = 355 - row_index * 42
            canvas.drawString(34, y, row[0])
            for narration_index, narration in enumerate(row[1]):
                canvas.drawString(68, y - narration_index * 12, narration)
            canvas.drawString(285, y, row[2])
            canvas.drawString(362, y, row[3])
            if row[4]:
                canvas.drawRightString(480, y, row[4])
            if row[5]:
                canvas.drawRightString(558, y, row[5])
            canvas.drawRightString(626, y, row[6])

        if page_index == len(page_rows) - 1:
            canvas.drawString(68, 170, "STATEMENT SUMMARY  :-")
            canvas.drawString(68, 150, "Opening Balance Dr Count Cr Count Debits Credits Closing Bal")
            canvas.drawString(68, 134, f"1000.00 2 2 {debit_total} 25.50 {closing_balance}")
            canvas.drawString(68, 100, "This is a computer generated statement and does not require signature.")
            canvas.drawString(68, 84, "HDFC BANK LIMITED")
            canvas.drawString(68, 68, "--- End Of Statement ---")
        canvas.showPage()
    canvas.save()


if __name__ == "__main__":
    draw("hdfc_bank_account_pdf_v1_nre_synthetic.pdf")
    draw(
        "hdfc_bank_account_pdf_v1_changed_header_synthetic.pdf",
        reference_header="Cheque/Ref No.",
    )
    draw(
        "hdfc_bank_account_pdf_v1_financial_mismatch_synthetic.pdf",
        first_debit="11.25",
        balances=("988.75", "1009.25", "1004.25", "1009.25"),
        debit_total="16.25",
        closing_balance="1009.25",
    )
    draw(
        "hdfc_bank_account_pdf_v1_repeated_header_synthetic.pdf",
        split_pages=True,
    )
    draw(
        "hdfc_bank_account_pdf_v1_dual_amount_synthetic.pdf",
        dual_populated_first_amount=True,
    )
