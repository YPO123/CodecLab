# Contributing

CodecLab is an offline-first audio tool. Contributions should preserve the core product constraints:

- Do not add account, upload, cloud processing, telemetry, advertising, or automatic update networking.
- Keep audio processing local to the user's Mac.
- Treat FFmpeg and codec licensing as release-blocking work, not cleanup.
- Avoid describing MP3 support as a new FFmpeg native MP3 encoder. MP3 encoding is handled through `libmp3lame`.

For code changes, prefer small focused pull requests with a short test note.

