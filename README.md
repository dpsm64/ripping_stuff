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
