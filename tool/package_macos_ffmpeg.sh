#!/usr/bin/env bash
# Bundle portable FFmpeg + FFprobe into a Flutter macOS application.
# Run from the repository root on a macOS GitHub Actions runner.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <path-to-SubtitleStudio.app>" >&2
  exit 2
fi

app="$1"
if [[ ! -d "$app/Contents/Resources" ]]; then
  echo "::error::Not a macOS application bundle: $app" >&2
  exit 1
fi

# Pin the vendor's FFmpeg 9.0.2 release, never a mutable 'latest' URL.
# See https://ffmpeg.martin-riedl.de/ for build scripts and source links.
source_base="https://ffmpeg.martin-riedl.de/download/macos"
work="$(mktemp -d)"
destination="$app/Contents/Resources/tools/ffmpeg"
bin="$destination/bin"
mkdir -p "$bin"

fetch_arch_tool() {
  local arch="$1" release="$2" tool="$3" expected_sha="$4"
  local archive="$work/$arch-$tool.zip"
  local extracted="$work/$arch-$tool"
  local binary
  echo "Downloading FFmpeg 9.0.2 $tool for macOS $arch"
  curl --fail --show-error --silent --location --retry 3 --retry-all-errors \
    --connect-timeout 20 --max-time 300 \
    "$source_base/$arch/$release/$tool.zip" --output "$archive"
  printf '%s  %s\n' "$expected_sha" "$archive" | shasum -a 256 -c -

  mkdir -p "$extracted"
  ditto -x -k "$archive" "$extracted"
  binary="$(find "$extracted" -type f -name "$tool" -print -quit)"
  if [[ -z "$binary" || ! -f "$binary" ]]; then
    echo "::error::No $tool executable in the $arch archive" >&2
    exit 1
  fi
  chmod 755 "$binary"
  local expected_arch="x86_64"
  if [[ "$arch" == "arm64" ]]; then expected_arch="arm64"; fi
  if [[ " $(lipo -archs "$binary") " != *" $expected_arch "* ]]; then
    echo "::error::$tool archive has unexpected CPU architecture" >&2
    exit 1
  fi
  cp "$binary" "$work/$arch-$tool"
}

fetch_arch_tool amd64 1789931006_9.0.2 ffmpeg \
  7c6b4125b191cbf773832dc51f424cf2b6bb7da43007d1e066f95909e47cacd4
fetch_arch_tool amd64 1789931006_9.0.2 ffprobe \
  2322438ed2f6319a691291b247d09c69dcaa3a982460d1f269a7e1af335cfdfd
fetch_arch_tool arm64 1789931890_9.0.2 ffmpeg \
  c8ed4c4e6978a03c485edbfe4e0a5dc2380f8a30bba5150531b31b094492d924
fetch_arch_tool arm64 1789931890_9.0.2 ffprobe \
  fcbe839537485eaee7a7a8bc5cbc0f90d53617e80943e8a5b2e31cb851197ea6

for tool in ffmpeg ffprobe; do
  lipo -create "$work/amd64-$tool" "$work/arm64-$tool" \
    -output "$bin/$tool"
  chmod 755 "$bin/$tool"
  if [[ "$(lipo -archs "$bin/$tool")" != *"x86_64"* ]] || \
     [[ "$(lipo -archs "$bin/$tool")" != *"arm64"* ]]; then
    echo "::error::Packaged $tool is not universal (Intel + Apple Silicon)" >&2
    exit 1
  fi
  # Combining signed thin binaries invalidates their original signatures.
  # This is ad-hoc signing for private CI testing, NOT Apple notarization.
  codesign --force --sign - "$bin/$tool"
  codesign --verify "$bin/$tool"
  if otool -L "$bin/$tool" | grep -E '/opt/homebrew/|/usr/local/|@rpath/'; then
    echo "::error::Packaged $tool depends on non-system libraries" >&2
    exit 1
  fi
  "$bin/$tool" -version | head -n 3
done

# Smoke-test the actual packaged executables, not a runner PATH installation.
sample="$work/subtitlestudio-media-test.wav"
"$bin/ffmpeg" -hide_banner -loglevel error -f lavfi \
  -i 'sine=frequency=440:duration=0.25' -ac 1 -ar 44100 -y "$sample"
test -s "$sample"
"$bin/ffprobe" -v error -show_entries stream=codec_name \
  -of csv=p=0 "$sample" | grep -q 'pcm_s16le'

# Keep build provenance and the FFmpeg license beside the redistributed tools.
"$bin/ffmpeg" -L > "$destination/FFMPEG_LICENSE.txt"
"$bin/ffmpeg" -version > "$destination/FFMPEG_BUILD_INFO.txt"
ditto installer/macos/FFMPEG_NOTICE.txt "$destination/NOTICE.txt"
echo "Portable FFmpeg and FFprobe included and verified in $app"
