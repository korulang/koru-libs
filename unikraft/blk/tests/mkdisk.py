#!/usr/bin/env python3
# The 32 KB virtio-blk backing file boot_lifecycle.kz expects: 64 sectors of
# 512 B, with sector 0 filled edge to edge with printable text so the console
# shows the whole transfer. Sector 1 is what the program writes.
#
#   python3 mkdisk.py disk.img
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "disk.img"
head = (b"KORU DISK SECTOR ZERO -- planted by the host, read back by "
        b"unikraft/blk from a real virtio-blk device. ")
sector0 = (head + b"-" * 512)[:512]
open(path, "wb").write(sector0 + b"\x00" * (512 * 63))
print(f"{path}: 64 sectors x 512 B")
