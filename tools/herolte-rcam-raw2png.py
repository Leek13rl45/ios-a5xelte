#!/usr/bin/env python3
"""The rear camera's raw frame (kern.herolte_rcam, stage 5) as a grayscale PNG.

  herolte-rcam-raw2png.py rcam-frame.raw [OUT.png] [--txt rcam-frame.txt] [--width 2016 --height 1512]

The dump is 16 bits a pixel, little-endian, RAW10 in bits 9:0 (CSIS0's DMA in normal packing), row after row. The
Bayer order is unknown, so every photosite becomes one gray pixel (no demosaic), stretched from the frame's 1st to
99th percentile to 0-255. A short dump (a frame cut off) is padded with black and said so. Width and height come from
rcam-frame.txt (hero-run writes it next to the raw file) when given, else from the options (mode 7: 2016 x 1512).
Standard library only.
"""
import argparse
import array
import os
import struct
import sys
import zlib


def read_txt(path):
    info = {}
    for line in open(path, encoding='utf-8', errors='replace'):
        parts = line.split(None, 1)
        if len(parts) == 2:
            info[parts[0]] = parts[1].strip()
    return info


def png(path, width, height, rows):
    """8-bit grayscale PNG, filter 0 on every row."""
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    raw = b''.join(b'\x00' + r for r in rows)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 0, 0, 0, 0)))
        f.write(chunk(b'IDAT', zlib.compress(raw, 6)))
        f.write(chunk(b'IEND', b''))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('raw')
    ap.add_argument('out', nargs='?')
    ap.add_argument('--txt', help="hero-run's rcam-frame.txt (width, height)")
    ap.add_argument('--width', type=int, default=2016)
    ap.add_argument('--height', type=int, default=1512)
    a = ap.parse_args()
    width, height = a.width, a.height
    if a.txt:
        info = read_txt(a.txt)
        width, height = int(info.get('width', width)), int(info.get('height', height))
    out = a.out or os.path.splitext(a.raw)[0] + '.png'

    data = open(a.raw, 'rb').read()
    need = width * height * 2
    if len(data) < need:
        print(f'{a.raw}: {len(data)} of {need} bytes ({100 * len(data) / need:.1f} %): the rest is black', file=sys.stderr)
        data += bytes(need - len(data))
    elif len(data) > need:
        print(f'{a.raw}: {len(data)} bytes, {need} used', file=sys.stderr)
    px = array.array('H')
    px.frombytes(data[:need])
    if sys.byteorder != 'little':
        px.byteswap()
    px = array.array('H', (v & 0x3ff for v in px))

    hist = [0] * 1024
    for v in px:
        hist[v] += 1
    total, lo, hi, acc = len(px), None, 1023, 0
    for v, n in enumerate(hist):
        acc += n
        if lo is None and acc > total * 0.01:
            lo = v
        if acc >= total * 0.99:
            hi = v
            break
    lo = lo or 0
    span = max(hi - lo, 1)
    lut = bytes(min(255, max(0, (v - lo) * 255 // span)) for v in range(1024))
    rows = [bytes(lut[v] for v in px[y * width:(y + 1) * width]) for y in range(height)]
    png(out, width, height, rows)
    mean = sum(v * n for v, n in enumerate(hist)) / total
    print(f'{out}: {width} x {height} gray, RAW10 min {min(px)} max {max(px)} mean {mean:.1f}, stretched {lo}-{hi}')


if __name__ == '__main__':
    main()
