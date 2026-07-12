# Local changes

This package is based on `file_selector_android` 0.5.2+8.

The upstream Android implementation copies a selected file to the application
cache and also reads the entire file into a `byte[]` for the Pigeon response.
Large ASR model archives exceed the Android heap limit during that second copy.

This local version:

- returns the streamed cache path without an in-memory file copy;
- creates the Dart `XFile` from that path;
- skips files whose cache copy could not be created instead of throwing a null
  pointer exception.
