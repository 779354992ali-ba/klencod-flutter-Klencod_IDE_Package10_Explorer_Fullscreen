# Package61 — Text Comparison

## Usage
1. Open the file whose current content you want to review.
2. Open the tools dashboard and choose **مقارنة النص** from the expanded tools list.
3. Paste the older text into the input area.
4. Choose **اعرض الفروقات**.

The result uses `+` for lines present only in the current editor content, `-` for lines present only in the earlier text, and a neutral row for unchanged lines. Counts and old/new line numbers are shown. Choose **تغيير النص السابق** to compare another baseline.

## Limits
The exact LCS comparison is limited to 250,000 matrix cells. Larger comparisons use common-prefix/common-suffix detection and show the middle as a replacement region. This avoids large memory allocations but can display a broader change block than a minimal diff. The tool is read-only and does not save either text.
