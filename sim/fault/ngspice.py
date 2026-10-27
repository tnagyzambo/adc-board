"""Run a netlist in KiCad's bundled ngspice shared library and return its vectors."""
import ctypes as C
import os
import time

LIB = os.environ.get('NGSPICE_LIB', '/Applications/KiCad/KiCad.app/Contents/PlugIns/sim/libngspice.0.dylib')


class _Vec(C.Structure):
    _fields_ = [('v_name', C.c_char_p), ('v_type', C.c_int), ('v_flags', C.c_short),
                ('v_realdata', C.POINTER(C.c_double)), ('v_compdata', C.c_void_p), ('v_length', C.c_int)]


class NgSpice:
    def __init__(self):
        self.lib = C.CDLL(LIB)
        self.out = []
        send_char = C.CFUNCTYPE(C.c_int, C.c_char_p, C.c_int, C.c_void_p)
        send_stat = C.CFUNCTYPE(C.c_int, C.c_char_p, C.c_int, C.c_void_p)
        on_exit = C.CFUNCTYPE(C.c_int, C.c_int, C.c_bool, C.c_bool, C.c_int, C.c_void_p)
        # Keep the callbacks referenced, or ctypes frees them under ngspice.
        self._cb = (send_char(lambda s, i, p: self.out.append(s.decode(errors='replace')) or 0),
                    send_stat(lambda s, i, p: 0), on_exit(lambda *a: 0))
        self.lib.ngSpice_Init(self._cb[0], self._cb[1], self._cb[2], None, None, None, None)
        self.lib.ngGet_Vec_Info.restype = C.POINTER(_Vec)
        self.lib.ngSpice_CurPlot.restype = C.c_char_p
        self.lib.ngSpice_AllVecs.restype = C.POINTER(C.c_char_p)
        self.lib.ngSpice_running.restype = C.c_bool
        self.timed_out = False

    def cmd(self, s):
        return self.lib.ngSpice_Command(s.encode())

    def run(self, lines, timeout=None):
        """Load the netlist lines, run its analysis, and return {vector: [values]}.
        With a timeout in seconds, the analysis is halted there and the
        vectors hold what it reached; timed_out is then set."""
        self.out.clear()
        self.timed_out = False
        self.cmd('destroy all')
        self.cmd('remcirc')
        arr = (C.c_char_p * (len(lines) + 1))(*[l.encode() for l in lines], None)
        self.lib.ngSpice_Circ(arr)
        if timeout is None:
            self.cmd('run')
        else:
            self.cmd('bg_run')
            t0 = time.time()
            time.sleep(0.02)
            while self.lib.ngSpice_running():
                if time.time() - t0 > timeout:
                    self.cmd('bg_halt')
                    while self.lib.ngSpice_running():
                        time.sleep(0.01)
                    self.timed_out = True
                    break
                time.sleep(0.02)
        plot = self.lib.ngSpice_CurPlot()
        names = self.lib.ngSpice_AllVecs(plot)
        vecs = {}
        i = 0
        while names[i]:
            n = names[i].decode()
            v = self.lib.ngGet_Vec_Info(('%s.%s' % (plot.decode(), n)).encode())
            if v and v.contents.v_realdata:
                vecs[n.lower()] = [v.contents.v_realdata[k] for k in range(v.contents.v_length)]
            i += 1
        return vecs

    def errors(self):
        return [l for l in self.out if 'error' in l.lower() or 'singular' in l.lower() or 'abort' in l.lower()]
