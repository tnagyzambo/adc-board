"""Absolute-maximum limits for every part in board.cir, and the check that
compares a sweep's results against them.

Each limit names the quantity, its bounds, the datasheet it comes from and
its kind:
  damage    an absolute maximum rating, or a dissipation above the rating
  trip      a protection part acting (fuse or eFuse limit): no damage
  function  a rail driven out of regulation or back-powered: no damage, but
            the board misbehaves while it lasts

Voltages are pin to pin; currents are positive into the pin named. A pin
that is diode-clamped and rated in current (OPA2189, TMUX6212, ADS127L14
analog pins) is checked on its clamp current only, as those datasheets
allow.
"""
import re

# Thin-film and thick-film resistor ratings at 70 C, by series and size.
RES_W = {('CRCW', '0402'): 0.063, ('CRCW', '0805'): 0.125, ('CRCW', '1206'): 0.25,
         ('TNPW', '0402'): 0.063, ('TNPU', '0402'): 0.063, ('TNPU', '0805'): 0.125,
         ('TNPU', '1206'): 0.25, ('PHP0', '1206'): 1.0}
# Murata rated-voltage codes.
CAP_V = {'0J': 6.3, '1A': 10, '1C': 16, '1E': 25, '1H': 50, '2A': 100, '2E': 250}

S_LABEL = {'U54': 'S1', 'U56': 'S2', 'Q4': 'S3', 'Q3': 'S4', 'Q5': 'S5', 'Q1': 'S8', 'U1': 'S9', 'U58': 'S11'}


class Limit:
    def __init__(self, what, quantity, lo, hi, unit, source, kind='damage'):
        self.what, self.quantity, self.lo, self.hi = what, quantity, lo, hi
        self.unit, self.source, self.kind = unit, source, kind


def _limits_for(ref, p):
    """The limits of one part, each with a function of the result vectors."""
    pins = p['pins']

    def V(pin):
        n = pins.get(str(pin))
        return (lambda v: [0.0] * len(v['time'])) if n in (None, '0') else (lambda v, n=n: v[n])

    def Vd(a, b):
        fa, fb = V(a), V(b)
        return lambda v: [x - y for x, y in zip(fa(v), fb(v))]

    def I(name):
        key = 'v.x%s.%s#branch' % (ref.lower(), name)
        return lambda v: v[key]

    def prod(f, g):
        return lambda v: [x * y for x, y in zip(f(v), g(v))]

    sub = p.get('subckt') or p['kind']
    L = []
    if p['kind'] == 'R':
        series, size = p['part'][:4], re.search(r'(0402|0805|1206)', p['part']).group(1)
        w = RES_W[(series, size)]
        d = Vd(1, 2)
        L.append(Limit('dissipation', lambda v: [x * x / p['ohms'] for x in d(v)], None, w, 'W',
                       '%s %s rating at 70 C' % (series, size)))
    elif p['kind'] == 'C':
        code = p['part'][8:10]
        rated = CAP_V.get(code)
        if rated:
            d = Vd(1, 2)
            L.append(Limit('voltage', d, -rated, rated, 'V', 'Murata rated voltage code %s' % code))
    elif sub == 'OPA2189':
        for amp in ('xa', 'xb'):
            for pin in ('vcp', 'vcn'):
                L.append(Limit('input clamp current, %s %s' % ({'xa': 'A', 'xb': 'B'}[amp], {'vcp': '+IN', 'vcn': '-IN'}[pin]),
                               I('%s.%s' % (amp, pin)), -10e-3, 10e-3, 'A', 'OPA2189 7.1 abs max'))
        L.append(Limit('supply V+ to V-', Vd(8, 4), None, 40, 'V', 'OPA2189 7.1 abs max'))
    elif sub == 'TMUX6212':
        for k in '1234':
            L.append(Limit('S%s clamp current' % k, I('vks' + k), -30e-3, 30e-3, 'A', 'TMUX6212 6.1 IIK'))
            L.append(Limit('D%s clamp current' % k, I('vkd' + k), -30e-3, 30e-3, 'A', 'TMUX6212 6.1 IIK'))
            L.append(Limit('switch %s current' % k, I('vw' + k), -0.132, 0.132, 'A',
                           'TMUX6212 6.1/6.5: IDC at +/-5 V, 85 C, + 10 %'))
        L.append(Limit('VDD to VSS', Vd(11, 2), None, 38, 'V', 'TMUX6212 6.1 abs max'))
        L.append(Limit('VDD', Vd(11, 3), -0.5, 38, 'V', 'TMUX6212 6.1 abs max'))
        L.append(Limit('VSS', Vd(2, 3), -38, 0.5, 'V', 'TMUX6212 6.1 abs max'))
        for sel in (6, 7, 14, 15):
            L.append(Limit('SEL pin %d' % sel, Vd(sel, 3), -0.5, 38, 'V', 'TMUX6212 6.1 abs max'))
    elif sub == 'ADS127L14':
        for pin, name in ((37, 'AINP3'), (38, 'AINN3'), (39, 'AINP2'), (40, 'AINN2'), (41, 'AINP1'),
                          (42, 'AINN1'), (43, 'AINP0'), (44, 'AINN0'), (47, 'REFN'), (49, 'REFP')):
            L.append(Limit('%s clamp current' % name, I('vk%d' % pin), -10e-3, 10e-3, 'A',
                           'ADS127L14 5.1 abs max, note 2'))
        L.append(Limit('AVDD1 to AVSS', Vd(23, 22), -0.3, 6.5, 'V', 'ADS127L14 5.1 abs max'))
        L.append(Limit('AVDD2 to AVSS', Vd(25, 22), -0.3, 6.5, 'V', 'ADS127L14 5.1 abs max'))
        L.append(Limit('AVSS to DGND', Vd(22, 17), -3, 0.3, 'V', 'ADS127L14 5.1 abs max'))
        L.append(Limit('IOVDD to DGND', Vd(18, 17), -0.3, 2.2, 'V', 'ADS127L14 5.1 abs max'))
    elif sub == 'REF5020':
        L.append(Limit('VIN', Vd(2, 4), -0.3, 18, 'V', 'REF5020 6.1 abs max'))
        L.append(Limit('VOUT', Vd(6, 4), -0.3, 5.5, 'V', 'REF5020 6.1 abs max'))
    elif sub == 'LT3092':
        L.append(Limit('IN to OUT', Vd(7, 1), -40, 40, 'V', 'LT3092 abs max'))
        L.append(Limit('IN to SET', Vd(7, 4), -40, 40, 'V', 'LT3092 abs max'))
        L.append(Limit('SET to OUT', Vd(4, 1), -10, 10, 'V', 'LT3092 abs max'))
        L.append(Limit('SET clamp current', I('vsc'), -15e-3, 15e-3, 'A', 'LT3092 abs max'))
    elif sub == 'TLP3475S':
        L.append(Limit('output voltage', Vd(3, 4), -60, 60, 'V', 'TLP3475S VOFF 60 V (doc)'))
        L.append(Limit('output current', I('vsw'), -0.4, 0.4, 'A', 'TLP3475S ION 0.4 A (unverified, no local datasheet)'))
        L.append(Limit('LED current', I('vled'), None, 30e-3, 'A', 'TLP3475S IF 30 mA (unverified, no local datasheet)'))
        L.append(Limit('LED reverse voltage', Vd(2, 1), None, 5, 'V', 'TLP3475S VR 5 V (unverified, no local datasheet)'))
    elif sub in ('BSS138W', 'DMN6075S', 'DMTH6016LFDFWQ'):
        vds, idmax, isd, pd = {'BSS138W': (50, 0.2, 0.2, 0.2), 'DMN6075S': (60, 2.0, 2.0, 0.8),
                               'DMTH6016LFDFWQ': (60, 9.4, 3.0, 1.06)}[sub]
        L.append(Limit('drain to source', Vd(3, 2), None, vds, 'V', '%s VDSS' % sub))
        L.append(Limit('gate to source', Vd(1, 2), -20, 20, 'V', '%s VGSS' % sub))
        L.append(Limit('drain current', I('vd'), None, idmax, 'A', '%s ID' % sub))
        L.append(Limit('body diode current', I('vb'), None, isd, 'A',
                       '%s IS' % sub if sub != 'BSS138W' else 'BSS138W ID (no IS rating; as the doc assumes)'))
        L.append(Limit('dissipation', prod(Vd(3, 2), I('vd')), -pd, pd, 'W', '%s PD' % sub))
    elif sub == 'BSS84W':
        L.append(Limit('source to drain', Vd(2, 3), None, 50, 'V', 'BSS84W VDSS -50 V'))
        L.append(Limit('gate to source', Vd(1, 2), -20, 20, 'V', 'BSS84W VGSS'))
        L.append(Limit('drain current', I('vd'), -0.13, None, 'A', 'BSS84W ID -130 mA'))
        L.append(Limit('body diode current', I('vb'), None, 0.13, 'A', 'BSS84W ID (no IS rating)'))
        L.append(Limit('dissipation', prod(Vd(3, 2), I('vd')), -0.2, 0.2, 'W', 'BSS84W PD'))
    elif sub == 'BAT54WS':
        L.append(Limit('reverse voltage', Vd(2, 1), None, 30, 'V', 'BAT54WS VR'))
        L.append(Limit('forward current', I('vs'), None, 0.2, 'A', 'BAT54WS IF'))
        L.append(Limit('dissipation', prod(Vd(1, 2), I('vs')), None, 0.2, 'W', 'BAT54WS PD'))
    elif sub == 'MMSZ5246BS':
        L.append(Limit('dissipation', prod(Vd(2, 1), lambda v, f=I('vz'): [-x for x in f(v)]), None, 0.2, 'W',
                       'MMSZ5246BS PD'))
    elif sub in ('SD36C', 'TVS2700', 'TVS0500'):
        L.append(Limit('steady current', I('vt'), -1e-3, 1e-3, 'A',
                       '%s is rated for pulses only; any sustained conduction' % sub))
    elif sub == 'MFNSMF020X':
        L.append(Limit('current', I('vf'), -0.1, 0.1, 'A', 'MF-NSMF020X hold current at 85 C', kind='trip'))
    elif sub == 'TPS25200':
        L.append(Limit('IN', Vd(6, 5), -0.3, 20, 'V', 'TPS25200 5.1 abs max'))
        L.append(Limit('OUT', Vd(1, 5), -0.3, 7, 'V', 'TPS25200 5.1 abs max'))
        L.append(Limit('IN to OUT', Vd(6, 1), -7, 20, 'V', 'TPS25200 5.1 abs max'))
        L.append(Limit('current', I('vsw'), None, 0.59, 'A', 'TPS25200 limit at 150k (0.59-0.71 A)', kind='trip'))
    elif sub == 'LM2776':
        L.append(Limit('VIN', Vd(3, 2), None, 6, 'V', 'LM2776 6.1 abs max'))
        L.append(Limit('GND to VOUT', Vd(2, 1), None, 6, 'V', 'LM2776 6.1 abs max'))
    elif sub == 'TPS7A3901':
        L.append(Limit('INP', Vd(1, 4), -0.3, 36, 'V', 'TPS7A39 5.1 abs max'))
        L.append(Limit('INN', Vd(5, 4), -36, 0.3, 'V', 'TPS7A39 5.1 abs max'))
        L.append(Limit('OUTP above INP', Vd(10, 1), None, 0.3, 'V', 'TPS7A39 5.1 abs max, 7.1.11 reverse current'))
        L.append(Limit('OUTN below INN', Vd(5, 6), None, 0.3, 'V', 'TPS7A39 5.1 abs max, 7.1.11 reverse current'))
        L.append(Limit('OUTP', Vd(10, 4), -0.3, 33, 'V', 'TPS7A39 5.1 abs max'))
        L.append(Limit('OUTN', Vd(6, 4), -33, 0.3, 'V', 'TPS7A39 5.1 abs max'))
    elif sub == 'TPS70918':
        L.append(Limit('VIN', Vd(6, 3), -0.3, 32, 'V', 'TPS709 6.1 abs max'))
        L.append(Limit('VOUT', Vd(1, 3), -0.3, 7, 'V', 'TPS709 6.1 abs max'))
    elif sub == 'TLV431':
        L.append(Limit('cathode voltage', Vd(2, 3), None, 7, 'V', 'TLV431 5.1 abs max'))
        L.append(Limit('cathode current', I('vk'), -20e-3, 20e-3, 'A', 'TLV431 5.1 abs max'))
    elif sub == 'MMST3906':
        L.append(Limit('collector to emitter', Vd(3, 2), -40, None, 'V', 'MMST3906 VCEO'))
        L.append(Limit('base to emitter, reverse', Vd(1, 2), None, 5, 'V', 'MMST3906 VEBO'))
        L.append(Limit('collector current', I('vc'), -0.2, 0.2, 'A', 'MMST3906 IC'))
        L.append(Limit('dissipation', prod(Vd(3, 2), I('vc')), None, 0.2, 'W', 'MMST3906 PD'))
    return L


# Rails driven out of regulation. While running, each rail should stay
# near its setting; with the channel supply off, a rail above 0.5 V is
# being back-powered through clamp diodes.
RAILS = {'p5v_ch': ('+5V_CH', 5.0), 'n5v_ch': ('-5V_CH', -4.7), 'p2v5_ch': ('+2V5_CH', 2.5),
         'n2v5_ch': ('-2V5_CH', -2.5), 'p1v8_ch': ('+1V8_CH', 1.8), 'p24v_ch': ('+24V_CH', 24.0),
         'p24v_in': ('+24V_IN', 24.0)}


def rail_limits(power):
    out = []
    for node, (name, nominal) in RAILS.items():
        f = lambda v, n=node: v[n]
        # +24V_IN comes from the stack and stays up while only the channel
        # supply is off; +24V_CH is switched with the channel supply.
        running = {'p24v_in': power in ('on', 'ch_off'), 'p24v_ch': power == 'on'}.get(node, power in ('on', 'no24'))
        if node == 'p24v_ch' and not running:
            continue                  # switched off by design; nothing to check
        if running:
            if node == 'n5v_ch':
                lo, hi = -5.3, -4.2       # the pump's droop under load is expected
            else:
                lo, hi = nominal - abs(nominal) * 0.1, nominal + abs(nominal) * 0.1
            out.append(('rail', Limit('%s out of regulation (nominal %g V)' % (name, nominal), f, lo, hi, 'V',
                                      'regulation +/-10 %', kind='function')))
        else:
            out.append(('rail', Limit('%s back-powered while off' % name, f, -0.5, 0.5, 'V',
                                      'rail should stay near 0 V', kind='function')))
    return out


def all_limits(board, power):
    """[(ref, Limit)] for every modelled part, plus the rails."""
    out = []
    for ref, p in board['parts'].items():
        if p['kind'] in ('R', 'C', 'X'):
            for lim in _limits_for(ref, p):
                out.append((ref, lim))
    return out + rail_limits(power)


def check(v, limits, volts):
    """Violations in one sweep: {(ref, what): worst} where worst records the
    extreme value, its fault voltage and the first fault voltage at which
    the limit is exceeded."""
    found = {}
    for ref, lim in limits:
        try:
            q = lim.quantity(v)
        except KeyError:
            continue
        first, worst, worst_v = None, None, None
        for x, fv in zip(q, volts):
            over = (lim.hi is not None and x > lim.hi) or (lim.lo is not None and x < lim.lo)
            if over:
                if first is None:
                    first = fv
                excess = (x - lim.hi) if (lim.hi is not None and x > lim.hi) else (lim.lo - x)
                if worst is None or excess > worst[0]:
                    worst, worst_v = (excess, x), fv
        if worst:
            found[(ref, lim.what)] = dict(value=worst[1], at=worst_v, first=first, limit=lim)
    return found
