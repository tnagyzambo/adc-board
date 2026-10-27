"""Generate the ngspice board deck for the GP channels from the KiCad netlist.

python3 gen_deck.py [netlist.net]

With no argument, exports the netlist from ../../e003-adc-board.kicad_sch
with kicad-cli. Writes:
  board.cir   both GP channels and the channel supplies, flat, one line per
              part; the converters' switch lines come from .params that
              sweep.py sets (ch1_g0 .. ch2_refbuf)
  board.json  the node of every net, and every part's type, pins and value,
              for limits.py

Only the GP channel sheets and the power sheet are taken. The FPGA, the
interconnect buffer and the 3.3 V limit are left out: sweep.py drives the
stack's 5 V, 24 V and 3.3 V and the channel-supply enable directly.
"""
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
KICAD_CLI = '/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli'
SHEETS = ('/gp-ch1/', '/gp-ch2/', '/power/')

# Library part -> subcircuit in parts.lib. Its ports are the pins in order.
SUBCKT = {
    'OPA2189IDGKR': 'OPA2189',
    'TMUX6212RUMR': 'TMUX6212',
    'ADS127L14IRSHR': 'ADS127L14',
    'REF5020IDGKR': 'REF5020',
    'LT3092EDD#PBF': 'LT3092',
    'TLP3475S': 'TLP3475S',
    'DMTH6016LFDFWQ-7': 'DMTH6016LFDFWQ',
    'BSS138W-7-F': 'BSS138W',
    'DMN6075S-7': 'DMN6075S',
    'MMSZ5246BS-7-F': 'MMSZ5246BS',
    'SD36C-01FTG': 'SD36C',
    'TVS2700DRVR': 'TVS2700',
    'TVS0500DRVR': 'TVS0500',
    'MF-NSMF020X-2': 'MFNSMF020X',
    'TPS25200DRVR': 'TPS25200',
    'LM2776DBVR': 'LM2776',
    'TPS7A3901DSCR': 'TPS7A3901',
    'TPS70918DRVR': 'TPS70918',
    'TLV431BIDBZR': 'TLV431',
    'MMST3906-7-F': 'MMST3906',
    'BSS84W-7-F': 'BSS84W',
    'BAT54WS-7-F': 'BAT54WS',
}
PINS = {'ADS127L14': 57, 'TMUX6212': 16, 'TPS7A3901': 11, 'LT3092': 9, 'OPA2189': 8, 'REF5020': 8,
        'TVS2700': 7, 'TVS0500': 7, 'TPS25200': 7, 'TPS70918': 7, 'LM2776': 6, 'TLP3475S': 4,
        'DMTH6016LFDFWQ': 3, 'BSS138W': 3, 'DMN6075S': 3, 'MMST3906': 3, 'TLV431': 3,
        'MMSZ5246BS': 2, 'SD36C': 2, 'MFNSMF020X': 2, 'BSS84W': 3, 'BAT54WS': 2}
# Parts with no DC model: the 3.3 V limit, which sweep.py replaces with a
# source, and test points.
SKIP = ('TPS2553DRVR', 'PCB-TEST-POINT')
RES_PREFIX = ('CRCW', 'TNPU', 'TNPW', 'PHP')
CAP_PREFIX = ('GRM', 'GCM', 'GCJ', 'GRJ', 'GXT')

TOK = re.compile(r'\(|\)|"(?:[^"\\]|\\.)*"|[^\s()"]+')


def parse(text):
    stack = [[]]
    for m in TOK.finditer(text):
        t = m.group(0)
        if t == '(':
            stack.append([])
        elif t == ')':
            x = stack.pop()
            stack[-1].append(x)
        elif t.startswith('"'):
            stack[-1].append(t[1:-1].replace('\\"', '"'))
        else:
            stack[-1].append(t)
    return stack[0][0]


def find(node, name):
    return [c for c in node if isinstance(c, list) and c and c[0] == name]


def val(node, name):
    r = find(node, name)
    return r[0][1] if r and len(r[0]) > 1 else None


def read_netlist(path):
    root = parse(open(path, encoding='utf-8').read())
    comps = {}
    for c in find(find(root, 'components')[0], 'comp'):
        ls = find(c, 'libsource')
        comps[val(c, 'ref')] = dict(value=val(c, 'value'), part=val(ls[0], 'part') if ls else '',
                                    sheet=val(find(c, 'sheetpath')[0], 'names'))
    nets = {}
    for n in find(find(root, 'nets')[0], 'net'):
        nets[val(n, 'name')] = [(val(nd, 'ref'), val(nd, 'pin')) for nd in find(n, 'node')]
    return comps, nets


def node_name(net, used):
    """A unique, lower-case ngspice node name for a KiCad net."""
    if net == 'GND':
        return '0'
    s = re.sub(r'^/gp-(ch\d)/(\w+/)?', r'\1_', net).lstrip('/').replace('{slash}', '_')
    # A trailing or leading sign is a polarity (EXC-, -5V_CH, U2A-+); any
    # other dash is a separator.
    s = s.replace('+', 'p')
    s = re.sub(r'^-|-(?=[)_.]|$)', 'n', s)
    s = re.sub(r'[^A-Za-z0-9]+', '_', s).strip('_').lower()
    if s[0].isdigit():
        s = 'n_' + s
    base, k = s, 1
    while s in used:
        k += 1
        s = '%s_%d' % (base, k)
    used.add(s)
    return s


def res_value(v):
    m = re.fullmatch(r'([\d.]+)\s*([RkKM]?)([\d]*)', v.strip())
    if not m:
        raise ValueError('resistor value %r' % v)
    num, mult, frac = m.groups()
    x = float(num + ('.' + frac if frac else ''))
    return x * {'': 1, 'R': 1, 'k': 1e3, 'K': 1e3, 'M': 1e6}[mult]


def channel_of(sheet):
    m = re.match(r'/gp-ch(\d)/', sheet)
    return 'ch' + m.group(1) if m else None


def build(netlist):
    comps, nets = read_netlist(netlist)
    used = set()
    node = {}
    for n in sorted(nets):
        node[n] = node_name(n, used)
    pins = {}
    for n, nodes in nets.items():
        for ref, pin in nodes:
            pins.setdefault(ref, {})[pin] = n

    lines, parts, unmodelled = [], {}, []
    key = lambda r: (re.match(r'\D+', r).group(0), int(re.search(r'\d+', r).group(0)))
    for ref in sorted(comps, key=key):
        c = comps[ref]
        if not c['sheet'].startswith(SHEETS):
            continue
        part = c['part']
        p = pins.get(ref, {})
        info = dict(part=part, value=c['value'], sheet=c['sheet'], channel=channel_of(c['sheet']),
                    pins={k: node[v] for k, v in p.items()}, nets=p)
        if part.startswith(RES_PREFIX):
            r = res_value(c['value'])
            info.update(kind='R', ohms=r)
            if r == 0:
                lines.append('V%s %s %s 0' % (ref, node[p['1']], node[p['2']]))
            else:
                lines.append('R%s %s %s %g' % (ref, node[p['1']], node[p['2']], r))
        elif part.startswith(CAP_PREFIX):
            info.update(kind='C')          # open at DC; limits.py checks its voltage
        elif part in SUBCKT:
            sub = SUBCKT[part]
            ports = []
            for k in range(1, PINS[sub] + 1):
                n = p.get(str(k))
                ports.append(node[n] if n else 'nc_%s_%d' % (ref.lower(), k))
            extra = ''
            if sub == 'ADS127L14':
                ch = info['channel']
                extra = ' g0={%s_g0} g1={%s_g1} g2={%s_g2} g3={%s_g3} g4={%s_g4} g5={%s_g5} g6={%s_g6} ' \
                        'refbuf={%s_refbuf}' % ((ch,) * 8)
            lines.append('X%s %s %s%s' % (ref, ' '.join(ports), sub, extra))
            info.update(kind='X', subckt=sub)
        elif part in SKIP:
            info.update(kind='skip')
        else:
            unmodelled.append(ref)
            info.update(kind='skip')
        parts[ref] = info
    if unmodelled:
        raise SystemExit('no model for %s' % ', '.join('%s (%s)' % (r, comps[r]['part']) for r in unmodelled))
    return lines, parts, node


def main():
    if len(sys.argv) > 1:
        netlist = sys.argv[1]
    else:
        netlist = os.path.join(HERE, 'e003-adc-board.net')
        subprocess.run([KICAD_CLI, 'sch', 'export', 'netlist', '--format', 'kicadsexpr', '-o', netlist,
                        os.path.join(PROJECT, 'e003-adc-board.kicad_sch')],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    lines, parts, node = build(netlist)
    with open(os.path.join(HERE, 'board.cir'), 'w') as f:
        f.write('* e003 GP channels and channel supplies, generated by gen_deck.py from\n')
        f.write('* %s. Do not edit; rerun gen_deck.py.\n' % os.path.basename(netlist))
        f.write('\n'.join(lines) + '\n')
    json.dump(dict(parts=parts, node=node), open(os.path.join(HERE, 'board.json'), 'w'), indent=1)
    n = sum(1 for p in parts.values() if p['kind'] in ('R', 'X'))
    print('board.cir: %d elements from %d parts, %d nets' % (n, len(parts), len(node)))


if __name__ == '__main__':
    main()
