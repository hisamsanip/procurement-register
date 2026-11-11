# PFMSB Procurement Register

Backup of the PFMSB procurement system for stratified developments under developer management.

- `app/pfmsb-register.html`: the register app (version 6). Single HTML file, styled to the PFMSB design kit. It covers records for PRF, RFQ, Quotation Analysis and PO, the Guidelines page, the property letterhead editor, PDF generation and CSV export for Excel. It runs as a published Claude artifact, which supplies the database, user and download features. Opened as a plain file it shows the screens but does not store data.
- `docs/PFMSB_Procurement_Documentation_Guideline.docx`: the procurement guideline.
- `docs/PFMSB_Procurement_Documentation_Pack_for_Property_Manager.docx`: guideline and the PRF, RFQ, QA and PO forms in one pack.
- `docs/PFMSB_Procurement_Workbook.xlsx`: Excel version with the Entry sheet and locked formulas.

Saved records, properties, vendors and settings live in the artifact database, not in this repository.
