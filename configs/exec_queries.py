import argparse
import json
import logging
import shutil
import sys
from os import path, makedirs
import pandas as pd
from pybatfish.client.session import Session


def save_df_as_csv(dataframe, csv_dir, csv_file_name):
    with open(path.join(csv_dir, csv_file_name), "w") as outfile:
        outfile.write(dataframe.to_csv())


def copy_snapshot_info(snapshot_dir, csv_dir):
    snapshot_info_name = "snapshot_info.json"
    snapshot_info_path = path.join(snapshot_dir, snapshot_info_name)
    if not path.exists(snapshot_info_path):
        return

    print("# Found %s, copy it to %s" % (snapshot_info_path, csv_dir))
    shutil.copyfile(snapshot_info_path, path.join(csv_dir, snapshot_info_name))


def exec_bf_query(bf_session, snapshot_name, query_dict, csv_dir):
    bf_session.set_snapshot(snapshot_name)
    # exec query
    for query in query_dict:
        print("# Exec Batfish Query = %s" % query)
        save_df_as_csv(query_dict[query](bf_session).answer().frame(), csv_dir, query + ".csv")


def snapshot_path(configs_dir, network_name, snapshot_name):
    return path.join(configs_dir, network_name, *snapshot_name.split("__"))


def exec_other_query(query_dict, snapshot_dir, csv_dir):
    for query in query_dict:
        print("# Exec Other Query = %s" % query)
        save_df_as_csv(query_dict[query](snapshot_dir), csv_dir, query + ".csv")


def edges_to_dataframe(edges):
    # hostname will be lower-case in batfish output
    return pd.DataFrame(
        {
            "Interface": map(
                lambda e: "%s[%s]" % (e["node1"]["hostname"].lower(), e["node1"]["interfaceName"]),
                edges,
            ),
            "Remote_Interface": map(
                lambda e: "%s[%s]" % (e["node2"]["hostname"].lower(), e["node2"]["interfaceName"]),
                edges,
            ),
        }
    )


def convert_l1topology_to_csv(snapshot_dir):
    with open(path.join(snapshot_dir, "layer1_topology.json"), "r") as file:
        l1topology_data = json.load(file)
    return edges_to_dataframe(l1topology_data["edges"])


if __name__ == "__main__":
    # print-omit avoidance
    pd.set_option("display.width", 300)
    pd.set_option("display.max_columns", 20)
    pd.set_option("display.max_rows", 200)
    # for batfish
    bf_query_dict = {
        "ip_owners": lambda bf: bf.q.ipOwners(),
        # 'edges_layer1': lambda: bfq.edges(edgeType='layer1'),
        # 'edges_layer3': lambda: bfq.edges(edgeType='layer3'),
        "interface_props": lambda bf: bf.q.interfaceProperties(
            nodes=".*",
            properties=", ".join(
                [
                    "VRF",
                    "Primary_Address",
                    "Access_VLAN",
                    "Allowed_VLANs",
                    "Switchport",
                    "Switchport_Mode",
                    "Switchport_Trunk_Encapsulation",
                    "Channel_Group",
                    "Channel_Group_Members",
                    "Description",
                ]
            ),
        ),
        "node_props": lambda bf: bf.q.nodeProperties(nodes=".*", properties=", ".join(["Configuration_Format"])),
        "sw_vlan_props": lambda bf: bf.q.switchedVlanProperties(nodes=".*"),
    }
    # other data source
    other_query_dict = {"edges_layer1": lambda in_dir: convert_l1topology_to_csv(in_dir)}

    # parse command line arguments
    parser = argparse.ArgumentParser(description="Batfish query exec")
    parser.add_argument("--batfish", "-b", type=str, default="localhost", help="batfish address")
    parser.add_argument("--network", "-n", default=None, type=str, help="Specify a target network name")
    parser.add_argument("--configs_dir", "-c", default="configs", help="Configs directory for network snapshots")
    parser.add_argument("--models_dir", "-m", default="models", help="Models directory to batfish output CSVs")
    query_keys = list(other_query_dict.keys()) + list(bf_query_dict.keys())
    parser.add_argument("--query", "-q", type=str, choices=query_keys, help="A Query to exec")
    log_levels = ["critical", "error", "warning", "info", "debug"]
    parser.add_argument("--log_level", type=str, default="warning", choices=log_levels, help="Log level")
    parser.add_argument("--debug", action="store_true", default=False, help="Debug")
    args = parser.parse_args()

    # set log level
    logger = logging.getLogger("pybatfish")
    if args.log_level == "critical":
        logger.setLevel(logging.CRITICAL)
    elif args.log_level == "error":
        logger.setLevel(logging.ERROR)
    elif args.log_level == "warning":
        logger.setLevel(logging.WARNING)
    elif args.log_level == "info":
        logger.setLevel(logging.INFO)
    else:
        logger.setLevel(logging.DEBUG)

    # limiting target query when using --query arg
    if args.query:
        bf_query_dict = {args.query: bf_query_dict[args.query]} if args.query in bf_query_dict else {}
        other_query_dict = {args.query: other_query_dict[args.query]} if args.query in other_query_dict else {}

    # batfish session definition
    bf = Session(host=args.batfish)

    networks = []
    if args.network:
        networks = list(filter(lambda n: n == args.network, bf.list_networks()))
    else:
        networks = bf.list_networks()

    if not networks:
        if args.network:
            print("Error: Network %s not found in batfish" % (args.network if args.network else None), file=sys.stderr)
        else:
            print("Warning: batfish does not have networks", file=sys.stderr)

    for network in networks:
        bf.set_network(network)
        for snapshot in sorted(bf.list_snapshots()):
            input_dir = snapshot_path(args.configs_dir, network, snapshot)
            output_dir = snapshot_path(args.models_dir, network, snapshot)
            print("# * network/snapshot   : %s / %s" % (network, snapshot))
            print("#   input snapshot dir : %s" % input_dir)
            print("#   output csv     dir : %s" % output_dir)
            makedirs(output_dir, exist_ok=True)
            exec_bf_query(bf, snapshot, bf_query_dict, output_dir)
            exec_other_query(other_query_dict, input_dir, output_dir)
            copy_snapshot_info(input_dir, output_dir)
