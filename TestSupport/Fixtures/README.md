# Synthetic fixture catalog

All files in this directory are authored for deterministic tests. They contain no
captured Tieba response, user account, Cookie, token, device identifier, private
text or third-party media.

- `JSON/success.json`: valid JSON decoding path.
- `JSON/malformed.json`: deterministic malformed JSON path.
- `Binary/opaque.pb`: opaque bytes for the binary fixture loading path. No schema
  or Tieba field meaning is claimed before phase 07.
- `Images/pixel.svg`: original 1×1 synthetic SVG for image resource loading.
- `Text/hash-mismatch.txt`: deterministic hash mismatch path.

`manifest.json` records the format, source, purpose, sanitization status and
SHA-256 for every fixture entry.
