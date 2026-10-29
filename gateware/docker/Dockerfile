# syntax=docker/dockerfile:1
#
# e003-adc-board gateware build image: Lattice Diamond for synthesis through
# bitstream, GHDL for simulation, make and git to drive them.
#
# Diamond is x86-64 Linux software, so the image is linux/amd64; on Apple
# silicon Docker Desktop runs it under Rosetta. Diamond's licence does not
# allow it to be redistributed, so the image is built locally from your own
# copy of the installer and must never be pushed to a public registry.
#
# Build it with `make image` from gateware/, after placing the Diamond for
# Linux installer (.run or .rpm) in gateware/docker/installer/ (see
# gateware/README.md).

FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# Build tools, GHDL, the RPM extractor, and the X, font and GL libraries that
# Diamond's binaries link against even when run without a display.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates bash make git python3 \
      ghdl \
      rpm2cpio cpio \
      libx11-6 libxext6 libxft2 libxrender1 libxt6 libsm6 libice6 \
      libxi6 libxrandr2 libxcursor1 libxinerama1 libxkbcommon0 \
      libfontconfig1 libfreetype6 libglib2.0-0 libgl1 libglu1-mesa \
      libncurses5 libtinfo5 libusb-0.1-4 libusb-1.0-0 \
 && rm -rf /var/lib/apt/lists/*

# Diamond itself, from the installer in gateware/docker/installer/: the .run of
# 3.14 or the .rpm of earlier releases (see install-diamond.sh). The installer
# is bind-mounted for this step only, so its several GB never land in an
# image layer. Whatever version it is, /opt/diamond points at it.
COPY install-diamond.sh /usr/local/bin/install-diamond
RUN --mount=type=bind,source=installer,target=/mnt/installer \
    bash /usr/local/bin/install-diamond /mnt/installer \
 && test -x /opt/diamond/bin/lin64/pnmainc

# FlexLM, which Diamond uses for its licence check, keeps state in /usr/tmp
# and some of its binaries ask for the LSB loader name.
RUN mkdir -p /usr/tmp && chmod 1777 /usr/tmp \
 && ln -sf /lib64/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3

# List any library Diamond's main binaries cannot find. This only warns: not
# every library a binary links is used by a batch build. If `make build`
# fails with "error while loading shared libraries", add the package here.
RUN for f in /opt/diamond/bin/lin64/pnmainc /opt/diamond/bin/lin64/synthesis \
             /opt/diamond/ispfpga/bin/lin64/map /opt/diamond/ispfpga/bin/lin64/par \
             /opt/diamond/ispfpga/bin/lin64/bitgen; do \
      [ -e "$f" ] || continue; \
      LD_LIBRARY_PATH=/opt/diamond/bin/lin64:/opt/diamond/ispfpga/bin/lin64 ldd "$f" \
        | sed -n "s|^\s*\(.*not found\)|$(basename "$f"): \1|p"; \
    done | sort -u | sed 's/^/warning: /'

# The repository is bind-mounted with a different owner; let git read it for
# the build ID.
RUN git config --system --add safe.directory '*'

ENV DIAMOND_DIR=/opt/diamond \
    E003_IN_CONTAINER=1 \
    QT_QPA_PLATFORM=offscreen

COPY entrypoint.sh /usr/local/bin/e003-entrypoint
RUN chmod 755 /usr/local/bin/e003-entrypoint

ENTRYPOINT ["/usr/local/bin/e003-entrypoint"]
CMD ["bash"]
