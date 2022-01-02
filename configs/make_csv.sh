#!/usr/bin/env bash
set -euo pipefail

# origin is the directory which owns this script
cd "$(dirname "$0")"

# output directory (to put csv files, results of parsing snapshots)
MODELS_DIR="../models"

function usage() {
  echo "Usage: $0 [TARGETS]"
  echo "  TARGETS"
  echo "    - bftest  : Batfish l2/l3 test pattern"
  echo "    - mddo    : MDDO network"
  echo "    - mddo_ld : MDDO network (single link-down pattern)"
  echo "    - all"
}

USE_BF_TEST=false
USE_MDDO=false
USE_MDDO_LD=false

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

for target in "$@"; do
  case $target in
    "bftest")
      USE_BF_TEST=true
      ;;
    "mddo")
      USE_MDDO=true
      ;;
    "mddo_ld")
      USE_MDDO_LD=true
      ;;
    "all")
      USE_BF_TEST=true
      USE_MDDO=true
      USE_MDDO_LD=true
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

# batfish-test-topology: for L2/L3 simple test pattern
if "$USE_BF_TEST"; then
  BF_TEST_BASE_DIR="batfish-test-topology"
  BF_TEST_SUB_DIRS=(
    "$BF_TEST_BASE_DIR/l2/sample3"
    "$BF_TEST_BASE_DIR/l2/sample4"
    "$BF_TEST_BASE_DIR/l2/sample5"
    "$BF_TEST_BASE_DIR/l2l3/sample3"
    "$BF_TEST_BASE_DIR/l2l3/sample3err2"
  )

  echo "# Config dir: $BF_TEST_BASE_DIR"
  python exec_queries.py -s "${BF_TEST_SUB_DIRS[@]}" -o "$MODELS_DIR"
fi

# MDDO network
MDDO_BASE_DIR="pushed_configs"
MDDO_SUB_DIRS=(
  "$MDDO_BASE_DIR/mddo_network"
)
if "$USE_MDDO"; then
  echo "# Config dir : $MDDO_BASE_DIR"
  python exec_queries.py -s "${MDDO_SUB_DIRS[@]}" -o "$MODELS_DIR"
fi

# MDDO network (with single link down patterns)
if "$USE_MDDO_LD"; then
  MDDO_SRC_DIR=${MDDO_SUB_DIRS[0]}
  MDDO_LINKDOWN_BASE_DIR="pushed_configs_linkdown"

  ## generate link-down patterns (snapshots)
  echo "# Source snapshots dir : $MDDO_SRC_DIR"
  echo "# Destination snapshots dir : $MDDO_LINKDOWN_BASE_DIR"

  # clean output directory to put linkdown snapshots
  if [ -d "$MDDO_LINKDOWN_BASE_DIR" ]; then
    rm -rf "${MDDO_LINKDOWN_BASE_DIR:?}"
  fi
  python make_linkdown_snapshots.py -s "$MDDO_SRC_DIR" -o "$MDDO_LINKDOWN_BASE_DIR"

  ## parse snapshots
  MDDO_LINKDOWN_SUB_DIRS=()
  for dir in $(find $MDDO_LINKDOWN_BASE_DIR -maxdepth 1 -type d | sed -e '1d' | sort); do
    MDDO_LINKDOWN_SUB_DIRS+=("$dir")
  done

  echo "# Config dir : $MDDO_LINKDOWN_BASE_DIR"

  ## clean output directory to put normalized csv data from each snapshots
  if [ -d "${MODELS_DIR}/${MDDO_LINKDOWN_BASE_DIR}" ]; then
    rm -rf "${MODELS_DIR:?}/${MDDO_LINKDOWN_BASE_DIR:?}"
  fi
  python exec_queries.py -s "${MDDO_LINKDOWN_SUB_DIRS[@]}" -o "$MODELS_DIR"

  ## copy snapshot info
  for subdir in "${MDDO_LINKDOWN_SUB_DIRS[@]}"; do
    cp "$subdir/snapshot_info.json" "$MODELS_DIR/$subdir"
  done
fi
