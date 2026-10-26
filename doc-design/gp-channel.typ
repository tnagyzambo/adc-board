// =============================================================================
//  GENERAL-PURPOSE CHANNEL  --  simplified functional schematics.
//
//  One circuit, configured by the FPGA through switches S1 to S10.  Each
//  drawing shows the same channel set up for one sensor: closed switches and
//  the parts and paths in use are drawn in black, open switches and the parts
//  they leave idle in grey.  The parts that set the converter's accuracy are
//  drawn as components; the excitation, the sensor supply and the gate drive
//  are left out or drawn as blocks, and so is decoupling.
//
//  Drawn in millimetres, with the symbols in the proportions of the ECAD
//  library's KiCad symbols and, as in KiCad, one stroke for wires and symbols.
//
//      #figure(caption: [...], gp-channel("load-cell"))
//
//  Configurations: "load-cell", "piezo" (a piezoresistive bridge), "current"
//  (a 4–20 mA transmitter), "voltage" (a 0–10 V transmitter).
// =============================================================================

#import "@local/eng-report:0.6.0": fletcher, fonts, size, track, rule, ink

#let cetz = fletcher.cetz

// Parts and paths that a configuration leaves idle.
#let idle = luma(175)

#let _st(paint) = (paint: paint, thickness: rule.thin)
#let _s = _st(ink.rule)
#let _zone = (paint: ink.rule, thickness: rule.hair, dash: "dashed")
#let _bus = (paint: ink.rule, thickness: rule.thin, dash: "dashed")
#let _arrow = (end: ">", fill: ink.rule, length: 1.6mm, width: 1.2mm)

// -- GEOMETRY ----------------------------------------------------------------

#let _len(a, b) = calc.sqrt(
  calc.pow(b.at(0) - a.at(0), 2) + calc.pow(b.at(1) - a.at(1), 2),
)

#let _mid(a, b) = ((a.at(0) + b.at(0)) / 2, (a.at(1) + b.at(1)) / 2)

// The point `t` along the line from `a` to `b`, offset `o` to its left.
#let _at(a, b, t, o) = {
  let l = _len(a, b)
  let (ux, uy) = ((b.at(0) - a.at(0)) / l, (b.at(1) - a.at(1)) / l)
  (a.at(0) + ux * t - uy * o, a.at(1) + uy * t + ux * o)
}

// A label `gap` clear of `c` to its "n", "e", "s" or "w".
#let _label(c, body, side, gap, paint: ink.text) = {
  import cetz.draw: content
  let (x, y) = c
  let (pos, anchor) = (
    n: ((x, y + gap), "south"),
    e: ((x + gap, y), "west"),
    s: ((x, y - gap), "north"),
    w: ((x - gap, y), "east"),
  ).at(side)
  content(pos, text(fill: paint, body), anchor: anchor)
}

// Text at a point, in the paint of the part it names.
#let _text(p, body, anchor: "center", paint: ink.text) = {
  cetz.draw.content(p, text(fill: paint, body), anchor: anchor)
}

// -- SYMBOLS -----------------------------------------------------------------

#let wire(..pts, paint: ink.rule) = cetz.draw.line(..pts, stroke: _st(paint))

// Junction.
#let dot(p, paint: ink.rule) = cetz.draw.circle(p, radius: 0.45, fill: paint, stroke: none)

// Connector contact.
#let pin(p) = cetz.draw.circle(p, radius: 0.6, fill: white, stroke: _s)

// Resistor between two points: the library's zigzag, 5 mm by 2 mm.
#let res(a, b, label: none, side: "n", paint: ink.rule) = {
  import cetz.draw: line
  let (body, amp) = (5, 1)
  let s = (_len(a, b) - body) / 2
  let zig = ((0, 0), (0.1, -1), (0.3, 1), (0.5, -1), (0.7, 1), (0.9, -1), (1, 0))
  line(a, _at(a, b, s, 0), stroke: _st(paint))
  line(..zig.map(((t, o)) => _at(a, b, s + t * body, o * amp)), stroke: _st(paint))
  line(_at(a, b, s + body, 0), b, stroke: _st(paint))
  if label != none { _label(_mid(a, b), label, side, amp + 0.6, paint: paint) }
}

// Capacitor between two points: plates 3.6 mm wide, 1.2 mm apart.
#let cap(a, b, label: none, side: "e", paint: ink.rule) = {
  import cetz.draw: line
  let (gap, w) = (1.2, 3.6)
  let m = _len(a, b) / 2
  line(a, _at(a, b, m - gap / 2, 0), stroke: _st(paint))
  line(_at(a, b, m + gap / 2, 0), b, stroke: _st(paint))
  for t in (m - gap / 2, m + gap / 2) {
    line(_at(a, b, t, w / 2), _at(a, b, t, -w / 2), stroke: _st(paint))
  }
  if label != none { _label(_mid(a, b), label, side, w / 2 + 0.6, paint: paint) }
}

// Op amp from the end of its + pin: inputs 5 mm apart with + above, as in the
// library symbol, and the output pin ending 14 mm along, level between them.
#let opamp(p, name: none) = {
  import cetz.draw: line, content
  let (x, y) = p
  line((x, y), (x + 2, y), stroke: _s)
  line((x, y - 5), (x + 2, y - 5), stroke: _s)
  line(
    (x + 2, y + 2.5),
    (x + 12, y - 2.5),
    (x + 2, y - 7.5),
    close: true,
    stroke: _s,
    fill: white,
  )
  line((x + 12, y - 2.5), (x + 14, y - 2.5), stroke: _s)
  content((x + 3.6, y), [+])
  content((x + 3.6, y - 5), [−])
  if name != none { content((x + 2, y + 3.1), name, anchor: "south-west") }
}

// Ground or supply return: an open triangle, labelled to its right.
#let gnd(p, label: none, paint: ink.rule) = {
  import cetz.draw: line
  let (x, y) = p
  line((x, y), (x, y - 1.6), stroke: _st(paint))
  line((x - 1.3, y - 1.6), (x + 1.3, y - 1.6), (x, y - 2.9), close: true, stroke: _st(paint))
  if label != none { _label((x + 1.3, y - 2.2), label, "e", 0.5, paint: paint) }
}

// Switch from `a` to `b`, in any direction: contacts 3 mm apart, the blade
// lifted to the left of the direction of travel when open.
#let switch(a, b, label: none, side: "e", closed: false, paint: ink.rule) = {
  import cetz.draw: line, circle
  let m = _len(a, b) / 2
  let (c0, c1) = (_at(a, b, m - 1.5, 0), _at(a, b, m + 1.5, 0))
  line(a, c0, stroke: _st(paint))
  line(c1, b, stroke: _st(paint))
  if closed {
    line(c0, c1, stroke: _st(paint))
  } else {
    line(c1, _at(a, b, m - 1.3, 1.8), stroke: _st(paint))
  }
  for c in (c0, c1) { circle(c, radius: 0.35, fill: white, stroke: _st(paint)) }
  if label != none { _label(_mid(a, b), label, side, 2.4, paint: paint) }
}

#let _source(a, b) = {
  import cetz.draw: line, circle
  let (r, m) = (2.8, _len(a, b) / 2)
  line(a, _at(a, b, m - r, 0), stroke: _s)
  line(_at(a, b, m + r, 0), b, stroke: _s)
  circle(_mid(a, b), radius: r, stroke: _s, fill: white)
}

// Current source from `a` to `b`, the arrow in the direction of the current.
#let isource(a, b, label: none, side: "e") = {
  import cetz.draw: line
  let m = _len(a, b) / 2
  _source(a, b)
  line(_at(a, b, m - 1.8, 0), _at(a, b, m + 1.8, 0), stroke: _s, mark: _arrow)
  if label != none { _label(_mid(a, b), label, side, 3.4) }
}

// Voltage source from + at `a` to − at `b`.
#let vsource(a, b, label: none, side: "e") = {
  import cetz.draw: content
  let m = _len(a, b) / 2
  _source(a, b)
  content(_at(a, b, m - 1.3, 0), [+])
  content(_at(a, b, m + 1.3, 0), [−])
  if label != none { _label(_mid(a, b), label, side, 3.4) }
}

// Functional block: corners `a` and `b`, its text centred.
#let blk(a, b, body) = {
  import cetz.draw: rect, content
  rect(a, b, stroke: (paint: ink.rule, thickness: rule.hair), fill: white)
  content(_mid(a, b), align(center, body))
}

// Domain: a dashed outline from bottom left `a` to top right `b`, titled above
// its top left corner as the template's `group` is.
#let domain(a, b, label) = {
  import cetz.draw: rect, content
  rect(a, b, stroke: _zone)
  content((a.at(0), b.at(1) + 1), text(fill: ink.mute, upper(label)), anchor: "south-west")
}

// Drawing scaled down to the text width where the page is narrower than it.
#let _fit(body) = layout(region => {
  let w = measure(body).width
  if w <= region.width { body } else {
    scale(region.width / w * 100%, reflow: true, body)
  }
})

// -- CHANNEL -----------------------------------------------------------------

// Rows of the four sensor contacts, the converter's inputs, the three REFP
// sources and REFN.
#let _y = (
  ep: 54, sp: 41, en: 28, sn: 15, inp: 38.5, inn: 12.5,
  r1: -2, r2: -8, r3: -14, rn: -20,
)

#let gp-channel(config) = {
  assert(
    config in ("load-cell", "piezo", "current", "voltage"),
    message: "no configuration " + repr(config),
  )
  let y = _y
  let bridge = config in ("load-cell", "piezo")
  let tx = not bridge
  // Closed switches, and the parts each configuration uses.
  let on = (
    s1: config == "load-cell",
    s2: tx,
    s3: config == "load-cell",
    s4: tx,
    s5: config == "load-cell",
    s6: config == "piezo",
    s7: tx,
    s8: config == "current",
    s9: config == "voltage",
  )
  let sense = config != "load-cell"
  let exc-n = true
  let c(b) = if b { ink.rule } else { idle }
  // Columns: the contacts, the current source's branches, the return of
  // EXC−, shunt calibration, the shunt, the divider, the buffers and the
  // converter's input filter, the converter.
  let xc = 26
  let (b0, b1, b2) = (34, 45, 56)
  let (xs, x3, xcal, x4) = (31, 43, 50, 55)
  let (xsh, xdv) = (63, 82)
  let (sp0, sp1, sn0, sn1) = (67, 79, 85, 95)
  let (xk, xop, xo, x702, x718, xa) = (98, 101, 118, 132, 136, 147)
  // REFP sources: resistor, switch and the bus that joins them.
  let (rr0, rr1, rs0, rs1, xb) = (64, 76, 78, 86, 90)

  set text(font: fonts.display, size: size.tiny, tracking: track.label)
  _fit(cetz.canvas(length: 1mm, {
    import cetz.draw: line, content

    domain((-2, 9), (20, 60), [Vehicle])
    domain((xc, -28), (166, 75), [General-purpose channel])

    // -- Sensor -----------------------------------------------------------
    if bridge {
      let (t, r, b, l) = ((9, y.ep), (17, y.sp), (9, y.en), (1, y.sp))
      res(t, r)
      res(r, b)
      res(b, l)
      res(l, t)
      content((9, y.sp), if config == "piezo" { [3.5~kΩ] } else { [350~Ω] })
      for p in (t, r, b, l) { dot(p) }
      wire(t, (xc, y.ep))
      wire(r, (xc, y.sp))
      wire(b, (xc, y.en))
      wire(l, (1, y.sn), (xc, y.sn))
    } else if config == "current" {
      wire((xc, y.ep), (4, y.ep))
      isource((4, y.ep), (4, y.sp), label: [4–20~mA])
      wire((4, y.sp), (xc, y.sp))
      // SIG− linked to EXC− in the cable (CBL-1), so the loop returns
      // through S4.
      wire((xc, y.en), (23, y.en), (23, y.sn), (xc, y.sn))
      content((21.8, (y.en + y.sn) / 2), [Link], angle: 90deg)
    } else {
      cetz.draw.rect((0, 11), (18, 50), stroke: _s)
      content((9, 48.6), [Transmitter], anchor: "north")
      wire((xc, y.ep), (9, y.ep), (9, 50))
      vsource((5, y.sp - 3), (5, y.en + 1), label: [0–10~V])
      wire((5, y.sp - 3), (5, y.sp), (xc, y.sp))
      wire((5, y.en + 1), (5, 21), (14, 21))
      wire((xc, y.en), (14, y.en), (14, y.sn), (xc, y.sn))
      dot((14, 21))
    }

    // -- Current source: 1 mA always, 9 mA with S1, 30 mA with S2 ---------
    let current = (load-cell: [9.0~mA], piezo: [1.0~mA]).at(config, default: [30~mA limit])
    // The LT3092 feeds the branches from the east; its output resistor is
    // the parallel combination of the branches switched in.
    let yo = 67.5
    blk((64, yo - 3.5), (80, yo + 3.5), [LT3092\ #current])
    blk((85, yo - 3.5), (103, yo + 3.5), [Sensor supply\ 24~V])
    wire((80, yo), (85, yo))
    wire((b0, yo), (64, yo))
    dot((b1, yo))
    dot((b2, yo))
    res((b0, yo), (b0, y.ep), label: [301~Ω], side: "e")
    for (x, s, r, name) in ((b1, on.s1, [37.4~Ω], [S1]), (b2, on.s2, [10.2~Ω], [S2])) {
      switch((x, yo), (x, yo - 6.5), label: name, closed: s, paint: c(s))
      res((x, yo - 6.5), (x, y.ep), label: r, side: "e", paint: c(s))
    }
    wire((xc, y.ep), (b0, y.ep))
    wire((b0, y.ep), (b1, y.ep), paint: c(on.s1 or on.s2))
    wire((b1, y.ep), (b2, y.ep), paint: c(on.s2))
    dot((b0, y.ep))
    dot((b1, y.ep), paint: c(on.s1 or on.s2))

    // -- EXC−: returned to the bus through the 1.00 kΩ current-sense
    // resistor, or straight by S3; to GND by S4 -----------------------
    let en = ink.rule
    wire((xc, y.en), (x4, y.en), paint: en)
    let yr = 21.5
    res((xs, y.en), (xs, yr), label: [1.00~kΩ], side: "e", paint: c(sense))
    switch((x3, y.en), (x3, yr), label: [S3], closed: on.s3, paint: c(on.s3))
    wire((xs, yr), (x3, yr), paint: c(exc-n))
    _text(((xs + x3) / 2, yr - 0.4), [EXC_N], anchor: "north", paint: c(exc-n))
    switch((x4, y.en), (x4, 22), label: [S4], closed: on.s4, paint: c(on.s4))
    gnd((x4, 22), label: [GND], paint: c(on.s4))
    for x in (xs, x3, xcal) { dot((x, y.en), paint: en) }

    // Shunt calibration across the SIG+ to EXC− arm, for a bridge.
    res((xcal, y.sp), (xcal, 34.5), label: [RCAL], side: "e", paint: c(bridge))
    switch((xcal, 34.5), (xcal, y.en), label: [S10], paint: c(bridge))
    dot((xcal, y.sp), paint: c(bridge))

    // -- Signal contacts ----------------------------------------------------
    // The 4–20 mA shunt across the signal contacts, closed by S8.
    res((xsh, y.sp), (xsh, 32), label: [100~Ω], side: "e", paint: c(on.s8))
    switch((xsh, 32), (xsh, 22), label: [S8], closed: on.s8, paint: c(on.s8))
    wire((xsh, 22), (xsh, y.sn), paint: c(on.s8))
    dot((xsh, y.sp), paint: c(on.s8))
    dot((xsh, y.sn), paint: c(on.s8))

    // The 10.0 kΩ series resistor; with the 2.49 kΩ bottom switched in by
    // S9 it is the top of a 5:1 divider, returned to SIG− at the contact.
    wire((xc, y.sp), (sp0, y.sp))
    res((sp0, y.sp), (sp1, y.sp), label: [10.0~kΩ])
    wire((sp1, y.sp), (xop, y.sp))
    res((xdv, y.sp), (xdv, 30), label: [2.49~kΩ], side: "e", paint: c(on.s9))
    switch((xdv, 30), (xdv, 20), label: [S9], closed: on.s9, paint: c(on.s9))
    wire((xdv, 20), (xdv, y.sn), paint: c(on.s9))
    dot((xdv, y.sp), paint: c(on.s9))
    dot((xdv, y.sn), paint: c(on.s9))
    wire((xc, y.sn), (sn0, y.sn))
    res((sn0, y.sn), (sn1, y.sn), label: [10~kΩ])
    wire((sn1, y.sn), (xop, y.sn))

    for (row, name) in ((y.ep, [EXC+]), (y.sp, [SIG+]), (y.en, [EXC−]), (y.sn, [SIG−])) {
      pin((xc, row))
      content((xc + 0.9, row + 0.5), name, anchor: "south-west")
    }

    // -- Buffers and converter input filter -------------------------------
    cap((xk, y.sp), (xk, y.sn), label: [110~pF], side: "w")
    dot((xk, y.sp))
    dot((xk, y.sn))
    for (y0, yo) in ((y.sp, y.inp), (y.sn, y.inn)) {
      opamp((xop, y0), name: [OPA2189])
      wire((xop + 14, yo), (xo, yo))
      wire((xo, yo), (xo, y0 - 9), (xop - 2, y0 - 9), (xop - 2, y0 - 5), (xop, y0 - 5))
      dot((xo, yo))
      res((xo, yo), (xo + 12, yo), label: [237~Ω])
      wire((xo + 12, yo), (xa, yo))
      dot((x702, yo))
      dot((x718, yo))
      cap((x718, yo), (x718, yo - 6.5), label: [330~pF])
      gnd((x718, yo - 6.5), label: [AVSS])
    }
    cap((x702, y.inp), (x702, y.inn), label: [3.3~nF], side: "w")

    // -- Reference: REFP from EXC+ (S5), EXC− (S6) or the bus (S7) --------
    blk((30, -24), (56, -10), [Excitation ±2.048~V\ REF5020, OPA2189])
    for (row, net, r, s, name) in (
      (y.r1, [EXC+], [10~kΩ], on.s5, [S5]),
      (y.r2, [EXC−], [237~Ω], on.s6, [S6]),
      (y.r3, none, [237~Ω], on.s7, [S7]),
    ) {
      if net == none {
        wire((56, row), (rr0, row), paint: c(s))
      } else {
        wire((58, row), (rr0, row), paint: c(s))
        _text((58.5, row + 0.4), net, anchor: "south-west", paint: c(s))
      }
      res((rr0, row), (rr1, row), label: r, paint: c(s))
      wire((rr1, row), (rs0, row), paint: c(s))
      switch((rs0, row), (rs1, row), label: name, side: "n", closed: s, paint: c(s))
      wire((rs1, row), (xb, row), paint: c(s))
      dot((xb, row), paint: c(s))
    }
    _text((57.5, y.r3 + 0.4), [EXC_P], anchor: "south-west", paint: c(on.s7))
    wire((xb, y.r1), (xb, y.r2), paint: c(on.s5))
    wire((xb, y.r2), (xb, y.r3), paint: c(on.s7))
    wire((xb, y.r2), (xa, y.r2))
    wire((56, y.rn), (rr0, y.rn))
    _text((57.5, y.rn + 0.4), [EXC_N], anchor: "south-west")
    res((rr0, y.rn), (rr1, y.rn), label: [237~Ω], side: "s")
    wire((rr1, y.rn), (xa, y.rn))
    cap((138, y.r2), (138, y.rn), label: [1.1~µF], side: "w")
    dot((138, y.r2))
    dot((138, y.rn))

    // -- Converter ----------------------------------------------------------
    cetz.draw.rect((xa, -24), (xa + 16, 44), stroke: _s, fill: white)
    content((xa + 8, (y.inp + y.inn) / 2), [ADS127L14])
    for (row, name) in ((y.inp, [AINP0]), (y.inn, [AINN0]), (y.r2, [REFP]), (y.rn, [REFN])) {
      content((xa + 1, row), name, anchor: "west")
    }
  }))
}

// -- EXCITATION MONITOR ------------------------------------------------------

// One channel's excitation monitor: the three other converters of its
// ADS127L14, each reading one node against GND.
#let gp-monitor() = {
  // Rows: EXC+ and EXC− at the contacts; the three inputs' positive sides,
  // each with its negative side, on GND, below it.
  let (ye, yb) = (52, 22.5)
  let (y1, y2, y3) = (ye - 2.5, yb - 2.5, -14)
  // Columns: the contacts, the divider on EXC+, the buffers and their
  // outputs, the dividers after them, and the converter.
  let xc = 26
  let (d0, d1, xp) = (44, 58, 62)
  let (xop, xo) = (70, 88)
  let (e0, e1, xq) = (92, 104, 108)
  let xa = 132

  set text(font: fonts.display, size: size.tiny, tracking: track.label)
  _fit(cetz.canvas(length: 1mm, {
    import cetz.draw: line, content

    domain((-2, 17), (20, 58), [Vehicle])
    domain((xc, -28), (158, 68), [General-purpose channel])

    // -- Sensor -----------------------------------------------------------
    res((9, ye), (9, yb), label: [Bridge\ 3.5~kΩ], side: "e")
    wire((9, ye), (xc, ye))
    wire((9, yb), (xc, yb))

    // -- Excitation -------------------------------------------------------
    blk((30, 57), (44, 64), [LT3092\ 1~mA])
    blk((49, 57), (65, 64), [Sensor supply\ 24~V])
    wire((44, 60.5), (49, 60.5))
    wire((37, 57), (37, ye))
    dot((37, ye))

    for (row, name) in ((ye, [EXC+]), (yb, [EXC−])) {
      pin((xc, row))
      content((xc + 0.9, row + 0.5), name, anchor: "south-west")
    }

    // A buffer from its + input at `p`, with its output joined back to its
    // − input, ending at `xo`.
    let follower(p, name) = {
      let (x, y) = p
      opamp((x, y), name: name)
      wire((x + 14, y - 2.5), (xo, y - 2.5))
      wire((xo, y - 2.5), (xo, y - 9), (x - 2, y - 9), (x - 2, y - 5), (x, y - 5))
      dot((xo, y - 2.5))
    }

    // -- Excitation input: EXC+ divided by 25, then buffered ----------------
    wire((xc, ye), (d0, ye))
    res((d0, ye), (d1, ye), label: [240~kΩ])
    wire((d1, ye), (xop, ye))
    res((xp, ye), (xp, ye - 8), label: [10.0~kΩ], side: "w")
    gnd((xp, ye - 8))
    dot((xp, ye))
    follower((xop, ye), [½ OPA2189])
    wire((xo, y1), (xa, y1))

    // -- Return input: EXC− buffered through 10 kΩ, then divided by 2 -------
    wire((xc, yb), (40, yb))
    res((40, yb), (54, yb), label: [10~kΩ])
    wire((54, yb), (xop, yb))
    follower((xop, yb), [½ OPA2189])
    wire((xo, y2), (e0, y2))
    res((e0, y2), (e1, y2), label: [1.00~kΩ])
    wire((e1, y2), (xa, y2))
    res((xq, y2), (xq, y2 - 8), label: [1.00~kΩ], side: "e")
    gnd((xq, y2 - 8))
    dot((xq, y2))

    // -- Bus input: the positive side of the bus divided by 4 ---------------
    blk((30, -24), (56, -10), [Excitation ±2.048~V\ REF5020, OPA2189])
    wire((56, y3), (e0, y3))
    content((57.5, y3 + 0.4), [EXC_P], anchor: "south-west")
    res((e0, y3), (e1, y3), label: [3.01~kΩ])
    wire((e1, y3), (xa, y3))
    res((xq, y3), (xq, y3 - 8), label: [1.00~kΩ], side: "e")
    gnd((xq, y3 - 8))
    dot((xq, y3))
    wire((56, -20), (59, -20))
    content((59.5, -20), [EXC_N], anchor: "west")

    // -- Converter, its negative inputs on GND ------------------------------
    cetz.draw.rect((xa, -26), (xa + 22, 60), stroke: _s, fill: white)
    content((xa + 11, 56), [ADS127L14])
    for (row, k) in ((y1, 1), (y2, 2), (y3, 3)) {
      content((xa + 1, row), [AINP#k], anchor: "west")
      content((xa + 1, row - 6), [AINN#k], anchor: "west")
      wire((xa, row - 6), (xa - 7, row - 6))
      gnd((xa - 7, row - 6), label: [GND])
    }
  }))
}

// -- BOARD ARCHITECTURE ------------------------------------------------------

// The board's functional layout: one channel, with the second stacked behind
// it, the FPGA and the two connectors, all on the stack's ground.
// Heavy lines carry power, dashed lines digital data and thin lines analog
// signals.
#let board-arch() = {
  let pw = (paint: ink.rule, thickness: rule.thick)
  let both = (start: ">", end: ">", fill: ink.rule, length: 1.6mm, width: 1.2mm)
  // Power, toward the load.
  let power(..pts) = cetz.draw.line(..pts, stroke: pw, mark: _arrow)
  // Digital data, one way or both.
  let data(two: false, ..pts) = cetz.draw.line(
    ..pts,
    stroke: _bus,
    mark: if two { both } else { _arrow },
  )
  // Analog signal, toward its destination.
  let signal(..pts) = cetz.draw.line(..pts, stroke: _s, mark: _arrow)
  // A connector: a tall block, its name running up it.
  let conn(a, b, body) = {
    cetz.draw.rect(a, b, stroke: _s, fill: white)
    cetz.draw.content(_mid(a, b), body, angle: 90deg)
  }

  // The channel's outline, and the step between it and each channel stacked
  // behind it.
  let (c0, c1, step) = ((14, 14), (96, 68), 1.6)

  set text(font: fonts.display, size: size.tiny, tracking: track.label)
  _fit(cetz.canvas(length: 1mm, {
    import cetz.draw: content, rect

    // -- The channels -------------------------------------------------------
    for k in (1,) {
      let d = k * step
      rect(
        (c0.at(0) + d, c0.at(1) + d),
        (c1.at(0) + d, c1.at(1) + d),
        stroke: _zone,
        fill: white,
      )
    }
    rect(c0, c1, stroke: _zone, fill: white)
    content(
      (c0.at(0) + 1.5, c1.at(1) - 1.5),
      text(fill: ink.mute, upper[General-purpose channel ×2]),
      anchor: "north-west",
    )

    conn((0, 30), (8, 70), [Sensor connector])

    blk((20, 36), (44, 62), [Protection,\ configuration\ switches])
    blk((20, 17), (39, 27), [Current source\ LT3092])
    blk((54, 46), (68, 58), [Buffers\ OPA2189])
    blk((76, 32), (94, 60), [ADS127L14\ \ Signal,\ monitor])
    blk((54, 17), (70, 29), [Reference,\ excitation\ ±2.048~V])
    blk((76, 0), (94, 9), [Inverter,\ regulators])

    // Sensor lines, sensor supply and excitation.
    cetz.draw.line((8, 49), (20, 49), stroke: _s)
    signal((29.5, 27), (29.5, 36))
    _text((30.5, 31.5), [EXC+], anchor: "west")
    signal((44, 52), (54, 52))
    _text((48.5, 52.8), [SIG±], anchor: "south")
    signal((68, 52), (76, 52))
    wire((54, 23), (41.5, 23), (41.5, 36))
    _text((47.75, 23.6), [Bus], anchor: "south")
    wire((70, 23), (85, 23), (85, 32))
    _text((77.5, 23.6), [Reference], anchor: "south")

    // Switch enables, straight from the converter's GPIO.
    data((76, 40), (44, 40))
    _text((60, 40.6), [GPIO], anchor: "south")

    // -- The converters' lines, straight to the FPGA's 1.8 V bank ------------
    data((94, 47), (120, 47), two: true)
    _text((108.8, 47.6), [Clock, SPI, data], anchor: "south")

    // -- FPGA and the stack interface -----------------------------------------
    blk((120, 24), (142, 58), [FPGA\ LCMXO2-4000HC])
    blk((120, 64), (139, 73), [Golden image\ flash])
    blk((150, 48), (168, 56), [CS select])
    blk((150, 25), (168, 44), [Bus buffer\ \ SPI, clock,\ start])
    blk((154, 0), (168, 9), [Channel\ limit])
    blk((154, 12.5), (168, 21.5), [3.3~V\ limit])
    blk((154, -13), (168, -4), [24~V fuse,\ suppressor])

    data((129.5, 64), (129.5, 58), two: true)
    data((159, 48), (159, 44))
    data((142, 39), (150, 39), two: true)

    conn((174, -14), (182, 76), [ASRP-PCB-INTERCONNECT-2])
    data((168, 39), (174, 39), two: true)
    data((174, 52), (168, 52))
    data((174, 29), (168, 29))
    data((150, 29), (142, 29))

    // -- Power ---------------------------------------------------------------
    power((174, 4.5), (168, 4.5))
    power((154, 4.5), (94, 4.5))
    // The stack's 24 V, through the board's fuse, up into every channel's
    // current source.
    power((174, -8.5), (168, -8.5))
    power((154, -8.5), (29.5, -8.5), (29.5, 17))
    power((85, 9), (85, 15.5))
    _text((86, 12), [Rails], anchor: "west")
    // The stack's 3.3 V, through its own limit, to the FPGA and the stack side;
    // the 5 V feeds only the channels.
    power((174, 17), (168, 17))
    power((154, 17), (133, 17), (133, 24))
  }))
}
