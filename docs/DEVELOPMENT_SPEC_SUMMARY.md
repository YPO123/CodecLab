# CodecLab Development Spec Summary

CodecLab is a free offline macOS app for local codec testing. It focuses on:

- Original / Encoded / Difference monitoring
- ABX blind tests with binomial p-values
- Null tests with automatic alignment
- Per-channel residual reporting for multichannel audio
- Current MP3 generation through FFmpeg + `libmp3lame`
- Legacy MP3 import for old MP3 comparison
- AAC and Opus workflows
- HTML and JSON local report export

Important terminology:

- "Current MP3" means the MP3 produced by the currently configured FFmpeg build with `libmp3lame`.
- Do not claim FFmpeg has a new native MP3 encoder.
- Recent FFmpeg encoder discussion is more relevant to AAC than MP3.

