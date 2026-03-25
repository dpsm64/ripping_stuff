#!/usr/bin/env bash
# split_chapters.sh — Split a multi-episode MP4 into one file per episode
#
# Usage:
#   ./split_chapters.sh input.mp4
#   ./split_chapters.sh input.mp4 "Show Name - S01E"
#   ./split_chapters.sh input.mp4 "Show Name - S01E" /path/to/output/dir
#   ./split_chapters.sh input.mp4 "Show Name - S01E" /path/to/output/dir <start_ep>
#   ./split_chapters.sh input.mp4 "Show Name - S01E" /path/to/output/dir <start_ep> <chapters_per_ep>
#   ./split_chapters.sh input.mp4 "Show Name - S01E" /path/to/output/dir <start_ep> <chapters_per_ep> <chapter_map>
#
# Arguments:
#   output_prefix   (2nd): prefix for output filenames (default: input basename)
#   output_dir      (3rd): directory for output files (default: same dir as input)
#   start_episode   (4th): episode number for the first output file (default: 1)
#   chapters_per_ep (5th): chapters to merge per episode when all episodes are uniform (default: 1)
#   chapter_map     (6th): comma-separated list of chapters per episode, overrides chapters_per_ep
#                          e.g. "4,4,5,4" for a disc where episode 3 has an extra act
#
# Examples:
#   # Simple 1-chapter-per-episode (default)
#   ./split_chapters.sh "Show S01 Disc1.mp4" "Show - S01E"
#
#   # Uniform 4 chapters per episode, disc 2 starting at E05
#   ./split_chapters.sh "Show S01 Disc2.mp4" "Show - S01E" ~/Media/Show/S01/ 5 4
#
#   # Non-uniform disc: episodes have 4,4,5,4 chapters respectively
#   ./split_chapters.sh "Show S01 Disc3.mp4" "Show - S01E" ~/Media/Show/S01/ 9 1 "4,4,5,4"
#
# Requirements: ffprobe + ffmpeg in PATH, python3

set -euo pipefail

# ── Args ──────────────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <input.mp4> [output_prefix] [output_dir] [start_ep] [chapters_per_ep] [chapter_map]"
    exit 1
fi

INPUT="$1"
INPUT_DIR="$(dirname "$INPUT")"
INPUT_BASE="$(basename "${INPUT%.*}")"

PREFIX="${2:-$INPUT_BASE - E}"
OUTDIR="${3:-$INPUT_DIR}"
START_EP="${4:-1}"
CHAPTERS_PER_EP="${5:-1}"
CHAPTER_MAP="${6:-}"

if ! [[ "$START_EP" =~ ^[0-9]+$ ]]; then
    echo "Error: start_episode must be a positive integer (got: '$START_EP')"
    exit 1
fi

if ! [[ "$CHAPTERS_PER_EP" =~ ^[0-9]+$ ]] || [[ "$CHAPTERS_PER_EP" -lt 1 ]]; then
    echo "Error: chapters_per_ep must be a positive integer (got: '$CHAPTERS_PER_EP')"
    exit 1
fi

if [[ -n "$CHAPTER_MAP" ]] && ! [[ "$CHAPTER_MAP" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
    echo "Error: chapter_map must be a comma-separated list of integers (got: '$CHAPTER_MAP')"
    exit 1
fi

# ── Sanity checks ─────────────────────────────────────────────────────────────
if [[ ! -f "$INPUT" ]]; then
    echo "Error: file not found: $INPUT"
    exit 1
fi

command -v ffprobe &>/dev/null || { echo "Error: ffprobe not found in PATH"; exit 1; }
command -v ffmpeg  &>/dev/null || { echo "Error: ffmpeg not found in PATH";  exit 1; }

mkdir -p "$OUTDIR"

# ── Main: probe + split ───────────────────────────────────────────────────────
INPUT="$INPUT" PREFIX="$PREFIX" OUTDIR="$OUTDIR" START_EP="$START_EP" \
CHAPTERS_PER_EP="$CHAPTERS_PER_EP" CHAPTER_MAP="$CHAPTER_MAP" python3 << 'PYEOF'
import json, os, subprocess, sys

input_file      = os.environ['INPUT']
prefix          = os.environ['PREFIX']
outdir          = os.environ['OUTDIR']
start_ep        = int(os.environ['START_EP'])
chapters_per_ep = int(os.environ['CHAPTERS_PER_EP'])
chapter_map_str = os.environ['CHAPTER_MAP'].strip()

# ── Probe for chapters ────────────────────────────────────────────────────────
probe = subprocess.run(
    ['ffprobe', '-v', 'quiet', '-print_format', 'json', '-show_chapters', input_file],
    capture_output=True, text=True
)
if probe.returncode != 0:
    print("ffprobe failed:\n", probe.stderr)
    sys.exit(1)

chapters = json.loads(probe.stdout).get('chapters', [])

if not chapters:
    print("No chapter markers found in this file.")
    print("You'll need to specify timestamps manually — see the ffmpeg split example.")
    sys.exit(1)

print(f"Found {len(chapters)} chapter(s) in: {input_file}")

# ── Build episode groups ──────────────────────────────────────────────────────
if chapter_map_str:
    # Explicit map: e.g. "4,4,5,4"
    counts = [int(x) for x in chapter_map_str.split(',')]
    total_mapped = sum(counts)
    if total_mapped != len(chapters):
        print(f"Error: chapter_map sums to {total_mapped} but file has {len(chapters)} chapters.")
        print(f"       Check your map: {chapter_map_str}")
        sys.exit(1)
    groups = []
    pos = 0
    for n in counts:
        groups.append(chapters[pos:pos+n])
        pos += n
    print(f"Using chapter_map [{chapter_map_str}] -> {len(groups)} episode(s), starting at episode {start_ep}\n")
else:
    # Uniform chunk size
    if len(chapters) % chapters_per_ep != 0:
        print(f"Warning: {len(chapters)} chapters doesn't divide evenly by {chapters_per_ep}.")
        print(f"         The last episode will contain only {len(chapters) % chapters_per_ep} chapter(s).")
        print(f"         Consider using a chapter_map instead.")
    groups = [chapters[i:i+chapters_per_ep] for i in range(0, len(chapters), chapters_per_ep)]
    print(f"Grouping into {len(groups)} episode(s) of {chapters_per_ep} chapter(s) each, starting at episode {start_ep}\n")

ep_count = len(groups)

# ── Split ─────────────────────────────────────────────────────────────────────
errors = []
for i, group in enumerate(groups):
    ep_num = start_ep + i
    start  = group[0]['start_time']
    end    = group[-1]['end_time']
    output = os.path.join(outdir, f"{prefix}{ep_num:02d}.mp4")

    titles = [ch.get('tags', {}).get('title', '') for ch in group]
    titles = [t for t in titles if t]
    if titles:
        label = titles[0] if len(titles) == 1 else f"{titles[0]} ... {titles[-1]}"
    else:
        label = f"Episode {ep_num}"

    print(f"[{i+1}/{ep_count}] {label}")
    print(f"         {float(start):.3f}s -> {float(end):.3f}s  ({len(group)} chapter(s))")
    print(f"         -> {output}")

    cmd = [
        'ffmpeg', '-y',
        '-i',  input_file,
        '-ss', start,
        '-to', end,
        '-c',  'copy',
        '-map_chapters', '-1',
        output
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  *** ffmpeg error ***\n{result.stderr[-800:]}")
        errors.append(output)
    else:
        size_mb = os.path.getsize(output) / 1_048_576
        print(f"         OK  ({size_mb:.1f} MB)\n")

# ── Summary ───────────────────────────────────────────────────────────────────
if errors:
    print(f"\nFinished with {len(errors)} error(s):")
    for e in errors:
        print(f"  {e}")
    sys.exit(1)
else:
    print(f"All {ep_count} episode(s) written to: {outdir}")
PYEOF