# Bisho IDE — Package 27: Editor Preference Persistence

- Word Wrap is restored from SharedPreferences when the full-screen editor opens.
- Toggling Word Wrap persists the choice for the next editor session.
- Preference storage failures do not block editing; the current session continues with the selected setting.
- Default remains disabled for compatibility with Package 22 horizontal scrolling.
