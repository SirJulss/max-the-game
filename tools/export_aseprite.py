#!/usr/bin/env python3
"""Export the game's original Aseprite art without resizing or repainting pixels.

Usage (from the repository root):
    python tools/export_aseprite.py
    python tools/export_aseprite.py Assets/npc/*.ase --manifest Assets/npc/sprites.json

Requires Pillow. Implements the official little-endian ASE format:
https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md

Supports RGBA, grayscale and indexed images, raw/compressed/linked cels,
palette changes, layer visibility, normal alpha composition and frame timing.
The actual NPC sources are RGBA with one fully opaque, visible normal layer.
Unsupported blend/tilemap/group-opacity features fail loudly instead of
silently exporting changed artwork. The .ase sources are never modified.
"""

from __future__ import annotations

import argparse
import glob
import json
import struct
import zlib
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


class AseError(ValueError):
    pass


@dataclass
class Layer:
    name: str
    flags: int
    kind: int
    level: int
    blend: int
    opacity: int


@dataclass
class Cel:
    layer: int
    x: int
    y: int
    opacity: int
    z: int
    pixels: bytes | None = None
    size: tuple[int, int] = (0, 0)
    linked_frame: int | None = None


def unpack(fmt: str, data: bytes, offset: int = 0):
    try:
        return struct.unpack_from("<" + fmt, data, offset)
    except struct.error as exc:
        raise AseError("Truncated Aseprite data") from exc


def read_string(data: bytes, offset: int) -> tuple[str, int]:
    length, = unpack("H", data, offset)
    end = offset + 2 + length
    if end > len(data):
        raise AseError("Truncated Aseprite string")
    return data[offset + 2:end].decode("utf-8"), end


def read_ase(path: Path) -> dict:
    data = path.read_bytes()
    file_size, magic, frame_count, width, height, depth = unpack("I5H", data)
    if magic != 0xA5E0 or file_size != len(data) or len(data) < 128:
        raise AseError(f"Invalid ASE header: {path}")
    if depth not in (8, 16, 32) or not width or not height or not frame_count:
        raise AseError("Unsupported depth or empty sprite")
    flags, speed = unpack("IH", data, 14)
    transparent = data[28]
    layers: list[Layer] = []
    frames: list[dict] = []
    palette = [(0, 0, 0, 255)] * 256
    modern_palette = False
    offset = 128
    for frame_index in range(frame_count):
        frame_size, frame_magic, old_count, duration, _, new_count = unpack("I4HI", data, offset)
        if frame_magic != 0xF1FA or frame_size < 16 or offset + frame_size > len(data):
            raise AseError(f"Invalid frame {frame_index}")
        cels: dict[int, Cel] = {}
        chunk_offset = offset + 16
        for _ in range(new_count or old_count):
            chunk_size, kind = unpack("IH", data, chunk_offset)
            if chunk_size < 6 or chunk_offset + chunk_size > offset + frame_size:
                raise AseError("Chunk exceeds frame bounds")
            chunk = data[chunk_offset + 6:chunk_offset + chunk_size]
            if kind == 0x2004:
                layer_flags, layer_kind, level, _, _, blend, opacity = unpack("6HB", chunk)
                name, _ = read_string(chunk, 16)
                layers.append(Layer(name, layer_flags, layer_kind, level, blend, opacity if flags & 1 else 255))
            elif kind == 0x2005:
                layer, x, y, opacity, cel_kind, z = unpack("HhhBHh", chunk)
                cel = Cel(layer, x, y, opacity, z)
                if cel_kind in (0, 2):
                    cel.size = unpack("HH", chunk, 16)
                    cel.pixels = chunk[20:] if cel_kind == 0 else zlib.decompress(chunk[20:])
                    expected = cel.size[0] * cel.size[1] * (depth // 8)
                    if len(cel.pixels) != expected:
                        raise AseError(f"Cel size mismatch: expected {expected}, got {len(cel.pixels)}")
                elif cel_kind == 1:
                    cel.linked_frame, = unpack("H", chunk, 16)
                else:
                    raise AseError(f"Unsupported tilemap cel in {path.name}")
                cels[layer] = cel
            elif kind == 0x2019:
                modern_palette = True
                total, first, last = unpack("III", chunk)
                if total > 65536 or last >= total or first > last:
                    raise AseError("Invalid palette range")
                if len(palette) < total:
                    palette.extend([(0, 0, 0, 255)] * (total - len(palette)))
                cursor = 20
                for index in range(first, last + 1):
                    entry_flags, r, g, b, a = unpack("H4B", chunk, cursor)
                    cursor += 6
                    palette[index] = (r, g, b, a)
                    if entry_flags & 1:
                        _, cursor = read_string(chunk, cursor)
            elif kind in (0x0004, 0x0011) and not modern_palette:
                packets, = unpack("H", chunk)
                cursor, index = 2, 0
                for _ in range(packets):
                    skip, count = unpack("BB", chunk, cursor)
                    cursor += 2
                    index += skip
                    for _ in range(count or 256):
                        rgb = unpack("3B", chunk, cursor)
                        cursor += 3
                        if kind == 0x0011:
                            rgb = tuple(round(value * 255 / 63) for value in rgb)
                        if index >= len(palette):
                            palette.append((*rgb, 255))
                        else:
                            palette[index] = (*rgb, 255)
                        index += 1
            chunk_offset += chunk_size
        frames.append({"cels": cels, "duration": duration or speed, "palette": palette.copy()})
        offset += frame_size
    return {"width": width, "height": height, "depth": depth, "transparent": transparent,
            "flags": flags, "layers": layers, "frames": frames}


def render_frames(sprite: dict) -> list[Image.Image]:
    layers, frames = sprite["layers"], sprite["frames"]
    visible: list[bool] = []
    ancestors: list[Layer] = []
    for layer in layers:
        while len(ancestors) > layer.level:
            ancestors.pop()
        parent_visible = all(parent.flags & 1 for parent in ancestors)
        visible.append(bool(layer.flags & 1) and parent_visible and not layer.flags & 64)
        if layer.kind == 1:
            if sprite["flags"] & 2 and (layer.opacity != 255 or layer.blend != 0):
                raise AseError("Group blend/opacity needs Aseprite's renderer")
            ancestors.append(layer)

    def resolve(frame_index: int, layer_index: int, seen: set | None = None) -> Cel:
        seen = set() if seen is None else seen
        key = (frame_index, layer_index)
        if key in seen or frame_index < 0 or frame_index >= len(frames):
            raise AseError("Invalid or cyclic linked cel")
        seen.add(key)
        cel = frames[frame_index]["cels"].get(layer_index)
        if cel is None:
            raise AseError("Linked cel references a missing image")
        return cel if cel.linked_frame is None else resolve(cel.linked_frame, layer_index, seen)

    images = []
    for frame_index, frame in enumerate(frames):
        canvas = Image.new("RGBA", (sprite["width"], sprite["height"]))
        painted = False
        for cel in sorted(frame["cels"].values(), key=lambda c: (c.layer + c.z, c.z)):
            if cel.layer >= len(layers):
                raise AseError("Cel references a missing layer")
            layer = layers[cel.layer]
            if not visible[cel.layer]:
                continue
            if layer.kind != 0 or layer.blend != 0:
                raise AseError(f"Unsupported visible layer type/blend: {layer.name}")
            source = resolve(frame_index, cel.layer)
            mode = {32: "RGBA", 16: "LA", 8: "P"}[sprite["depth"]]
            image = Image.frombytes(mode, source.size, source.pixels)
            if mode == "P":
                colors = frame["palette"].copy()
                if not layer.flags & 8:
                    r, g, b, _ = colors[sprite["transparent"]]
                    colors[sprite["transparent"]] = (r, g, b, 0)
                image = Image.frombytes("RGBA", source.size, bytes(channel for index in source.pixels for channel in colors[index]))
            elif mode == "LA":
                image = image.convert("RGBA")
            opacity = (cel.opacity * layer.opacity + 127) // 255
            if opacity != 255:
                image.putalpha(image.getchannel("A").point(lambda alpha: (alpha * opacity + 127) // 255))
            if not painted:
                # No mask: preserve all source bytes, including RGB under transparent pixels.
                canvas.paste(image, (cel.x, cel.y))
            else:
                canvas.alpha_composite(image, (cel.x, cel.y))
            painted = True
        images.append(canvas)
    return images


def export(path: Path, output_dir: Path | None = None) -> dict:
    sprite = read_ase(path)
    images = render_frames(sprite)
    width, height = sprite["width"], sprite["height"]
    sheet = Image.new("RGBA", (width * len(images), height))
    for index, image in enumerate(images):
        sheet.paste(image, (index * width, 0))
    output = (output_dir or path.parent) / (path.stem + ".png")
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, optimize=False)
    with Image.open(output) as verified:
        assert verified.convert("RGBA").tobytes() == sheet.tobytes(), "PNG changed sprite pixels"
    metadata = {"source": path.as_posix(), "sheet": output.as_posix(),
                "frame_width": width, "frame_height": height, "frames": len(images),
                "layout": "horizontal", "durations_ms": [frame["duration"] for frame in sprite["frames"]],
                "color_depth": sprite["depth"], "layers": [layer.name for layer in sprite["layers"]]}
    print(f"{path.name} -> {output.name}: {len(images)} frames of {width}x{height}, original RGBA pixels preserved")
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("sources", nargs="*", default=["Assets/npc/*.ase"])
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()
    paths = sorted({Path(path) for pattern in args.sources for path in glob.glob(pattern)})
    if not paths:
        parser.error("No source .ase files matched")
    entries = [export(path, args.output_dir) for path in paths]
    if args.manifest:
        args.manifest.parent.mkdir(parents=True, exist_ok=True)
        args.manifest.write_text(json.dumps(entries, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
