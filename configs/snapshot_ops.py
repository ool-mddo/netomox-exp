import glob
import json
import shutil
import sys
import re
from os import path, makedirs, link


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
        except Exception as err:
            print(
                "Error: cannot read layer1_topology.json in %s with: %s" % (dir_path, err),
                file=sys.stderr,
            )
            sys.exit(1)


def write_l1_topology_data(snapshot_dir_path, edges):
    with open(path.join(snapshot_dir_path, "layer1_topology.json"), "w") as file:
        json.dump({"edges": edges}, file, indent=2)


def snapshot_metadata(index, src_dir_path, dst_dir_path, edges, description):
    return {
        "index": index,
        "lost_edges": edges,
        "original_snapshot_path": src_dir_path,
        "snapshot_path": dst_dir_path,
        "description": description,
    }


def write_snapshot_metadata(dst_dir_path, metadata):
    with open(path.join(dst_dir_path, "snapshot_info.json"), "w") as file:
        json.dump(metadata, file, indent=2)


def deduplicate_edges(edges):
    uniq_edges = []
    for edge in edges:
        if next((e for e in uniq_edges if is_same_edge(e, edge)), None):
            continue
        uniq_edges.append(edge)
    return uniq_edges


def copy_output_files(src_dir_path, dst_dir_path):
    for copy_file in [path.basename(f) for f in glob.glob(path.join(src_dir_path, "*"))]:
        src_file = path.join(src_dir_path, copy_file)
        dst_file = path.join(dst_dir_path, copy_file)
        if path.exists(dst_file):
            print("Warning: dst file: %s already exists" % dst_file, file=sys.stderr)
        else:
            link(src_file, dst_file)  # hard link


def make_output_configs(src_snapshot_dir_path, dst_snapshot_dir_path):
    # configs directory
    copy_dirs = ["configs", "hosts"]
    for copy_dir in copy_dirs:
        src_snapshot_copy_dir_path = path.join(src_snapshot_dir_path, copy_dir)
        dst_snapshot_copy_dir_path = path.join(dst_snapshot_dir_path, copy_dir)
        makedirs(dst_snapshot_copy_dir_path, exist_ok=True)
        # config files
        copy_output_files(src_snapshot_copy_dir_path, dst_snapshot_copy_dir_path)


def edge2tuple(edge):
    return (
        edge["node1"]["hostname"],
        edge["node1"]["interfaceName"],
        edge["node2"]["hostname"],
        edge["node2"]["interfaceName"],
    )


def match_lost_edge(edge, key, node, link_re):
    return edge[key]["hostname"].lower() == node.lower() and re.fullmatch(link_re, edge[key]["interfaceName"])


def draw_off(l1topo, node, link_regexp):
    l1topo_lost = []
    l1topo_found = []
    link_re = r".*"  # default: match all interfaces of target node
    if link_regexp:
        link_re = re.compile(link_regexp, flags=re.IGNORECASE)

    for edge in l1topo["edges"]:
        if match_lost_edge(edge, "node1", node, link_re) or match_lost_edge(edge, "node2", node, link_re):
            l1topo_lost.append(edge)
        else:
            l1topo_found.append(edge)

    return {"lost_edges": l1topo_lost, "found_edges": l1topo_found}


def make_snapshot_dir(
    index,
    input_snapshot_dir_path,
    output_snapshot_base_dir_path,
    output_snapshot_dir_name,
    l1_topology_data,
    node,
    link_re_str,
    description,
    dry_run,
):
    output_snapshot_dir_path = path.join(output_snapshot_base_dir_path, output_snapshot_dir_name)
    output_snapshot_configs_dir_path = path.join(output_snapshot_dir_path, "configs")
    print("# output")
    print("# + snapshot base dir:  %s" % output_snapshot_base_dir_path)
    print("#   + snapshot dir: %s (%s)" % (output_snapshot_dir_path, output_snapshot_dir_name))
    print("#     + snapshot_configs dir: %s" % output_snapshot_configs_dir_path)

    # draw-off layer1 topology data
    l1_topology_data_off = draw_off(l1_topology_data, node, link_re_str)
    metadata = snapshot_metadata(
        index, input_snapshot_dir_path, output_snapshot_dir_path, l1_topology_data_off["lost_edges"], description
    )

    if dry_run:
        for edge in l1_topology_data_off["lost_edges"]:
            print("# DRY_RUN: lost: %s[%s] -> %s[%s]" % edge2tuple(edge))
        return

    # make configs directory and config files in output snap@shot directory
    shutil.rmtree(output_snapshot_dir_path, ignore_errors=True)  # clean
    makedirs(output_snapshot_configs_dir_path, exist_ok=True)  # make dirs recursively
    make_output_configs(input_snapshot_dir_path, output_snapshot_dir_path)
    # write data to layer1_topology.json in output snapshot directory
    write_l1_topology_data(output_snapshot_dir_path, l1_topology_data_off["found_edges"])
    # write metadata
    write_snapshot_metadata(output_snapshot_dir_path, metadata)
