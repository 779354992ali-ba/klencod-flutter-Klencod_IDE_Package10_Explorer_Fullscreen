# Package32 — Toolbar & Real Built-in Extensions

- Replaced the cramped six-column primary toolbar with a horizontally scrollable strip of fixed-width action cards. Labels wrap to two lines and are no longer clipped at the bottom.
- Standardized the primary strip cards with the same dark navy surfaces, restrained cyan/violet/green gradients, rounded borders, and soft shadows used by the lower dashboard cards.
- Replaced the placeholder Extensions notice with eight functional local editor extensions: JSON formatter/minifier, Base64 encode/decode, URL encode/decode, alphabetical line sorting, and duplicate-line removal.
- Extensions operate on the current selection when text is selected; otherwise they operate on the whole active file. Results replace the input and move the cursor to the end of the transformed text.
- Invalid input reports an error without modifying the document. No paid APIs, remote services, or fake marketplace entries are included.
- Build workflow remains `flutter pub get` then `flutter build apk --release`; no tests or analyzer are added to the workflow.
