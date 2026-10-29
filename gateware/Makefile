# e003-adc-board bring-up gateware.
#
#   make sim          simulate (GHDL), prints "tb_e003_top: PASS"
#   make              synthesise, place and route, pack: build/e003_top.bit
#   make detect       check the J-Link sees the FPGA over JTAG
#   make prog         load the bitstream into SRAM (lost at power-off)
#   make prog-flash   write it to the internal flash (kept across power cycles)
#   make clean
#
# Every tool comes from the OSS CAD Suite; see README.md. Override any
# variable on the command line, e.g. `make prog CABLE=ft2232`.

TOP     := e003_top
DEVICE  := LCMXO2-4000HC-4QN84C
LPF     := constraints/$(TOP).lpf
BUILD   := build

GHDL         ?= ghdl
YOSYS        ?= yosys
NEXTPNR      ?= nextpnr-machxo2
ECPPACK      ?= ecppack
OPENFPGALOADER ?= openFPGALoader

# Yosys 0.40 and later. Older releases name the same flow `synth_machxo2`.
SYNTH   ?= synth_lattice -family xo2
# JTAG programmer and its clock. 1 MHz is slow and safe through the
# Tag-Connect cable; raise it once programming is reliable.
CABLE   ?= jlink
JTAG_HZ ?= 1000000

GHDL_FLAGS := --std=08

RTL := \
	rtl/e003_pkg.vhd \
	rtl/host_spi_slave.vhd \
	rtl/adc_spi_master.vhd \
	rtl/adc_ctrl.vhd \
	rtl/clk_meter.vhd \
	rtl/$(TOP).vhd

SIM := \
	sim/osch_sim.vhd \
	sim/adc_model.vhd \
	sim/tb_$(TOP).vhd

# The build's git hash, readable at registers 0x0C to 0x0F. 0 outside git.
GIT_HASH := $(shell git rev-parse --short=7 HEAD 2>/dev/null || echo 0)
BUILD_ID := $(shell printf '%d' 0x$(GIT_HASH))

BIT := $(BUILD)/$(TOP).bit

.PHONY: all sim synth pnr detect prog prog-flash clean

all: $(BIT)

$(BUILD):
	mkdir -p $@

# --- Simulation ------------------------------------------------------------
# Run inside build/sim: GHDL's LLVM and GCC back ends (macOS on Apple
# silicon uses LLVM) write the simulation executable to the working directory.

sim: | $(BUILD)
	mkdir -p $(BUILD)/sim
	cd $(BUILD)/sim && $(GHDL) -a $(GHDL_FLAGS) $(abspath $(RTL) $(SIM))
	cd $(BUILD)/sim && $(GHDL) --elab-run $(GHDL_FLAGS) tb_$(TOP) --wave=tb_$(TOP).ghw

# --- Synthesis -------------------------------------------------------------

synth: $(BUILD)/$(TOP).json

$(BUILD)/$(TOP).json: $(RTL) Makefile | $(BUILD)
	$(YOSYS) -m ghdl -l $(BUILD)/yosys.log -p \
		"ghdl $(GHDL_FLAGS) -gG_BUILD_ID=$(BUILD_ID) $(RTL) -e $(TOP); \
		 $(SYNTH) -top $(TOP) -json $@"

# --- Place and route -------------------------------------------------------

pnr: $(BUILD)/$(TOP).config

$(BUILD)/$(TOP).config: $(BUILD)/$(TOP).json $(LPF)
	$(NEXTPNR) --device $(DEVICE) --json $< --lpf $(LPF) \
		--textcfg $@ --log $(BUILD)/nextpnr.log --report $(BUILD)/report.json

# --- Bitstream -------------------------------------------------------------

$(BIT): $(BUILD)/$(TOP).config
	$(ECPPACK) $< $@
	@echo "Built $@ (build ID 0x$(GIT_HASH))"

# --- Programming over JTAG -------------------------------------------------

detect:
	$(OPENFPGALOADER) -c $(CABLE) --freq $(JTAG_HZ) --detect

prog: $(BIT)
	$(OPENFPGALOADER) -c $(CABLE) --freq $(JTAG_HZ) $(BIT)

prog-flash: $(BIT)
	$(OPENFPGALOADER) -c $(CABLE) --freq $(JTAG_HZ) -f $(BIT)

clean:
	rm -rf $(BUILD)
