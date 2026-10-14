# Checkpoint 82: controlled two-track media and extraction diagnostics.
# Requires ffmpeg and ffprobe on PATH; no user media is read or modified.
param(
    [string]$OutputDirectory = ".\build\waveform_checkpoint82"
)
$ErrorActionPreference = "Stop"
foreach ($toolName in @("ffmpeg", "ffprobe")) {
    if (-not (Get-Command $toolName -ErrorAction SilentlyContinue)) {
        throw "Missing $toolName. Install FFmpeg and add bin folder to PATH."
    }
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$root = (Resolve-Path $OutputDirectory).Path
$fixture = Join-Path $root "multitrack_pts_gap.mkv"
$track0 = Join-Path $root "track_0.pcm"
$track1 = Join-Path $root "track_1.pcm"
$auto = Join-Path $root "auto.pcm"
$invalid = Join-Path $root "invalid_track.pcm"
$report = Join-Path $root "waveform_probe.json"
$failureLog = Join-Path $root "invalid_track_stderr.txt"

function Invoke-FFmpeg([string[]] $Options) {
    & ffmpeg @Options
    if ($LASTEXITCODE -ne 0) {
        throw "FFmpeg failed (exit $LASTEXITCODE)."
    }
}
# Track 0: 440 Hz, t=0; track 1: 880 Hz, t=1.25 s.
Invoke-FFmpeg @(
    "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
    "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=44100:duration=3",
    "-itsoffset", "1.25",
    "-f", "lavfi", "-i", "sine=frequency=880:sample_rate=44100:duration=3",
    "-map", "0:a:0", "-map", "1:a:0",
    "-c:a", "pcm_s16le",
    "-metadata:s:a:0", "language=eng",
    "-metadata:s:a:1", "language=fra",
    $fixture
)
$probeText = (& ffprobe -v error -select_streams a -show_entries "stream=index,codec_type,sample_rate,start_time:stream_tags=language" -of json $fixture) -join [Environment]::NewLine
if ($LASTEXITCODE -ne 0) { throw "ffprobe failed to inspect the fixture." }
$streams = @((ConvertFrom-Json $probeText).streams)
if ($streams.Count -ne 2) {
    throw "Fixture should contain two audio streams; found $($streams.Count)."
}
$base = @("-hide_banner", "-loglevel", "error", "-nostdin", "-y", "-i", $fixture)
$pcm = @("-af", "aresample=async=1:first_pts=0",
         "-ac", "1", "-ar", "44100", "-f", "s16le", "-acodec", "pcm_s16le")
Invoke-FFmpeg ($base + @("-map", "0:a:0") + $pcm + @($track0))
Invoke-FFmpeg ($base + @("-map", "0:a:1") + $pcm + @($track1))
Invoke-FFmpeg ($base + $pcm + @($auto))

# Missing streams must fail explicitly rather than silently using audio 0.
if (Test-Path $invalid) { Remove-Item $invalid -Force }
& ffmpeg @($base + @("-map", "0:a:9") + $pcm + @($invalid)) 2> $failureLog
$invalidExit = $LASTEXITCODE
if ($invalidExit -eq 0) {
    throw "Regression: selecting 0:a:9 incorrectly succeeded."
}
if (Test-Path $invalid) { Remove-Item $invalid -Force }

$sample0 = [long]((Get-Item $track0).Length / 2)
$sample1 = [long]((Get-Item $track1).Length / 2)
$sampleAuto = [long]((Get-Item $auto).Length / 2)
$prefix = New-Object byte[] 4096
$stream = [System.IO.File]::OpenRead($track1)
try {
    $read = $stream.Read($prefix, 0, $prefix.Length)
} finally {
    $stream.Dispose()
}
$prefixAllZero = $true
for ($i = 0; $i -lt $read; $i++) {
    if ($prefix[$i] -ne 0) { $prefixAllZero = $false; break }
}
$summary = [ordered]@{
    fixture = $fixture
    createdAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    audioStreamCount = $streams.Count
    audioStreams = $streams
    expectedFirstTrackHz = 440
    expectedSecondTrackHz = 880
    secondTrackPtsOffsetSeconds = 1.25
    pcmSampleRate = 44100
    firstTrackSamples = $sample0
    delayedTrackSamples = $sample1
    automaticTrackSamples = $sampleAuto
    delayedTrackLeading4096BytesSilent = $prefixAllZero
    invalidTrackExitCode = $invalidExit
    firstTrackSHA256 = (Get-FileHash $track0 -Algorithm SHA256).Hash
    delayedTrackSHA256 = (Get-FileHash $track1 -Algorithm SHA256).Hash
    automaticTrackSHA256 = (Get-FileHash $auto -Algorithm SHA256).Hash
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $report -Encoding UTF8
$summary | ConvertTo-Json -Depth 8
Write-Host "Probe outputs: $root"
# Timings and prefix-silence results must be reviewed on the actual FFmpeg
# version; generating this fixture does NOT run or verify the Flutter app.
