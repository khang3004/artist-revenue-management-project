## 📁 Cấu trúc

```
slides/
├── main.tex                        # Entry point — compile file này
├── settings/
│   ├── hcmus_beamer.sty            # Beamer theme (Warsaw + Beaver)
│   ├── packages.tex                # Package imports
│   └── commands.tex                # Custom macros (\highlight, \tbl, \kpiCard,...)
├── sections/                       # Mỗi section = 1 folder
│   ├── 01_intro/_master.tex        # Giới thiệu, mục tiêu, tech stack
│   ├── 02_erd/_master.tex          # ERD, ISA, mối quan hệ
│   ├── 03_implementation/_master.tex # Thiết kế vật lý, cài đặt, data
│   ├── 04_exploitation/_master.tex # 5 stored procedures (ROLLUP, PIVOT, subquery)
│   ├── 05_demo/_master.tex         # Demo Streamlit Dashboard
│   └── 06_conclusion/_master.tex   # Tổng kết, phân công
├── images/
│   └── hcmus_logo.png              # Logo trường
└── figures/                        # Screenshots kết quả (thêm sau)
    ├── erd.png                     # ERD diagram
    ├── sp1_revenue_rollup.png      # Kết quả SP1
    ├── sp2_revenue_pivot.png       # Kết quả SP2
    ├── dashboard_overview.png      # Streamlit Dashboard
    └── ...
```

---

## 🚀 Setup & Compile

### Prerequisites

Cài 1 trong 3 LaTeX distribution:

| OS         | Distribution | Cài đặt                                            |
| ---------- | ------------ | -------------------------------------------------- |
| Ubuntu/WSL | TeX Live     | `sudo apt install texlive-full`                    |
| macOS      | MacTeX       | `brew install --cask mactex`                       |
| Windows    | MikTeX       | [miktex.org/download](https://miktex.org/download) |

> **Lưu ý:** Cần `texlive-full` (hoặc tương đương) vì slide dùng các package: `tikz`, `pgfplots`, `booktabs`, `listings`, `multicol`.

### Option 1: Command Line (khuyến khích)

```bash
cd slides

# Compile (chạy 2 lần để Table of Contents đúng)
pdflatex main.tex
pdflatex main.tex

# Hoặc nếu dùng latexmk (auto chạy đủ lần):
latexmk -pdf main.tex
```

### Option 2: VS Code + LaTeX Workshop

1. Cài extension: [LaTeX Workshop](https://marketplace.visualstudio.com/items?itemName=James-Yu.latex-workshop)
2. Mở `slides/main.tex`
3. `Ctrl+Alt+B` (Build) hoặc save → auto compile
4. `Ctrl+Alt+V` (View PDF)

Thêm vào `.vscode/settings.json` (trong folder `slides/`):

```json
{
  "latex-workshop.latex.outDir": "./out",
  "latex-workshop.latex.recipes": [
    {
      "name": "pdflatex x2",
      "tools": ["pdflatex", "pdflatex"]
    }
  ],
  "latex-workshop.latex.tools": [
    {
      "name": "pdflatex",
      "command": "pdflatex",
      "args": ["-synctex=1", "-interaction=nonstopmode", "%DOC%"]
    }
  ]
}
```

### Option 3: Overleaf (online)

1. Zip folder `slides/` → Upload lên [overleaf.com](https://overleaf.com)
2. Set compiler: `pdfLaTeX`
3. Set main document: `main.tex`
4. Compile

---

## ✏️ Cách chỉnh sửa

### Thêm screenshot kết quả

Tìm các dòng `% TODO:` trong file `.tex` và thay bằng:

```latex
% Trước:
% TODO: Chèn screenshot kết quả
\textit{(Chèn screenshot tại đây)}

% Sau:
\includegraphics[width=0.9\textwidth]{figures/sp1_revenue_rollup.png}
```

### Thay thông tin nhóm

Trong `main.tex`, sửa block `\author`:

```latex
\author[Nhóm XX]{
    \small
    \begin{tabular}{c c c c}
        \textbf{Nguyễn Văn A}          & \textbf{Trần Thị B}          & ...
        \scriptsize \textit{21C01001}   & \scriptsize \textit{21C01002} & ...
    \end{tabular}
}
```

### Thêm section mới

1. Tạo folder: `sections/07_bonus/`
2. Tạo file: `sections/07_bonus/_master.tex`
3. Thêm vào `main.tex`:

```latex
\include{sections/07_bonus/_master}
```

---

## 🎨 Custom Macros có sẵn

| Macro                           | Dùng cho                  | Ví dụ                          |
| ------------------------------- | ------------------------- | ------------------------------ |
| `\highlight{text}`              | Highlight xanh đậm        | `\highlight{ROLLUP}`           |
| `\keyterm{text}`                | Key term nâu              | `\keyterm{PostgreSQL}`         |
| `\tbl{name}`                    | Tên bảng (monospace xanh) | `\tbl{artists}`                |
| `\sql{code}`                    | SQL keyword               | `\sql{GROUP BY}`               |
| `\kpiCard{width}{label}{value}` | KPI metric box            | `\kpiCard{3cm}{Tracks}{40}`    |
| `\sectionCard{title}{subtitle}` | Section header box        |                                |
| `\resultBox{label}{value}`      | Result highlight          | `\resultBox{Accuracy}{98.5\%}` |
| `\todo{note}`                   | Dev TODO marker (đỏ)      | `\todo{Thêm screenshot}`       |

---

## 📋 Checklist trước khi nộp

- [ ] Thay thông tin nhóm (tên, MSSV, GVHD)
- [ ] Chèn ERD diagram vào `figures/erd.png`
- [ ] Chèn screenshots kết quả 5 stored procedures
- [ ] Chèn screenshots Streamlit Dashboard
- [ ] Cập nhật link GitHub repo
- [ ] Compile thành công, kiểm tra PDF
- [ ] Review: tổng slide ~ 12-15 trang
