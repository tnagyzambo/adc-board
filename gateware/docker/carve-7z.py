#!/usr/bin/env python3
"""Copy every 7-Zip archive embedded in a file out into a directory.

    carve-7z.py INSTALLER OUTDIR

A Qt Installer Framework installer stores the payload of each component as a
7-Zip archive inside the installer binary, and installing a component is
unpacking its archive into the target directory. This finds those archives
without running the installer: it scans for the 7-Zip signature, accepts a
match only if the start header's CRC is right, takes the archive's length
from that header, and writes it out as OUTDIR/partNN.7z. A match inside an
archive already found is skipped. Prints one line per archive.
"""

import os
import struct
import sys
import zlib

SIGNATURE = b"7z\xbc\xaf\x27\x1c"
START_HEADER = 32
CHUNK = 64 << 20


def find_archives(f, size):
    """Yield (offset, length) of each valid, non-nested 7-Zip archive."""
    pos = 0
    tail = b""
    end_of_last = 0
    while True:
        buf = f.read(CHUNK)
        if not buf:
            return
        data = tail + buf
        base = pos - len(tail)
        i = data.find(SIGNATURE)
        while i != -1:
            # A signature too near the end of the window is seen again, whole,
            # at the start of the next one.
            if i + START_HEADER <= len(data):
                offset = base + i
                header = data[i:i + START_HEADER]
                (crc,) = struct.unpack_from("<I", header, 8)
                next_offset, next_size = struct.unpack_from("<QQ", header, 12)
                length = START_HEADER + next_offset + next_size
                if (offset >= end_of_last
                        and header[6] == 0
                        and zlib.crc32(header[12:32]) == crc
                        and next_size > 0
                        and offset + length <= size):
                    end_of_last = offset + length
                    yield offset, length
            i = data.find(SIGNATURE, i + 1)
        tail = data[-(START_HEADER - 1):]
        pos += len(buf)


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    size = os.path.getsize(src)
    with open(src, "rb") as f:
        archives = list(find_archives(f, size))
        for n, (offset, length) in enumerate(archives):
            out = os.path.join(outdir, f"part{n:02d}.7z")
            f.seek(offset)
            left = length
            with open(out, "wb") as o:
                while left:
                    block = f.read(min(CHUNK, left))
                    if not block:
                        sys.exit(f"{src}: archive at {offset} runs past the end of the file")
                    o.write(block)
                    left -= len(block)
            print(f"{out}: {length} bytes at offset {offset}")
    if not archives:
        sys.exit(f"{src}: no 7-Zip archives found")


if __name__ == "__main__":
    main()
