# Bisho IDE — Package64 Changelog

## Android SAF filename and Gradle scaffold hardening

- Uses `application/octet-stream` for Gradle, properties, batch, and shell files so Android Storage Access Framework providers are less likely to append `.txt` based on a `text/plain` MIME type.
- `SafFileService.saveFile` now verifies the returned document name and attempts an SAF rename when a provider changes the requested name. It throws a clear error if the exact name cannot be restored instead of silently reporting success.
- Updated editor saves and the new-project wizard to use the neutral MIME type for affected extensions.
- Project scaffold repair now recognizes legacy `<expected-name>.txt` files and attempts to rename them back to the expected name before creating replacements.
- The Android wrapper scripts are saved with a neutral MIME type; the wrapper JAR retains its archive MIME type.
- Added unit assertions for Gradle, properties, batch, and extensionless wrapper MIME mapping.
- Package version advanced to `1.0.0+64`.

## Verification limits

This environment does not have Flutter or Dart installed. Flutter dependency resolution, analyzer, formatter, tests, APK build, and Android SAF provider runtime behavior were not executed. The package is not claimed to be build-verified or device-verified.
