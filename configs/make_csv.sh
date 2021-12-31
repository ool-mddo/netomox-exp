#!/usr/bin/env bash

BF_TEST_BASE_DIR="batfish-test-topology"
BF_TEST_SUB_DIRS=(
  "$BF_TEST_BASE_DIR/l2/sample3"
  "$BF_TEST_BASE_DIR/l2/sample4"
  "$BF_TEST_BASE_DIR/l2/sample5"
  "$BF_TEST_BASE_DIR/l2l3/sample3"
  "$BF_TEST_BASE_DIR/l2l3/sample3err2"
)

echo "# Config dir: $BF_TEST_BASE_DIR"
python exec_queries.py -s "${BF_TEST_SUB_DIRS[@]}" -o ../models

MDDO_BASE_DIR="pushed_configs"
MDDO_SUB_DIRS=(
  "$MDDO_BASE_DIR/mddo_network"
)

echo "# Config dir : $MDDO_BASE_DIR"
python exec_queries.py -s "${MDDO_SUB_DIRS[@]}" -o ../models
