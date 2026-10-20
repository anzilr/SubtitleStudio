# CP86 R7 — FFmpeg decode-progress feedback

## CP86 R7 — Native decode progress without false percentages (2026-10-20)

Physical test `cp86_r6_waveform_perf.log` (OnePlus CPH2381, Android 14) measured a **137,089 ms** first load, including **134,990 ms FFmpeg execution**, **1,881 ms peak conversion**, 24 ms zoom metadata and about 1947 ms for validated warm source load (of which 1825 ms was the cache reader). Cold extraction was about 98.47% native decoding. A single warm reopening was captured. Peak-cache generation is not the meaningful wall-clock bottleneck.

CP86 R7 exposes FFmpegKit's supported per-session statistics callback as *processed audio time* (not a percentage, since source media duration is not available/guaranteed for SAF). The timeline is monotonic, throttled to two-second media increments, is discarded when the active request changes, and never logs SAF paths in the new callback. A compact second line is displayed only in sufficiently tall waveform loading panes. Pure regression tests cover invalid/regressing stats, formatting and per-request isolation.

This change improves feedback while decoding continues; **it does not speed up FFmpeg**. Next efficiency work should evaluate alternative decoding architectures on a separate experimental branch with physical-device profiling (progressive/tiled decode and seek/gap semantics), preserving signed timing, multi-track mapping and atomic source-specific cache updates. Do not compromise the stable CP87 R13 Back gesture fix.
