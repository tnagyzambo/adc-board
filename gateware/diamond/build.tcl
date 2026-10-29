# Lattice Diamond batch build: synthesis, translate, map, place and route,
# timing analysis, then the SRAM bitstream (.bit) and the flash image (.jed).
#
# Run by `make build` inside the container as `pnmainc diamond/build.tcl`.
# The Makefile passes everything through the environment:
#
#   E003_TOP      top-level entity
#   E003_DEVICE   part number, e.g. LCMXO2-4000HC-4QN84C
#   E003_SYNTH    lse (Lattice Synthesis Engine) or synplify (Synplify Pro)
#   E003_OUT      project directory, created afresh by the Makefile
#   E003_LPF      preference file
#   E003_SOURCES  VHDL sources, space separated
#
# The project is recreated on every build, so nothing in it is ever edited
# by hand and the build depends only on the files in the repository.

proc env_or_die {name} {
  if {![info exists ::env($name)]} {
    puts stderr "build.tcl: $name is not set; run this through `make build`"
    exit 2
  }
  return $::env($name)
}

set top     [env_or_die E003_TOP]
set device  [env_or_die E003_DEVICE]
set synth   [env_or_die E003_SYNTH]
set out     [env_or_die E003_OUT]
set lpf     [env_or_die E003_LPF]
set sources [env_or_die E003_SOURCES]
set impl    impl1

if {[catch {
  prj_project new -name $top -dir $out -impl $impl -dev $device -synthesis $synth -lpf $lpf
  foreach src $sources {
    prj_src add $src
  }
  prj_impl option top $top
  prj_project save

  puts "=== Synthesis ($synth)"
  prj_run Synthesis -impl $impl
  puts "=== Translate"
  prj_run Translate -impl $impl
  puts "=== Map"
  prj_run Map -impl $impl
  puts "=== Place and route"
  prj_run PAR -impl $impl
  puts "=== Timing analysis"
  prj_run PAR -impl $impl -task PARTrace
  puts "=== Bitstream and JEDEC"
  prj_run Export -impl $impl -task Bitgen
  prj_run Export -impl $impl -task Jedecgen

  prj_project save
  prj_project close
} msg]} {
  puts stderr "build.tcl: Diamond failed: $msg"
  catch {prj_project close}
  exit 1
}

exit 0
