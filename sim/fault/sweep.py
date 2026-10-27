"""Run the DC fault sweep of GP channel 1 and flag every limit exceeded.

python3 gen_deck.py          # after any schematic change
python3 sweep.py [-j N] [--quick] [--only POWER]

--quick runs a subset with the channel running; --only reruns one power
state (on, no24, ch_off, stack_off) and merges it into results.json.

For every power state, configuration, shield setting and connected sensor,
a source on each of channel 1's five contacts ramps from 0 to +28 V and,
separately, to -28 V, once limited to 5 A, as a low-impedance supply such
as a valve driver behind its fuse would be, and once limited to 30 mA, as
another channel's sensor supply would be. Every pair of contacts is also
shorted with the channel running. Each case is checked against limits.py.

Writes results.json, every violation of every case; report.py summarises it.
"""
import itertools
import json
import multiprocessing as mp
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import limits  # noqa: E402
import scenarios as sc  # noqa: E402

SOURCES = ('5A', '30mA')
VMAX = 28.0
TIMEOUT = 45      # seconds per attempt


def cases(quick=False):
    """(power, config, shield, sensor, fault, vmax) for every case."""
    pairs = []
    for sensor, configs in sc.SENSORS.items():
        for config in (sc.CONFIGS if configs is None else ('off',) + configs):
            pairs.append((sensor, config))
    out = []
    for power in ('on', 'no24', 'ch_off', 'stack_off'):
        if power in ('on', 'no24'):
            ps = [(s, c, sh) for s, c in pairs for sh in ((0, 1) if power == 'on' else (0,))]
        else:
            ps = [(s, 'off', 0) for s in sc.SENSORS]
        for sensor, config, shield in ps:
            out.append((power, config, shield, sensor, None, 0.0))
            for contact, src, sign in itertools.product(sc.CONTACTS, SOURCES, (1, -1)):
                out.append((power, config, shield, sensor, ('V', contact, src), sign * VMAX))
    for sensor, config in pairs:
        for a, b in itertools.combinations(sc.CONTACTS, 2):
            out.append(('on', config, 0, sensor, ('short', a, b), 0.0))
    if quick:
        out = [c for c in out if c[0] == 'on' and c[2] == 0 and c[3] in ('none', 'lc350', 'txv')]
    return out


_ng = _board = None


def _init():
    global _ng, _board
    from ngspice import NgSpice
    _ng = NgSpice()
    _board = json.load(open(os.path.join(HERE, 'board.json')))


def run_case(case):
    power, config, shield, sensor, fault, vmax = case
    t0 = time.time()
    want = sc.t_end(fault, vmax or 1.0)
    for attempt in range(len(sc.RETRIES)):
        v = _ng.run(sc.deck(power, config, shield, sensor, fault, vmax=vmax or 1.0, attempt=attempt), timeout=TIMEOUT)
        t = v.get('time', [])
        status = 'ok' if t and t[-1] >= want * 0.999 else ('timeout' if _ng.timed_out else 'failed')
        if status == 'ok':
            break
    sign = 1 if vmax >= 0 else -1
    volts = [0.0 if x <= sc.T_ON else sign * (x - sc.T_ON) * sc.RATE for x in t]
    if not vmax:
        volts = [0.0] * len(t)
    # Keep only the settled points: from T_ON on.
    keep = [i for i, x in enumerate(t) if x >= sc.T_ON - 1e-9]
    if not vmax:
        keep = keep[-1:]      # a short or no fault: the final state
    vv = {k: [x[i] for i in keep] for k, x in v.items()}
    vs = [volts[i] for i in keep]
    found = limits.check(vv, limits.all_limits(_board, power), vs) if keep else {}
    reached = vs[-1] if vs else None
    viol = [dict(ref=r, what=w, value=d['value'], at=d['at'], first=d['first'], unit=d['limit'].unit,
                 lo=d['limit'].lo, hi=d['limit'].hi, source=d['limit'].source, kind=d['limit'].kind)
            for (r, w), d in found.items()]
    fault_i = None
    if vv.get('vf#branch') and fault and fault[0] == 'V':
        fault_i = max(vv['vf#branch'], key=abs)
        fault_i = -fault_i      # current out of the source into the contact
    return dict(case=dict(power=power, config=config, shield=shield, sensor=sensor,
                          fault=list(fault) if fault else None, vmax=vmax),
                status=status, attempt=attempt, reached=reached, fault_current=fault_i, violations=viol,
                errors=[l for l in _ng.errors()][:3], seconds=round(time.time() - t0, 2))


def main():
    jobs = 10
    if '-j' in sys.argv:
        jobs = int(sys.argv[sys.argv.index('-j') + 1])
    todo = cases(quick='--quick' in sys.argv)
    only = sys.argv[sys.argv.index('--only') + 1] if '--only' in sys.argv else None
    if only:
        todo = [c for c in todo if c[0] == only]
    print('%d cases on %d processes' % (len(todo), jobs), flush=True)
    t0 = time.time()
    results = []
    with mp.get_context('spawn').Pool(jobs, initializer=_init) as pool:
        for k, r in enumerate(pool.imap_unordered(run_case, todo, chunksize=2)):
            results.append(r)
            if r['status'] != 'ok' or r['seconds'] > 30:
                print('  %s %.0f s: %s' % (r['status'], r['seconds'], r['case']), flush=True)
            if (k + 1) % 25 == 0:
                print('  %d/%d, %.0f s' % (k + 1, len(todo), time.time() - t0), flush=True)
    path = os.path.join(HERE, 'results.json')
    if only and os.path.exists(path):
        # Replace that power state's cases and keep the rest.
        results += [r for r in json.load(open(path)) if r['case']['power'] != only]
    json.dump(results, open(path, 'w'), indent=1)
    failed = sum(r['status'] != 'ok' for r in results)
    print('done in %.0f s; %d cases did not finish' % (time.time() - t0, failed))


if __name__ == '__main__':
    main()
