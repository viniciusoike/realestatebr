# Cement test fixture provenance

These fixtures are small excerpts for parser tests. No full archive workbook or source PDF is committed. The four PDF text files are byte-for-byte `pdftools::pdf_text(path)[[1]]` output from Phase 0's local PDF downloads. The PDFs were retrieved on **2026-10-23** in an earlier probe that bypassed SNIC's invalid TLS certificate. This phase made no unverified download. The site certificate expired on 2026-09-03, so a new verified fetch was unavailable.

| Text fixture | Source PDF URL | Source PDF SHA-256 |
| --- | --- | --- |
| `consumption_2024.txt` | https://snic.org.br/assets/pdf/numeros/1752521135.pdf | `bdf5129617e626893db85353df70616c304321c5f26b35aa2a63e8cec2a16d0b` |
| `production_2024.txt` | https://snic.org.br/assets/pdf/numeros/1752521165.pdf | `520670c1a06140b4d899703f6a18ae564982133dd5c673ea00612c0006449507` |
| `consumption_2025.txt` | https://snic.org.br/assets/pdf/numeros/1784570419.pdf | `230723bad3293417b0a4ef355d2965a300e96a22ce9a13c0c07fac35a170332f` |
| `production_2025.txt` | https://snic.org.br/assets/pdf/numeros/1784570386.pdf | `0b5fd33f592016d53bcd700fcc8a935c59bf92b46a9fa27f86f2396db8790f30` |

The `archive_consumption_excerpt.xlsx` fixture copies the 2004, 2014–2016, and 2023–2024 sheet cells from A03 (SHA-256 `1204150b8e4c75a3e9c9a01b24f5bfde555383ecda456c199e970263387f6c9d`). The `archive_production_excerpt.xlsx` fixture copies the 2023–2025 sheet cells from A04 (SHA-256 `67057ddc8d9f54130d71289035f1110b8dc37753eebc9cd4af6eeccef8ed72d6`). Both source workbooks are under `data-raw/backlog/CBIC/` outside this worktree. The copies preserve the 14-column sheet layout and cell values but omit source formatting, formulas, and all other sheets. The 2025 production sheet preserves the archive's January vintage for revision tests.

`index_excerpt.html` keeps only the relevant anchor labels and relative URLs from the SNIC [industry index](https://snic.org.br/numeros-da-industria.php), retrieved on 2026-10-23 during Phase 0. `broken_variants.yaml` describes five one-feature changes applied in memory to `consumption_2025.txt` for rejection tests.
