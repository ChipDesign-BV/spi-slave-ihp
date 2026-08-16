#!/usr/bin/env bash
# RTL-to-GDS for spi_slave on the thick-oxide sg13g2_stdcell_hv library.
set -euo pipefail
cd "$(dirname "$0")"

if [[ ! -f ihp_pdk.env ]]; then
  echo "ERROR: copy ihp_pdk.env.example to ihp_pdk.env and set the PDK paths."
  exit 1
fi
source ihp_pdk.env

HV_LIB=$(cd "$(dirname "$0")" && cd ../../sg13g2_stdcell_hv 2>/dev/null && pwd || true)
if [[ -z "$HV_LIB" ]]; then
  echo "ERROR: sg13g2_stdcell_hv not found next to this repository."
  echo "Clone it as a sibling directory; config.yaml resolves it relatively."
  exit 1
fi
echo "=== thick-oxide cells: $HV_LIB ==="

make librelane
echo "=== Flow complete. Outputs in $(pwd)/runs/<RUN_DATE>/final/ ==="
