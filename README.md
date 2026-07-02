# CodecLab

CodecLab is a free, offline macOS tool for codec comparison, ABX listening, and null-difference monitoring. It is designed for audio engineers, producers, teachers, students, podcast/video creators, and anyone who needs to decide whether MP3, AAC, or Opus encoding is audibly different from a reference file.

The app is intentionally local-first:

- No account
- No cloud processing
- No upload
- No telemetry
- No automatic update checks

## Status

This repository currently contains the first SwiftUI prototype:

- Drag-and-drop or picker-based reference audio import
- Metadata display for sample rate, bit depth, channel count, duration, codec, and lossy source warnings
- 10/15/30/60 second test region selection
- FFmpeg diagnostics with `libmp3lame`, AAC, and Opus availability checks
- Current MP3 generation through `libmp3lame`
- Legacy MP3 import and decode path
- Original / Current MP3 / Legacy MP3 playback switching through `AVAudioEngine`
- Null-test and ABX service foundations

## Why "Current MP3"?

FFmpeg does not provide a native MP3 encoder. CodecLab treats "Current MP3" as the result produced by the currently configured FFmpeg build with `libmp3lame` enabled. The app must verify that `libmp3lame` is available before enabling Current MP3 generation.

## Requirements

- macOS 13.5 Ventura or later
- Xcode 26 or later is recommended for this prototype
- XcodeGen for regenerating the Xcode project
- FFmpeg with `libmp3lame` enabled for MP3 generation

CodecLab first looks for bundled `ffmpeg`/`ffprobe` binaries in the app resources. During development, it can also use common local FFmpeg paths such as `/opt/homebrew/bin/ffmpeg` and `/usr/local/bin/ffmpeg`.

## Build

```bash
xcodegen generate
xcodebuild -scheme CodecLab -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

## License

CodecLab source code is released under the MIT License.

FFmpeg and codec libraries have their own licenses. Release builds that bundle FFmpeg must include the relevant license notices and configure flags under `CodecLab/Resources/LICENSES`.

