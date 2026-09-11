# Change directory using fzf
cdf() {
    cd "$(find . -type d | fzf)"
}

# Open file using fzf in VSCode
codef() {
    code "$(find . -type f | fzf)"
}

# Pretty print JSON
json() {
    python3 -m json.tool <<< "$1"
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
