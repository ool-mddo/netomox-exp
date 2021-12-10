#!/usr/bin/env bash

BF_TEST_BASE_DIR='../batfish-test-topology/'
BF_TEST_SUB_DIRS=( 'l2/sample3' 'l2/sample4' 'l2/sample5' 'l2l3/sample3' 'l2l3/sample3err2')

MDDO_BASE_DIR="${HOME}/ool-mddo"
MDDO_SUB_DIR="pushed_configs"
MDDO_CONFIG_DIR="${MDDO_BASE_DIR}/${MDDO_SUB_DIR}"
L1_TOPOLOGY_FILE="${MDDO_BASE_DIR}/netbox2inet-henge/layer1_topology.sample.json"

echo "# Config dir: $BF_TEST_BASE_DIR"
python exec_queries.py -b "$BF_TEST_BASE_DIR" -s "${BF_TEST_SUB_DIRS[@]}"

echo "# Config dir : $MDDO_CONFIG_DIR"
echo "# L1 topo file : $L1_TOPOLOGY_FILE"
cp "$L1_TOPOLOGY_FILE" "${MDDO_CONFIG_DIR}/layer1_topology.json"
python exec_queries.py -b "$MDDO_BASE_DIR" -s "$MDDO_SUB_DIR"
