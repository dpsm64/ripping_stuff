#!/usr/bin/env python3
"""
rename_episodes.py - Copy media files from a source directory to an output
directory, renaming them to a Jellyfin/Plex-compatible episode naming scheme.

Usage:
    python3 rename_episodes.py [--preview] <source_dir> <title> <season> <output_dir>

Options:
    --preview   Print what would be copied (source, destination, file size)
                without actually copying anything.

Examples:
    python3 rename_episodes.py --preview /mnt/rips/disc1 "The Wire" 2 /media/tv/The_Wire/Season_02
    python3 rename_episodes.py /mnt/rips/disc1 "The Wire" 2 /media/tv/The_Wire/Season_02
"""

import sys
import os
import shutil


def usage():
    print(__doc__)
    sys.exit(1)


def format_size(num_bytes):
    for unit in ("B", "KB", "MB", "GB"):
        if num_bytes < 1024:
            return f"{num_bytes:.1f} {unit}"
        num_bytes /= 1024
    return f"{num_bytes:.1f} TB"


def main():
    args = sys.argv[1:]

    preview = "--preview" in args
    if preview:
        args = [a for a in args if a != "--preview"]

    if len(args) != 4:
        usage()

    source_dir, title, season_str, output_dir = args

    # Validate season number
    try:
        season = int(season_str)
        if season < 0:
            raise ValueError
    except ValueError:
        print(f"Error: season must be a non-negative integer, got '{season_str}'")
        sys.exit(1)

    # Validate source directory
    if not os.path.isdir(source_dir):
        print(f"Error: source directory does not exist: {source_dir}")
        sys.exit(1)

    # Collect and sort files by creation time, earliest first (directories are skipped)
    entries = sorted(
        (e for e in os.listdir(source_dir)
         if os.path.isfile(os.path.join(source_dir, e))),
        key=lambda e: os.stat(os.path.join(source_dir, e)).st_birthtime
        if hasattr(os.stat(os.path.join(source_dir, e)), "st_birthtime")
        else os.stat(os.path.join(source_dir, e)).st_mtime
    )

    if not entries:
        print(f"No files found in {source_dir}")
        sys.exit(0)

    # Sanitize title for use in filenames (replace spaces with underscores,
    # strip characters that are problematic on most filesystems)
    safe_title = "".join(
        c if c.isalnum() or c in " ._-" else "_"
        for c in title
    ).replace(" ", "_")

    season_str_padded = f"{season:02d}"
    prefix = "[PREVIEW] " if preview else ""

    print(f"{prefix}Source : {source_dir}")
    print(f"{prefix}Output : {output_dir}")
    print(f"{prefix}Title  : {title}")
    print(f"{prefix}Season : {season_str_padded}")
    print(f"{prefix}Files  : {len(entries)}")
    print()

    if preview:
        src_w = max(len(e) for e in entries)
        dst_w = max(
            len(f"{safe_title}_S{season_str_padded}E{ep:02d}{os.path.splitext(e)[1]}")
            for ep, e in enumerate(entries, start=1)
        )
        print(f"  {'SOURCE FILE':<{src_w}}  {'DESTINATION FILE':<{dst_w}}  SIZE")
        print(f"  {'-' * src_w}  {'-' * dst_w}  ----")
        for episode, filename in enumerate(entries, start=1):
            ext = os.path.splitext(filename)[1]
            new_name = f"{safe_title}_S{season_str_padded}E{episode:02d}{ext}"
            src_path = os.path.join(source_dir, filename)
            size = format_size(os.path.getsize(src_path))
            print(f"  {filename:<{src_w}}  {new_name:<{dst_w}}  {size}")
        print()
        print("Preview only — no files were copied.")
    else:
        os.makedirs(output_dir, exist_ok=True)

        for episode, filename in enumerate(entries, start=1):
            ext = os.path.splitext(filename)[1]
            new_name = f"{safe_title}_S{season_str_padded}E{episode:02d}{ext}"
            src_path = os.path.join(source_dir, filename)
            dst_path = os.path.join(output_dir, new_name)

            if os.path.exists(dst_path):
                print(f"  SKIP (already exists): {new_name}")
                continue

            print(f"  {filename}  ->  {new_name}")
            shutil.copy2(src_path, dst_path)

        print("\nDone.")


if __name__ == "__main__":
    main()