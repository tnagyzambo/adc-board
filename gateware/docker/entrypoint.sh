#!/usr/bin/env bash
# Container entry point: puts Diamond on the PATH the way Lattice's own
# diamond_env script does, then runs the command it was given.

bindir="$DIAMOND_DIR/bin/lin64"
export bindir

# diamond_env points LM_LICENSE_FILE at Diamond's own license/ directory,
# which is empty here; keep the licence that docker/run mounted instead.
mounted_license=${LM_LICENSE_FILE:-}
if [ -f "$bindir/diamond_env" ]; then
  # shellcheck disable=SC1091
  source "$bindir/diamond_env" >/dev/null 2>&1 || true
fi
if [ -n "$mounted_license" ]; then
  export LM_LICENSE_FILE=$mounted_license
else
  unset LM_LICENSE_FILE
fi

export FOUNDRY="${FOUNDRY:-$DIAMOND_DIR/ispfpga}"
export PATH="$bindir:$DIAMOND_DIR/ispfpga/bin/lin64:$PATH"
export LD_LIBRARY_PATH="$bindir:$DIAMOND_DIR/ispfpga/bin/lin64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

if [ -z "${LM_LICENSE_FILE:-}" ]; then
  echo "e003: no Diamond licence mounted; simulation works, Diamond builds will not" >&2
elif [ ! -r "$LM_LICENSE_FILE" ]; then
  echo "e003: Diamond licence $LM_LICENSE_FILE is not readable in the container" >&2
fi

exec "$@"
