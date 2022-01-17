from pybatfish.client.session import Session
from os import path
import argparse
import glob
import re


def find_all_l1topology_files(input_dir):
    return sorted(glob.glob("%s/**/layer1_topology.json" % input_dir, recursive=True))


def dir_info(input_snapshot_base_dir, input_snapshot_dir):
    input_snapshot_base_name = path.basename(input_snapshot_base_dir)
    if re.match(".*/$", input_snapshot_base_dir):
        input_snapshot_base_name = path.basename(path.dirname(input_snapshot_base_dir))

    # pick path string follows input_snapshot_base_name
    m = re.search("%s/(.*)" % input_snapshot_base_name, input_snapshot_dir)
    input_snapshot_name = m.group(1)

    return {
        # used as snapshot name: snapshot name cannot contain '/'
        "config_name": input_snapshot_name.replace("/", "__"),
        "config_dir": path.expanduser(input_snapshot_dir),  # input dir
    }


def delete_network_if_exists(bf_session, network_name):
    if next(filter(lambda n: n == network_name, bf_session.list_networks()), None):
        print("# Found network %s in batfish, delete it." % network_name)
        bf_session.delete_network(network_name)


def register_snapshots(bf_session, snapshot_name, snapshot_dir):
    print("# - network name: %s" % snapshot_name)
    print("#   input snapshot dir: %s" % snapshot_dir)
    bf_session.init_snapshot(snapshot_dir, name=snapshot_name, overwrite=True)


if __name__ == "__main__":
    # parse command line arguments
    parser = argparse.ArgumentParser(description="Batfish query exec")
    parser.add_argument("--batfish", "-b", type=str, default="localhost", help="batfish address")
    parser.add_argument(
        "--network", "-n", required=True, type=str, default="default_network", help="Network name of snapshots"
    )
    parser.add_argument("--input_snapshot_base", "-i", required=True, type=str, help="Input snapshot base directory")
    args = parser.parse_args()

    # batfish session definition
    bf = Session(host=args.batfish)
    delete_network_if_exists(bf, args.network)
    bf.set_network(args.network)

    dirs = list(
        map(
            lambda l1tf: dir_info(args.input_snapshot_base, path.dirname(l1tf)),
            find_all_l1topology_files(args.input_snapshot_base),
        )
    )
    for d in dirs:
        register_snapshots(bf, d["config_name"], d["config_dir"])
