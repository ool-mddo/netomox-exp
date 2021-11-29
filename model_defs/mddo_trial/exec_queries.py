from pybatfish.client.commands import *
from pybatfish.question.question import load_questions
from pybatfish.question import bfq
from os import path, makedirs
import argparse
import json
import pandas as pd


def save_df_as_csv(dataframe, csv_dir, csv_file_name):
    with open(path.join(csv_dir, csv_file_name), 'w') as outfile:
        outfile.write(dataframe.to_csv())


def exec_bf_query(bf_query_dict, snapshot_dir, csv_dir, snapshot_name):
    # load question
    load_questions()
    # init snapshot
    bf_init_snapshot(snapshot_dir, name=snapshot_name)
    # exec query
    for query in bf_query_dict:
        print("# Exec Batfish Query = %s" % query)
        save_df_as_csv(bf_query_dict[query]().answer().frame(), csv_dir, query + '.csv')


def exec_other_query(other_query_dict, snapshot_dir, csv_dir):
    for query in other_query_dict:
        print("# Exec Other Query = %s" % query)
        save_df_as_csv(other_query_dict[query](snapshot_dir), csv_dir, query + '.csv')


def dir_info(config_sub_path, base_dir):
    config_name = config_sub_path.replace('/', '_')
    return {
        'config_name': config_name,
        'config_dir': path.join(base_dir, config_sub_path),  # input
        'csv_dir': path.join('./csv', config_name)  # output
    }


def edges_to_dataframe(edges):
    # hostname will be lower-case in batfish output
    return pd.DataFrame({
        'Interface': map(lambda e: '%s[%s]' % (e['node1']['hostname'].lower(), e['node1']['interfaceName']), edges),
        'Remote_Interface': map(lambda e: '%s[%s]' % (e['node2']['hostname'].lower(), e['node2']['interfaceName']), edges)
    })


def convert_l1topology_to_csv(snapshot_dir):
    l1topology_data = {}
    with open(path.join(snapshot_dir, 'layer1_topology.json'), 'r') as file:
        l1topology_data = json.load(file)
    return edges_to_dataframe(l1topology_data['edges'])


if __name__ == '__main__':
    # print-omit avoidance
    pd.set_option("display.width", 300)
    pd.set_option("display.max_columns", 20)
    pd.set_option("display.max_rows", 200)

    base_dir = '../batfish-test-topology/'
    config_sub_path_list = [
        'l2/sample3',
        'l2/sample4',
        'l2/sample5',
        'l2l3/sample3',
        'l2l3/sample3err2'
    ]

    # for batfish
    bf_query_dict = {
        'ip_owners': lambda: bfq.ipOwners(),
        # 'edges_layer1': lambda: bfq.edges(edgeType='layer1'),
        # 'edges_layer3': lambda: bfq.edges(edgeType='layer3'),
        'interface_props': lambda: bfq.interfaceProperties(nodes='.*', properties=', '.join([
            'VRF', 'Primary_Address', 'Access_VLAN', 'Allowed_VLANs',
            'Switchport', 'Switchport_Mode', 'Channel_Group', 'Channel_Group_Members'
        ])),
        'node_props': lambda: bfq.nodeProperties(nodes='.*', properties=', '.join([
            'Configuration_Format'
        ])),
        'sw_vlan_props': lambda: bfq.switchedVlanProperties(nodes='.*')
    }
    # other data source
    other_query_dict = {
        'edges_layer1': lambda in_dir: convert_l1topology_to_csv(in_dir)
    }

    parser = argparse.ArgumentParser(description='Batfish query exec')
    parser.add_argument('--base', '-b', type=str, default=base_dir, help='Base directory path of configs')
    parser.add_argument('--sub', '-s', type=str, help='Sub-directory path of configs')
    query_keys = list(other_query_dict.keys()) + list(bf_query_dict.keys())
    parser.add_argument('--query', '-q', type=str, choices=query_keys, help='A Query to exec')
    args = parser.parse_args()

    # base directory settings
    base_dir = path.expanduser(args.base if args.base else base_dir)

    # limiting target when using --sub arg
    if args.sub:
        config_sub_path_list = [args.sub]

    # limiting target query when using --query arg
    if args.query:
        bf_query_dict = { args.query: bf_query_dict[args.query] } if args.query in bf_query_dict else {}
        other_query_dict = { args.query: other_query_dict[args.query] } if args.query in other_query_dict else {}

    dirs = map(lambda d: dir_info(d, base_dir), config_sub_path_list)
    for d in dirs:
        makedirs(d['csv_dir'], exist_ok=True)
        # batfish queries
        bool(bf_query_dict) and exec_bf_query(bf_query_dict, d['config_dir'], d['csv_dir'], d['config_name'])
        # other queries
        bool(other_query_dict) and exec_other_query(other_query_dict, d['config_dir'], d['csv_dir'])
