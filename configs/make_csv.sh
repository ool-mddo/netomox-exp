#!/usr/bin/env bash
set -euo pipefail

# origin is the directory which owns this script
cd "$(dirname "$0")"

# output directory (to put csv files, results of parsing snapshots)
MODELS_DIR="../models"


# batfish-test-topology: for L2/L3 simple test pattern

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


# MDDO network

MDDO_BASE_DIR="pushed_configs"
MDDO_SUB_DIRS=(
  "$MDDO_BASE_DIR/mddo_network"
)

echo "# Config dir : $MDDO_BASE_DIR"
python exec_queries.py -s "${MDDO_SUB_DIRS[@]}" -o "$MODELS_DIR"


# MDDO network (with single link down patterns)

MDDO_SRC_DIR=${MDDO_SUB_DIRS[0]}
MDDO_LINKDOWN_BASE_DIR="pushed_configs_linkdown"

## generate link-down patterns (snapshots)
echo "# Linkdown snapshots dir : $MDDO_LINKDOWN_BASE_DIR"
if [ -d "$MDDO_LINKDOWN_BASE_DIR" ]; then
  rm -rf "${MDDO_LINKDOWN_BASE_DIR:?}"
fi
python make_linkdown_patterns.py -s "$MDDO_SRC_DIR" -o "$MDDO_LINKDOWN_BASE_DIR"

## parse snapshots
MDDO_LINKDOWN_SUB_DIRS=()
for dir in $(find $MDDO_LINKDOWN_BASE_DIR -maxdepth 1 -type d | sed -e '1d'); do
  MDDO_LINKDOWN_SUB_DIRS+=("$dir")
done

echo "# Config dir : $MDDO_LINKDOWN_BASE_DIR"
if [ -d "${MODELS_DIR}/${MDDO_LINKDOWN_BASE_DIR}" ]; then
  rm -rf "${MODELS_DIR:?}/${MDDO_LINKDOWN_BASE_DIR:?}"
fi
python exec_queries.py -s "${MDDO_LINKDOWN_SUB_DIRS[@]}" -o "$MODELS_DIR"
