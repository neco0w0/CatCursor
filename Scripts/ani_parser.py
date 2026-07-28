import struct
import io
from PIL import Image


def parse_ani(path):
    with open(path, "rb") as f:
        data = f.read()

    assert data[0:4] == b"RIFF"
    assert data[8:12] == b"ACON"

    pos = 12
    header = None
    frames = []  # raw icon/cur bytes in file order (this is the frame image list)
    seq = None   # optional custom display order (indices into frames)

    while pos < len(data):
        chunk_id = data[pos:pos + 4]
        chunk_size = struct.unpack("<I", data[pos + 4:pos + 8])[0]
        chunk_data = data[pos + 8:pos + 8 + chunk_size]

        if chunk_id == b"anih":
            # ANIHEADER: cbSizeOf,nFrames,nSteps,cx,cy,cBitCount,cPlanes,iDispRate,bfAttributes
            header = struct.unpack("<9I", chunk_data[:36])
        elif chunk_id == b"LIST":
            list_type = chunk_data[0:4]
            if list_type == b"fram":
                sub = chunk_data[4:]
                spos = 0
                while spos < len(sub):
                    sub_id = sub[spos:spos + 4]
                    sub_size = struct.unpack("<I", sub[spos + 4:spos + 8])[0]
                    sub_data = sub[spos + 8:spos + 8 + sub_size]
                    if sub_id == b"icon":
                        frames.append(sub_data)
                    spos += 8 + sub_size
                    if sub_size % 2 == 1:
                        spos += 1
        elif chunk_id == b"seq ":
            seq = list(struct.unpack(f"<{chunk_size // 4}I", chunk_data))
        elif chunk_id == b"rate":
            pass

        pos += 8 + chunk_size
        if chunk_size % 2 == 1:
            pos += 1

    n_frames, n_steps = header[1], header[2]
    cx, cy = header[3], header[4]
    jif_rate = header[7]

    images = []
    hotspots = []
    for raw in frames:
        im = Image.open(io.BytesIO(raw))
        im.load()
        images.append(im)
        # parse hotspot directly from the CUR header (bytes 10-11 = xHotspot, 12-13 = yHotspot)
        # CUR format: 0-1 reserved, 2-3 type(2=cur), 4-5 count, then per-image dir entries of 16 bytes
        if raw[2:4] == b"\x02\x00":
            hx, hy = struct.unpack("<HH", raw[10:14])
            hotspots.append((hx, hy))
        else:
            hotspots.append(None)

    return {
        "n_frames": n_frames,
        "n_steps": n_steps,
        "jif_rate": jif_rate,
        "fps": 60 / jif_rate if jif_rate else None,
        "seq": seq,
        "images": images,
        "hotspots": hotspots,
    }


if __name__ == "__main__":
    import sys
    r = parse_ani(sys.argv[1])
    print("frames:", r["n_frames"], "steps:", r["n_steps"], "fps:", r["fps"], "seq:", r["seq"])
    for i, (im, hs) in enumerate(zip(r["images"], r["hotspots"])):
        print(i, im.size, im.mode, "hotspot:", hs)
