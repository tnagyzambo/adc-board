"""Scenarios for the DC fault sweep: power state, channel configuration,
connected sensor and fault, each turned into ngspice lines around board.cir.

All faults and sensors are on channel 1. Channel 2 stays off with nothing
connected, and only loads the shared supplies.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))

CONTACTS = {'EXC+': 'gp1_excp', 'EXC-': 'gp1_excn', 'SIG+': 'gp1_sigp', 'SIG-': 'gp1_sign', 'SHLD': 'gp1_shld'}

# GPIO0..GPIO6 of the converter: LC_EN, PRT_EN, TX_EN, CAL_EN, S8_EN, S9_EN,
# SHLD_EN (tab-gp-code). A bridge runs the REFP buffer; a transmitter
# leaves it off (tab-adc-config).
LINES = ('LC_EN', 'PRT_EN', 'TX_EN', 'CAL_EN', 'S8_EN', 'S9_EN', 'SHLD_EN')
CONFIGS = {
    'off': ((), 1),
    'lc': (('LC_EN',), 1),
    'lc_cal': (('LC_EN', 'CAL_EN'), 1),
    'prt': (('PRT_EN',), 1),
    'prt_cal': (('PRT_EN', 'CAL_EN'), 1),
    'i420': (('TX_EN', 'S8_EN'), 0),
    'volt': (('TX_EN', 'S9_EN'), 0),
}

# Supplies from the stack, and the FPGA's enable of the channel supply.
POWER = {
    'on': dict(v5=5.0, v24=24.0, v33=3.3, en=3.3),      # running
    'ch_off': dict(v5=5.0, v24=24.0, v33=3.3, en=0.0),  # channel supply switched off
    'stack_off': dict(v5=0.0, v24=0.0, v33=0.0, en=0.0),  # whole stack unpowered
    'no24': dict(v5=5.0, v24=0.0, v33=3.3, en=3.3),     # running, 24 V rail absent
}

# Sensors on channel 1, and the configurations each is used in.
SENSORS = {
    'none': None,
    'lc350': ('lc', 'lc_cal'),       # 350 ohm load cell
    'prt3k5': ('prt', 'prt_cal'),    # 3.5 kohm piezoresistive (Keller 7L)
    'tx420': ('i420',),              # two-wire 4-20 mA, 21 mA, with the CBL-1 link
    'txv': ('volt',),                # three-wire 0-10 V at 10 V out, 10 mA supply
}


def sensor_lines(name):
    e, x, s, n = (CONTACTS[k] for k in ('EXC+', 'EXC-', 'SIG+', 'SIG-'))
    if name == 'none':
        return []
    if name in ('lc350', 'prt3k5'):
        r = 350 if name == 'lc350' else 3500
        return ['Rbr1 %s %s %g' % (e, s, r), 'Rbr2 %s %s %g' % (s, x, r),
                'Rbr3 %s %s %g' % (e, n, r), 'Rbr4 %s %s %g' % (n, x, r)]
    if name == 'tx420':
        # Loop current from EXC+ back on SIG+, a reverse-polarity diode, and
        # the cable link from SIG- to EXC- (CBL-1).
        return ['Dtx %s tx1 DCLAMP' % e,
                'Btx tx1 %s I = {21m*pos(tanh(v(tx1,%s)/2))}' % (s, s),
                'Rlink %s %s 0.1' % (n, x)]
    if name == 'txv':
        # Supply current from EXC+ to its common on EXC-; 10 V out through
        # 100 ohm once supplied; SIG- meets the common inside the transmitter.
        return ['Dtv %s tv1 DCLAMP' % e,
                'Btv tv1 %s I = {10m*pos(tanh(v(tv1,%s)/2))}' % (x, x),
                'Btvo tvo %s V = {10*sg(v(tv1,%s)-8,0.5)}' % (x, x),
                'Rtvo tvo %s 100' % s,
                'Rtvl %s %s 0.5' % (n, x)]
    raise ValueError(name)


def fault_lines(fault):
    """('V', contact, source) sweeps a current-limited source on a contact;
    ('short', a, b)
    joins two contacts; None leaves the channel undisturbed."""
    if fault is None:
        return ['Vf fsrc 0 0', 'Rfd fsrc 0 1k']
    if fault[0] == 'V':
        _, c, src = fault
        # A source limited to src ('5A', '30mA'), 0.1 ohm below its limit.
        ilim = float(src[:-2]) * 1e-3 if src.endswith('mA') else float(src[:-1])
        return ['Vf fsrc 0 0', 'Bf fsrc %s I = {%g*tanh(v(fsrc,%s)/(%g*0.1))}' % (CONTACTS[c], ilim, CONTACTS[c], ilim)]
    if fault[0] == 'short':
        # The short closes once the channel is running: its conductance
        # rises from 20 nS to 20 S (0.05 ohm), log-linearly over T_SHORT.
        a, b = CONTACTS[fault[1]], CONTACTS[fault[2]]
        return ['Vf fsrc 0 0', 'Rfd fsrc 0 1k',
                'Bsh %s %s I = {v(%s,%s)*20*exp(-21*(1-min(max((time-%g)/%g,0),1)))}' % (a, b, a, b, T_ON, T_SHORT)]
    raise ValueError(fault)


# The sweep runs as a slow transient, because the operating point of the
# whole channel does not converge from cold: the supplies ramp up over 1 ms,
# the switch lines come up at 1.4 ms, everything has settled by T_ON, and the fault source then ramps at 1 V/ms. With 10 pF on
# every node (cshunt) the slowest internal time constant is about 10 us, so
# each output point is a DC operating point to well within 1 mV.
T_ON = 2e-3
RATE = 1e3   # V/s
T_SHORT = 10e-3


def t_end(fault, vmax):
    return T_ON + (T_SHORT if fault and fault[0] == 'short' else abs(vmax) / RATE)


# Solver settings to retry a case with, should the previous ones fail: a
# few cases stall at a corner of a clamp or gate, and any of these gets past
# it without changing the circuit.
RETRIES = (
    dict(),
    dict(options=(('reltol=1e-4', 'reltol=1e-3'), ('gmin=1e-12', 'gmin=1e-10')), tmax=2e-5),
    dict(tmax=2e-5),
    dict(options=(('cshunt=1e-11', 'cshunt=1e-10'), ('method=gear', 'method=trap'))),
)


def deck(power, config, shield, sensor, fault=None, vmax=28.0, step=1.0, attempt=0):
    """ngspice lines for one scenario: the fault source ramps from 0 to vmax
    (either sign), with output every `step` volts. attempt picks RETRIES."""
    p = POWER[power]
    on, refbuf = CONFIGS[config]
    on = set(on) | ({'SHLD_EN'} if shield else set())
    params = ['.param %s_g%d=%d' % ('ch1', i, l in on) for i, l in enumerate(LINES)]
    params += ['.param ch1_refbuf=%d' % refbuf]
    params += ['.param ch2_g%d=0' % i for i in range(len(LINES))] + ['.param ch2_refbuf=1']
    ramp = lambda v: 'PWL(0 0 1m %g)' % v
    lines = ['* e003 GP fault sweep: %s %s shield=%d %s %s' % (power, config, shield, sensor, fault),
             '.options rshunt=1e9 cshunt=1e-11 gmin=1e-12 itl1=2000 itl2=1000 itl4=200 reltol=1e-4'
             ' abstol=1e-10 vntol=1e-5 method=gear interp noacct',
             '.include %s' % os.path.join(HERE, 'parts.lib')] + params
    lines += ['.include %s' % os.path.join(HERE, 'board.cir'),
              'Vs5 s5 0 %s' % ramp(p['v5']), 'Rs5 s5 n_5v 0.01',
              'Vs24 s24 0 %s' % ramp(p['v24']), 'Rs24 s24 n_24v 0.05',
              'Vs33 s33 0 %s' % ramp(p['v33']), 'Rs33 s33 n_3v3_lim 0.1',
              'Ven sen 0 %s' % ramp(p['en']), 'Ren sen fpga_adc_en 100']
    # 10 Mohm from every contact to GND, for the suppressors' and cable's
    # leakage: without it an open contact behind a closed switch floats on
    # 10 pF and the solver stalls.
    lines += ['Rlk_%s %s 0 10Meg' % (n, n) for ch in ('gp1', 'gp2') for n in
              ('%s_excp' % ch, '%s_excn' % ch, '%s_sigp' % ch, '%s_sign' % ch, '%s_shld' % ch)]
    lines += sensor_lines(sensor) + fault_lines(fault)
    te = t_end(fault, vmax)
    lines = [l.replace('Vf fsrc 0 0', 'Vf fsrc 0 PWL(0 0 %g 0 %g %g)' % (T_ON, te, vmax)) for l in lines]
    r = RETRIES[attempt]
    for a, b in r.get('options', ()):
        lines[1] = lines[1].replace(a, b)
    lines += ['.tran %g %g 0 %g uic' % (step / RATE, te, r['tmax']) if 'tmax' in r else
              '.tran %g %g uic' % (step / RATE, te), '.end']
    return lines


def fault_volts(n_points, vmax=28.0, step=1.0):
    """The fault source's voltage at each output point of deck()."""
    t = [k * step / RATE for k in range(n_points)]
    return [0.0 if x <= T_ON else (x - T_ON) * RATE * (1 if vmax >= 0 else -1) for x in t]
