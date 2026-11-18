"""Build the HEROLTE GPS replay blob from the recovery lhd capture (bbd-ref.tar).

Records are lhd's ttyBCM write() calls, verbatim, up to CUTOFF. Each record
carries the number of chip end-of-packet markers (ESC 0xb0, 0x01) lhd had
received before issuing that write, and a pre-send delay for long idle gaps.

Blob: "HGPSRPL1" u32 count u32 total_bytes, then per record
      u16 wait_eop, u16 delay_ms, u16 length, data[length].
"""
import hashlib, struct, sys, tarfile
src, out, cutoff = sys.argv[1], sys.argv[2], float(sys.argv[3])
rows = []
with tarfile.open(src) as t:
    for m in t.getmembers():
        if not m.isfile():
            continue
        p = m.name.rsplit('/', 1)[-1].split('-')
        if len(p) == 4 and p[2] == 'ttyBCM':
            rows.append((int(p[0]) + int(p[1]) / 1e9, p[3], t.extractfile(m).read()))
rows.sort(key=lambda r: r[0])

def eops(data, prev=0):
    n = 0
    for b in data:
        if prev == 0xb0 and b == 0x01:
            n += 1
        prev = b
    return n, prev

recs, seen, prev, last_w = [], 0, 0, None
reads_after = 0
for ts, d, data in rows:
    if d == 'r':
        n, prev = eops(data, prev)
        seen += n
        if ts > cutoff:
            reads_after += n
        continue
    if ts > cutoff:
        continue
    gap = 0 if last_w is None else ts - last_w
    delay = min(150, round(gap * 1000)) if gap > 0.02 else 0
    recs.append((seen, delay, data))
    last_w = ts

blob = bytearray(b'HGPSRPL1' + struct.pack('<II', len(recs), sum(len(r[2]) for r in recs)))
for w, dl, data in recs:
    assert len(data) < 65536
    blob += struct.pack('<HHH', w, dl, len(data)) + data
open(out, 'wb').write(blob)
print('records', len(recs), 'bytes', sum(len(r[2]) for r in recs), 'max write', max(len(r[2]) for r in recs),
      'final wait', recs[-1][0], 'chip eops total', seen, 'blob', len(blob), hashlib.sha256(blob).hexdigest())
print('delays', [(i, r[1]) for i, r in enumerate(recs) if r[1]])
