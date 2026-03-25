#!/usr/bin/env bash
# split_chapters.sh — Split a multi-episode MP4 into one file per episode
#
# Usage:
#   ./split_chapters.sh input.mp4
#   ./split_chapters.sh input.mp4 "Show Name - S01E"
#   ./split_chapters.sh input.mp4 "Show Name - S01E" /path/to/output/dir
#   ./split_chapters.sh input.mp4 "Show Name - S01E" /path/to/output/dir 4
#   ./split_chapters.sh input.mp4 "Show Name - S01E" /path/to/output/dir 4 4
#
# Output files will be named: <prefix><NN>.mp4  (e.g. "Show Name - S01E04.mp4")
# If no prefix is given, the input filename (sans extension) is used.
# If no output dir is given, files are written alongside the input file.
# start_episode   (4th arg): episode number for the first output file (default: 1).
# chapters_per_ep (5th arg): how many chapters to merge into one episode (default: 1).
#                            Use 4 for a 1-hour show split into four acts per episode.
#
# Requirements: ffprobe + ffmpeg in PATH, python3
