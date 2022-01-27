from os import path
import argparse
import glob
import sys
import snapshot_ops as so


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Duplicate snapshots with single physical-linkdown")
    parser.add_argument(
        "--input_snapshot_base",
        "-i",
        required=True,
        type=str,
        help="Input snapshot base directory",
    )
    parser.add_argument(
        "--output_snapshot_base",
        "-o",
        required=True,
        type=str,
        help="Output snapshot(s) base directory",
    )
    parser.add_argument("--node", "-n", default=None, type=str, help="A node name to draw-off")
    parser.add_argument("--link_regexp", "-l", type=str, help="Link name or pattern regexp to draw-off")
    parser.add_argument("--dry_run", action="store_true", default=False, help="Dry-run")
    args = parser.parse_args()

    # input/output snapshot directory construction:
    # + snapshot_base_dir/
    #   + snapshot_dir/
    #     + configs/ (fixed, refer as "snapshot_configs_dir")
    #     - layer1_topology.json (fixed name)

    l1_topology_files = glob.glob(
        "%s/**/layer1_topology.json" % path.expanduser(args.input_snapshot_base), recursive=True
    )
    if len(l1_topology_files) != 1:
        print(
            "# Error: layer1_topology.json not found or found multiple in snapshot directory %s"
            % args.input_snapshot_base,
            file=sys.stderr,
        )
        sys.exit(1)

    input_snapshot_dir_path = path.dirname(l1_topology_files[0])
    input_snapshot_dir_name = path.basename(input_snapshot_dir_path)
    input_snapshot_configs_dir_path = path.join(path.dirname(l1_topology_files[0]), "configs")
    output_snapshot_base_dir_path = path.expanduser(args.output_snapshot_base)
    print("# input")
    print("# + snapshot base dir: %s" % args.input_snapshot_base)
    print("#   + snapshot dir: %s (%s)" % (input_snapshot_configs_dir_path, input_snapshot_dir_name))
    print("#     + snapshot config dir:  %s" % input_snapshot_configs_dir_path)

    # read layer1 topology data
    l1_topology_data = so.read_l1_topology_data(input_snapshot_dir_path)

    # option control
    if args.node is None:
        # deduplicate edges (layer1_topology link definition is bidirectional)
        uniq_edges = so.deduplicate_edges(l1_topology_data["edges"])
        for i, edge in enumerate(uniq_edges):
            index = i + 1  # index number start 1
            so.make_snapshot_dir(
                index,
                input_snapshot_dir_path,
                output_snapshot_base_dir_path,
                "%s_%02d" % (input_snapshot_dir_name, index),
                l1_topology_data,
                edge["node1"]["hostname"],
                edge["node1"]["interfaceName"],
                "No.%02d: " % index + "down %s[%s] <=> %s[%s] in layer1" % so.edge2tuple(edge),
                args.dry_run,
            )
    else:
        so.make_snapshot_dir(
            0,
            input_snapshot_dir_path,
            output_snapshot_base_dir_path,
            input_snapshot_dir_name,
            l1_topology_data,
            args.node,
            args.link_regexp,
            "Draw-off node: %s, link_pattern: %s" % (args.node, args.link_regexp),
            args.dry_run,
        )
