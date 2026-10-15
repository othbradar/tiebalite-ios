# U13 synthetic media fixtures

No account, user content, network response or credentials. Generated locally with Pillow 12.3.0 and ffmpeg.

- bounded.gif / bounded.webp: 240×160, four moving colored rectangles, 120/180/240/300 ms, infinite loop. WebP lossless. ImageIO tests check distinct downsampled frames and original encoded bytes.
- video.mp4: ffmpeg testsrc2 320×180 @24 fps, 8 seconds, H.264/yuv420p + 440 Hz AAC sine, faststart.
- voice.m4a: 8 seconds of 660 Hz AAC sine.
- Identical Debug-only copies in Resources/DebugU13Media for the existing Renderer Lab. Release excludes the folder and Debug Swift sources.

Real Tieba samples are not committed. Live format/read checks are recorded separately in TASK_STATE and ignored Artifacts.
