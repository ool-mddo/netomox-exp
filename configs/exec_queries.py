from pybatfish.client.session import Session
from pybatfish.question.question import load_questions
from os import path, makedirs
import argparse
import json
import pandas as pd


def save_df_as_csv(dataframe, csv_dir, csv_file_name):
    with open(path.join(csv_dir, csv_file_name), "w") as outfile:
        outfile.write(dataframe.to_csv())


def exec_bf_query(bf_session, query_dict, snapshot_dir, csv_dir, snapshot_name):
    # load question
    load_questions( session=bf_session)
    # init snapshot
    bf_session.init_snapshot(snapshot_dir, name=snapshot_name, overwrite=True)
    # exec query
    for query in query_dict:
        print("# Exec Batfish Query = %s" % query)
        save_df_as_csv(query_dict[query](bf_session).answer().frame(), csv_dir, query + ".csv")


def exec_other_query(query_dict, snapshot_dir, csv_dir):
    for query in query_dict:
        print("# Exec Other Query = %s" % query)
        save_df_as_csv(query_dict[query](snapshot_dir), csv_dir, query + ".csv")


def dir_info(snapshot_dir, output_dir):
    # snapshot name cannot contain '/'
    config_name = snapshot_dir.replace("/", "_")
    return {
        "config_name": config_name,  # used as snapshot name
        "config_dir": path.expanduser(snapshot_dir),  # input dir
        "csv_dir": path.expanduser(path.join(output_dir, snapshot_dir)),  # output dir
    }


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
    l1topology_data = {}
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
    parser.add_argument(
        "--network", "-n", required=True, type=str, default="default_network", help="Network name of snapshots"
    )
    parser.add_argument(
        "--snapshots",
        "-s",
        required=True,
        type=str,
        nargs="*",
        help="Snapshot directory path(s) of configs",
    )
    parser.add_argument("--output", "-o", default="./", help="Outpu directory of csv data")
    query_keys = list(other_query_dict.keys()) + list(bf_query_dict.keys())
    parser.add_argument("--query", "-q", type=str, choices=query_keys, help="A Query to exec")
    args = parser.parse_args()

    # limiting target query when using --query arg
    if args.query:
        bf_query_dict = {args.query: bf_query_dict[args.query]} if args.query in bf_query_dict else {}
        other_query_dict = {args.query: other_query_dict[args.query]} if args.query in other_query_dict else {}

    # batfish session definition
    print ("debug: " + str(args.batfish))
    bf = Session(host=args.batfish)
    bf.set_network(args.network)
    dirs = list(map(lambda p: dir_info(p, args.output), sorted(args.snapshots)))

    # exec query
    for d in dirs:
        makedirs(d["csv_dir"], exist_ok=True)
        # batfish queries
        bool(bf_query_dict) and exec_bf_query(bf, bf_query_dict, d["config_dir"], d["csv_dir"], d["config_name"])
        # other queries
        bool(other_query_dict) and exec_other_query(other_query_dict, d["config_dir"], d["csv_dir"])
