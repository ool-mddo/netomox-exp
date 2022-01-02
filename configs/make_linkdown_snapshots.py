from os import path, makedirs, link
import argparse
import glob
import json
import sys


def revers_edge(edge):
    return {"node1": edge["node2"], "node2": edge["node1"]}


def is_same_edge(edge1, edge2):
    # NOTE: simple dictionary comparison
    # probably, the comparison condition are too strict.
    # Be careful if you have mixed interface expression (long/short name, upper/lower case)
    # It might be better to use "DeepDiff" (ignore-case compare etc)
    return edge1 == edge2 or revers_edge(edge1) == edge2


def read_l1_topology_data(dir_path):
    with open(path.join(dir_path, "layer1_topology.json"), "r") as file:
        try:
            return json.load(file)
        except Exception as e:
            print(
                "Error: cannot read layer1_topology.json in %s with: %s" % (dir_path, e),
                file=sys.stderr,
            )
            sys.exit(1)


def write_l1_topology_data(snapshot_dir_path, edges):
    with open(path.join(snapshot_dir_path, "layer1_topology.json"), "w") as file:
        json.dump({"edges": edges}, file, indent=2)


def write_snapshot_metadata(src_dir_path, dst_dir_path, index, edge):
    metadata = {
        "index": index,
        "target_links": [edge, revers_edge(edge)],
        "original_snapshot_path": src_dir_path,
        "snapshot_path": dst_dir_path,
        "description": "No.%02d: down %s[%s] <=> %s[%s] in layer1"
        % (
            index,
            edge["node1"]["hostname"],
            edge["node1"]["interfaceName"],
            edge["node2"]["hostname"],
            edge["node2"]["interfaceName"],
        ),
    }
    with open(path.join(dst_dir_path, "snapshot_info.json"), "w") as file:
        json.dump(metadata, file, indent=2)


def deduplicate_edges(edges):
    uniq_edges = []
    for edge in edges:
        if next((e for e in uniq_edges if is_same_edge(e, edge)), None):
            continue
        uniq_edges.append(edge)
    return uniq_edges


def make_output_configs(src_snapshot_configs_dir_path, dst_snapshot_dir_path, config_files):
    # configs directory
    dst_snapshot_configs_dir_path = path.join(dst_snapshot_dir_path, "configs")
    makedirs(dst_snapshot_configs_dir_path, exist_ok=True)
    # config files
    for config_file in config_files:
        src_file = path.join(src_snapshot_configs_dir_path, config_file)
        dst_file = path.join(dst_snapshot_configs_dir_path, config_file)
        if path.exists(dst_file):
            print("Warning: dst file: %s already exists" % dst_file, file=sys.stderr)
        else:
            link(src_file, dst_file)  # hard link


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Duplicate snapshots with single physical-linkdown")
    parser.add_argument(
        "--snapshot",
        "-s",
        required=True,
        type=str,
        help="Origin snapshot directory path of configs",
    )
    parser.add_argument(
        "--output",
        "-o",
        required=True,
        type=str,
        help="Base directory name of output snapshots",
    )
    args = parser.parse_args()

    # input/output snapshot directory construction:
    # + snapshot_base_dir/
    #   + snapshot_dir/
    #     + configs/ (fixed, refer as "snapshot_configs_dir")
    #     - layer1_topology.json (fixed name)
    input_snapshot_dir_path = path.expanduser(args.snapshot)
    input_snapshot_dir_name = path.basename(args.snapshot)
    input_snapshot_configs_dir_path = path.join(input_snapshot_dir_path, "configs")
    output_snapshot_base_dir_path = path.expanduser(args.output)

    # read layer1 topology data
    l1_topology_data = read_l1_topology_data(input_snapshot_dir_path)

    # deduplicate edges (layer1_topology link definition is bidirectional)
    uniq_edges = deduplicate_edges(l1_topology_data["edges"])

    # list config files in input snapshot directory
    config_files = [path.basename(f) for f in glob.glob(path.join(input_snapshot_configs_dir_path, "*"))]

    # make outputs
    makedirs(output_snapshot_base_dir_path, exist_ok=True)
    for i, edge in enumerate(uniq_edges):
        # index number start 1
        index = i + 1

        # output directory defs
        output_snapshot_dir_name = "%s_%02d" % (input_snapshot_dir_name, index)
        output_snapshot_dir_path = path.join(output_snapshot_base_dir_path, output_snapshot_dir_name)
        makedirs(output_snapshot_dir_path, exist_ok=True)

        # make configs directory and config files in output snap@shot directory
        make_output_configs(input_snapshot_configs_dir_path, output_snapshot_dir_path, config_files)

        # remove a link as "down link"
        edges_without_target = list(filter(lambda e: not is_same_edge(e, edge), l1_topology_data["edges"]))
        # write data to layer1_topology.json in output snapshot directory
        write_l1_topology_data(output_snapshot_dir_path, edges_without_target)
        # write metadata
        write_snapshot_metadata(input_snapshot_dir_path, output_snapshot_dir_path, index, edge)
