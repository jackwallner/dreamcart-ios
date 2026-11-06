#!/usr/bin/env python3
"""Replace captures and CoreText headers in finished screenshot frames."""
from __future__ import annotations

import argparse
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

from common import config, destinations, erase_header, header_job, headline, paste_screen, raw_path, read_json, source


def extra_text_job(frame: dict, extra: dict, headers: dict, locale: str) -> dict:
    key = f"{frame['file']}#{extra['key']}"
    if key not in headers:
        raise ValueError(f"missing extra text {key}")
    return {
        'text': headers[key],
        'locale': locale,
        'font': extra['font'],
        'color': extra['color'],
        'box': extra['box'][2:],
        'maxSize': extra.get('max_size', 72),
        'minSize': extra.get('min_size', 12),
        'align': extra.get('align', 'center'),
    }


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--config', type=Path, required=True)
    p.add_argument('--raw-root', type=Path, required=True)
    p.add_argument('--headers', type=Path, required=True)
    p.add_argument('--locale', required=True)
    p.add_argument('--out', type=Path, required=True, help='output root; writes ROOT/LOCALE/SET/file.png')
    p.add_argument('--set', dest='set_key')
    args = p.parse_args()
    data, headers = config(args.config), read_json(args.headers)[args.locale]
    sets = data['sets'] if args.set_key is None else {args.set_key: data['sets'][args.set_key]}
    plans = []
    for key, group in sets.items():
        frames = group['frames']
        jobs = [header_job(f, headers[f['file']], args.locale) for f in frames]
        results = headline(jobs)
        size = min(r['size'] for r in results)
        cause = frames[min(range(len(results)), key=lambda i: results[i]['size'])]
        for f, result in zip(frames, results):
            if not result['fits'] or size < f['min_size']:
                raise ValueError(f"{key}/{cause['file']}: size {size:g} below required minimum; text={headers[cause['file']]!r}")
            for target in destinations(f):
                if not raw_path(args.raw_root, args.locale, key, target['raw']).is_file():
                    raise ValueError(f"missing raw {key}/{target['raw']}")
        extras = []
        for frame in frames:
            for extra in frame.get('extra_text', []):
                extras.append((frame, extra, extra_text_job(frame, extra, headers, args.locale)))
        extra_results = headline([item[2] for item in extras]) if extras else []
        for (frame, extra, _), result in zip(extras, extra_results):
            if not result['fits'] or result['size'] < extra.get('min_size', 12):
                text = headers[f"{frame['file']}#{extra['key']}"]
                raise ValueError(f"{key}/{frame['file']}#{extra['key']}: text does not fit; text={text!r}")
        plans.append((key, group, jobs, size, extras))
    with tempfile.TemporaryDirectory() as tmp:
        for key, group, jobs, size, extras in plans:
            frames = group['frames']
            for i, job in enumerate(jobs):
                job.update(size=size, out=str(Path(tmp) / f'{i}.png'))
            extra_jobs = []
            for i, (_, _, job) in enumerate(extras):
                job['out'] = str(Path(tmp) / f'extra-{i}.png')
                extra_jobs.append(job)
            rendered = headline(jobs)
            if not all(r['fits'] for r in rendered):
                raise ValueError(f'{key}: uniform header size does not fit')
            extra_rendered = headline(extra_jobs) if extra_jobs else []
            if not all(r['fits'] for r in extra_rendered):
                raise ValueError(f'{key}: extra text does not fit')
            output = args.out / args.locale / key
            output.mkdir(parents=True, exist_ok=True)
            for frame, job in zip(frames, jobs):
                with Image.open(source(data, frame['base'])) as im:
                    canvas = im.convert('RGB')
                if canvas.size != tuple(group['canvas']):
                    raise ValueError(f"{frame['file']}: base size differs from canvas")
                plate = None
                if frame.get('plate'):
                    with Image.open(source(data, frame['plate'])) as im:
                        plate = im.convert('RGB')
                erase_header(canvas, frame['header_box'], plate)
                frame_extras = [(extra, job) for owner, extra, job in extras if owner['file'] == frame['file']]
                for extra, _ in frame_extras:
                    extra_plate = plate
                    if extra.get('plate'):
                        with Image.open(source(data, extra['plate'])) as im:
                            extra_plate = im.convert('RGB')
                    erase_header(canvas, extra['box'], extra_plate)
                for target in destinations(frame):
                    with Image.open(raw_path(args.raw_root, args.locale, key, target['raw'])) as raw:
                        paste_screen(canvas, raw, target['rect'], target.get('radius', 0))
                with Image.open(job['out']) as overlay:
                    canvas.paste(overlay, tuple(frame['header_box'][:2]), overlay)
                for extra, extra_job in frame_extras:
                    x, y, width, height = extra['box']
                    if 'fill_color' in extra:
                        ImageDraw.Draw(canvas).rounded_rectangle(
                            (x, y, x + width - 1, y + height - 1),
                            radius=min(width, height) // 2,
                            fill=tuple(extra['fill_color']),
                        )
                    with Image.open(extra_job['out']) as overlay:
                        canvas.paste(overlay, (x, y), overlay)
                canvas.save(output / frame['file'], format='PNG', optimize=True)
            print(f'{args.locale}/{key}: {len(frames)} frames size={size:g}')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        print(f'reskin: {error}', file=sys.stderr)
        sys.exit(1)
