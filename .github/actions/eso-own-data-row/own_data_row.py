import argparse
import re
import sys


def field(text, name):
    m = re.search(r'^##\s*' + re.escape(name) + r':[ \t]*(.*?)[ \t]*$', text, re.M)
    return m.group(1) if m else ''


def upsert(path, folder, build_row):
    lines = open(path, encoding='utf-8').read().split('\n')
    start = next(i for i, l in enumerate(lines) if '[==[' in l) + 1
    end = next(i for i in range(start, len(lines)) if lines[i].startswith(']==]'))
    rows = lines[start:end]
    idx = next((i for i, r in enumerate(rows) if r.split('\t', 1)[0] == folder), None)
    old = rows[idx].split('\t') if idx is not None else []
    new = build_row(old)
    if idx is not None:
        if rows[idx] == new:
            return False
        rows[idx] = new
    else:
        rows.append(new)
        rows.sort(key=lambda r: r.split('\t', 1)[0].lower())
    lines[start:end] = rows
    open(path, 'w', encoding='utf-8').write('\n'.join(lines))
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--manifest', required=True)
    ap.add_argument('--folder', required=True)
    ap.add_argument('--title', required=True)
    ap.add_argument('--author', required=True)
    ap.add_argument('--pc-file', default='')
    ap.add_argument('--console-file', default='')
    args = ap.parse_args()

    text = open(args.manifest, encoding='utf-8').read()
    addon = field(text, 'AddOnVersion')
    version = field(text, 'Version')
    api = ' '.join(t for t in field(text, 'APIVersion').split() if t.isdigit())
    if not addon or not version:
        print('::error::manifest is missing AddOnVersion or Version')
        sys.exit(1)

    changed = []
    if args.pc_file:
        def pc_row(old):
            esoui = old[3] if len(old) > 3 else ''
            return '\t'.join([args.folder, addon, version, esoui, api])
        if upsert(args.pc_file, args.folder, pc_row):
            changed.append(args.pc_file)
    if args.console_file:
        def con_row(old):
            title = old[4] if len(old) > 4 and old[4] else args.title
            author = old[5] if len(old) > 5 and old[5] else args.author
            addon_id = old[6] if len(old) > 6 else ''
            return '\t'.join([args.folder, addon, version, api, title, author, addon_id])
        if upsert(args.console_file, args.folder, con_row):
            changed.append(args.console_file)
    print('Updated: ' + (', '.join(changed) or 'nothing (already current)'))


if __name__ == '__main__':
    main()
