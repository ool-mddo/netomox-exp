#!/usr/bin/env bash

MDDO_BASE_DIR="${HOME}/ool-mddo"
CONFIG_DIR_NAME="pushed_configs"
CONFIG_DIR="${MDDO_BASE_DIR}/${CONFIG_DIR_NAME}"
L1_TOPOLOGY_FILE="${MDDO_BASE_DIR}/netbox2inet-henge/layer1_topology.sample.json"

echo "# Config dir : $CONFIG_DIR"
echo "# L1 topo file : $L1_TOPOLOGY_FILE"
cp "${L1_TOPOLOGY_FILE}" "${CONFIG_DIR}/layer1_topology.json"
python exec_queries.py -b "$MDDO_BASE_DIR" -s ${CONFIG_DIR_NAME}
