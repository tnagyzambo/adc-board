"""Compare the model with the figures the design summary works out by hand.

python3 validate.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import scenarios as sc  # noqa: E402
from ngspice import NgSpice  # noqa: E402

ng = NgSpice()


def at(case, v28=28.0):
    """Vectors of one case at the end of its ramp."""
    power, config, shield, sensor, fault = case
    for attempt in range(len(sc.RETRIES)):
        v = ng.run(sc.deck(power, config, shield, sensor, fault, vmax=v28, attempt=attempt), timeout=60)
        if v.get('time') and v['time'][-1] >= sc.t_end(fault, v28) * 0.999:
            return {k: x[-1] for k, x in v.items()}
    raise SystemExit('did not converge: %s\n%s' % (case, '\n'.join(ng.errors())))


def show(label, doc, value):
    print('%-66s doc %-10s model %s' % (label, doc, value))


v = at(('on', 'off', 0, 'lc350', None), 1.0)
show('Load cell, channel off: 1.0 mA through 350 ohm', '0.35 V', '%.2f V' % (v['gp1_excp'] - v['gp1_excn']))
show('Load cell: -5V_CH under load (sec-gp-supply)', '-4.7 V', '%.2f V' % v['n5v_ch'])
v = at(('on', 'lc', 0, 'lc350', None), 1.0)
show('Load cell: bridge voltage at 9.0 mA, configured', '3.2 V', '%.2f V' % (v['gp1_excp'] - v['gp1_excn']))
show('Load cell: REFP', '~1.1 V', '%.3f V' % v['ch1_refp'])
v = at(('on', 'prt', 0, 'prt3k5', None), 1.0)
show('Piezoresistive: current-sense voltage at 1.0 mA', '1.0 V', '%.3f V' % (v['gp1_excn'] - v['ch1_exc_n']))
v = at(('on', 'i420', 0, 'tx420', None), 1.0)
show('4-20 mA: shunt voltage at 21 mA', '2.1 V', '%.3f V' % (v['gp1_sigp'] - v['gp1_sign']))
v = at(('on', 'volt', 0, 'txv', None), 1.0)
show('Voltage: divider tap at 10 V out (5:1)', '2.0 V', '%.3f V' % (v['net_r238_pad2'] - v['gp1_sign']))

v = at(('on', 'lc', 0, 'lc350', ('V', 'SIG+', '5A')))
show('+28 V on SIG+: SIG+ buffer clamp current (sec-gp-chain)', '2.1 mA', '%.2f mA' % (1e3 * v['v.xu2.xa.vcp#branch']))
show('  buffer output into the converter clamp (sec-gp-supply)', '~8 mA', '%.2f mA' % (1e3 * v['v.xu9.vk43#branch']))
v = at(('on', 'volt', 0, 'none', ('V', 'SIG-', '5A')))
show('+28 V on SIG-, voltage config: SIG+ buffer clamp (sec-protection)', '7.4 mA', '%.2f mA' % (1e3 * v['v.xu2.xa.vcp#branch']))
show('  2.49k divider bottom dissipation', '0.1 W', '%.3f W' % ((v['gp1_sign'] - v['net_r8_pad2']) ** 2 / 2490))
v = at(('on', 'off', 0, 'none', ('V', 'EXC-', '30mA')))
show('30 mA into EXC-, off: EXC- held by S4 body diode', '0.7 V', '%.2f V' % v['gp1_excn'])
show('  current-sense resistor current (tab-protection)', '2.8 mA', '%.2f mA' % (1e3 * (v['gp1_excn'] - v['ch1_exc_n']) / 1000))
show('  S4 body diode dissipation (sec-protection)', '21 mW', '%.1f mW' % (
    1e3 * (v['gp1_excn']) * v['v.xq3.vb#branch']))
v = at(('on', 'i420', 0, 'tx420', ('V', 'SIG+', '30mA')))
show('30 mA into SIG+, 4-20 mA, 21 mA loop: shunt dissipation (sec-protection)', '<= 0.28 W', '%.1f mW' % (
    1e3 * (v['gp1_sigp'] - v['net_q1_pad3']) ** 2 / 100))
v = at(('on', 'off', 0, 'none', ('V', 'EXC+', '5A')))
show('+28 V on EXC+: LT3092 reverse current (tab-protection)', '< 1 mA', '%.3f mA' % (
    1e3 * v['v.xu6.vrev#branch']))
v = at(('on', 'off', 0, 'tx420', None), 1.0)
show('Two-wire transmitter on a channel that is off: +2V5_CH', '< 2.7 V', '%.3f V' % v['p2v5_ch'])
show('  clamp current into the converter, AINP0', '~8 mA', '%.2f mA' % (1e3 * v['v.xu9.vk43#branch']))
show('  shunt clamp (Q10) current', '', '%.2f mA' % (-1e3 * v['v.xq10.vc#branch']))
