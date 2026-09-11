# Ghidra launcher
ghidra() {
    "$HOME/tools/ghidra_11.4.2_PUBLIC/ghidraRun" "$@"
}

# Change directory using fzf
cdf() {
    cd "$(find . -type d | fzf)"
}

# Open file using fzf in VSCode
codef() {
    code "$(find . -type f | fzf)"
}

# Launch a Debian container for reverse engineering
crackenv() {
    docker run --rm -it --platform=linux/amd64 \
        -v "$PWD":/crackme \
        -w /crackme \
        debian:stable-slim bash
}

# Pretty print JSON
json() {
    python3 -m json.tool <<< "$1"
}

# Start a simple HTTP server in the current directory
serve() {
    python3 -m http.server 8000
}

# Extract audio from a video file using ffmpeg
extract_audio() {
    if [ $# -lt 1 ]; then
        echo "Usage: extract_audio <input_file> [output_file]"
        return 1
    fi

    local in="$1"

    if [ ! -f "$in" ]; then
        echo "extract_audio: file not found: $in"
        return 1
    fi

    local out

    if [ $# -ge 2 ]; then
        # If user specified an output file, use it as-is
        out="$2"
    else
        # Default: same name + _audio.m4a
        local base="${in%.*}"
        out="${base}_audio.m4a"
    fi

    # -vn: no video
    # -acodec aac: re-encode audio as AAC (widely supported)
    # -b:a 192k: reasonable quality/size tradeoff
    ffmpeg -i "$in" -vn -acodec aac -b:a 192k "$out"
}

# Transcribe audio using OpenAI Whisper in a conda environment
whisp() {
    if [ $# -lt 1 ]; then
        echo "Usage: whisper_transcribe <input_file> [whisper_args...]" >&2
        return 1
    fi

    local in="$1"
    shift

    # Check file exists
    if [ ! -f "$in" ]; then
        echo "whisper_transcribe: file not found: $in" >&2
        return 1
    fi

    # Extract base name (no extension)
    local name="$(basename "$in")"
    local base="${name%.*}"

    # Create output directory (next to the input file)
    local outdir="$(dirname "$in")/$base"
    mkdir -p "$outdir"

    # Temp audio for whisper
    local tmp_audio="$(dirname "$in")/${base}_whisper_tmp.wav"

    echo "[*] Extracting/normalizing audio with ffmpeg..."
    ffmpeg -y -i "$in" -vn -ac 1 -ar 16000 -f wav "$tmp_audio"
    if [ $? -ne 0 ]; then
        echo "whisper_transcribe: ffmpeg failed" >&2
        return 1
    fi

    # Default model (feel free to change it)
    local model="turbo"

    echo "[*] Running whisper in conda env 'whisper'..."
    (
        # Enable conda inside subshell
        if command -v conda >/dev/null 2>&1; then
            eval "$(conda shell.zsh hook)" 2>/dev/null
            conda activate whisper >/dev/null 2>&1
        else
            echo "whisper_transcribe: conda not found in subshell" >&2
            exit 1
        fi

        # Whisper writes output name based on temp audio name
        # So we use --output_dir to place the final files
        whisper "$tmp_audio" \
            --model "$model" \
            --output_dir "$outdir" \
            "$@"
    )
    local status=$?

    if [ $status -eq 0 ]; then
        rm -f "$tmp_audio"
        echo "[*] Transcription saved to: $outdir"
    else
        echo "whisper_transcribe: whisper failed (temp file kept: $tmp_audio)" >&2
    fi

    return $status
}

# Zsh smart compressor: targets a maximum file size (default 10 MB) using 2-pass x264.
# Usage:
#   smartcomp input_video [max_mb=10] [output.mp4]
# Examples:
#   smartcomp in.mov
#   smartcomp in.mov 25
#   smartcomp in.mov 8 out.mp4
smartcomp() {
  emulate -L zsh

  local in="$1"
  local max_mb="${2:-10}"
  local out="$3"

  if [[ -z "$in" || ! -f "$in" ]]; then
    print -u2 "Usage: smartcomp input_video [max_mb=10] [output.mp4]"
    return 2
  fi

  # Default output: <input>_<max_mb>mb.mp4
  if [[ -z "$out" ]]; then
    out="${in:r}_${max_mb}mb.mp4"
  fi

  local tmpdir passlog
  tmpdir="$(mktemp -d -t smartcomp.XXXXXX)" || { print -u2 "mktemp failed"; return 1; }
  passlog="${tmpdir}/ffmpeg2pass"  # prefix; ffmpeg will append -0.log etc.

  {
    # Get duration (seconds, floating point)
    local dur
    dur="$(ffprobe -v error -show_entries format=duration \
          -of default=noprint_wrappers=1:nokey=1 -- "$in")"
    if [[ -z "$dur" ]]; then
      print -u2 "ffprobe failed to read duration."
      return 3
    fi

    # Leave headroom so we don't overshoot due to container overhead/rounding
    local margin="0.95"

    # Audio bitrate (kbps) — we’ll auto-drop it if video budget gets tiny
    local a_kbps=96

    # Total target bitrate (kbps) from size and duration
    local target_total_kbps
    target_total_kbps="$(awk -v mb="$max_mb" -v d="$dur" -v m="$margin" \
      'BEGIN{ printf "%.0f", (mb*1024*1024*8*m)/(d*1000) }')"

    # If total budget is small, reduce audio bitrate to leave room for video
    if (( target_total_kbps < 220 )); then
      a_kbps=64
    fi
    if (( target_total_kbps < 160 )); then
      a_kbps=48
    fi

    # Video bitrate (kbps)
    local v_kbps
    v_kbps="$(awk -v t="$target_total_kbps" -v a="$a_kbps" \
      'BEGIN{ v=t-a; if(v<50) v=50; printf "%.0f", v }')"

    print "== smartcomp =="
    print "Input:  $in"
    print "Output: $out"
    print "Limit:  ${max_mb} MB (margin ${margin})"
    print "Dur:    ${dur}s"
    print "Rates:  total ${target_total_kbps} kbps | audio ${a_kbps} kbps | video ${v_kbps} kbps"

    # Pass 1 (video only)
    ffmpeg -y -i "$in" \
      -c:v libx264 -preset medium -b:v "${v_kbps}k" \
      -pass 1 -passlogfile "$passlog" \
      -an -f mp4 /dev/null || return 4

    # Pass 2 (video + audio)
    ffmpeg -y -i "$in" \
      -c:v libx264 -preset medium -b:v "${v_kbps}k" \
      -pass 2 -passlogfile "$passlog" \
      -c:a aac -b:a "${a_kbps}k" -ac 2 \
      -movflags +faststart \
      "$out" || return 5

    # Report final size
    local bytes
    bytes="$(wc -c < "$out" 2>/dev/null || echo 0)"
    awk -v b="$bytes" -v mb="$max_mb" 'BEGIN{
      printf "Final size: %.2f MB (limit %.2f MB)\n", b/1024/1024, mb
    }'

  } always {
    # Zsh "finally": always clean temp dir, even on errors/return.
    command rm -rf -- "${tmpdir:?}"
  }
}
