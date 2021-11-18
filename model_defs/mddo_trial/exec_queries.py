from pybatfish.client.commands import *
from pybatfish.question.question import load_questions
from pybatfish.question import bfq
from os import path, makedirs
import argparse
import json
import pandas as pd


def exec_query(query_dict, snapshot_dir, csv_dir, snapshot_name):
    # load question
    load_questions()
    # init snapshot
    bf_init_snapshot(snapshot_dir, name=snapshot_name)
    # exec query
    for query in query_dict:
        print("# Exec Query = %s" % query)
        with open(path.join(csv_dir, query + '.csv'), 'w') as outfile:
            outfile.write(query_dict[query]().answer().frame().to_csv())


def dir_info(config_sub_path, base_dir):
    config_name = config_sub_path.replace('/', '_')
    return {
        'config_name': config_name,
        'config_dir': path.join(base_dir, config_sub_path),  # input
        'csv_dir': path.join('./csv', config_name)  # output
    }

def edges_to_dataframe(edges):
    return pd.DataFrame({
        'Interface': map(lambda e: '%s[%s]' % (e['node1']['hostname'], e['node1']['interfaceName']), edges),
        'Remote_Interface': map(lambda e: '%s[%s]' % (e['node2']['hostname'], e['node2']['interfaceName']), edges)
    })

def convert_l1topology_to_csv(snapshot_dir, csv_dir):
    l1topology_data = {}
    with open(path.join(snapshot_dir, 'layer1_topology.json'), 'r') as file:
        l1topology_data = json.load(file)

    df = edges_to_dataframe(l1topology_data['edges'])
    with open(path.join(csv_dir, 'edges_layer1.csv'), 'w') as file:
        file.write(df.to_csv())

if __name__ == '__main__':
    base_dir = path.expanduser('../batfish-test-topology/')
    config_sub_path_list = [
        'l2/sample3',
        'l2/sample4',
        'l2/sample5',
        'l2l3/sample3',
        'l2l3/sample3err2'
    ]
    query_dict = {
        'ip_owners': lambda: bfq.ipOwners(),
        # 'edges_layer1': lambda: bfq.edges(edgeType='layer1'),
        'edges_layer3': lambda: bfq.edges(edgeType='layer3'),
        'interface_props': lambda: bfq.interfaceProperties(nodes='.*', properties='.*'),
        'node_props': lambda: bfq.nodeProperties(nodes='.*', properties='Configuration_Format, VRFs, Interfaces'),
        'sw_vlan_props': lambda: bfq.switchedVlanProperties(nodes='.*')
    }
    other_queries = ['edges_layer1']

    parser = argparse.ArgumentParser(description='Batfish query exec')
    parser.add_argument('--base', '-b', type=str, default=base_dir, help='Base directory path of configs')
    parser.add_argument('--sub', '-s', type=str, choices=config_sub_path_list, help='Sub-directory path of configs')
    query_keys = other_queries + list(query_dict.keys())
    parser.add_argument('--query', '-q', type=str, choices=query_keys, help='A Query to exec')
    args = parser.parse_args()

    # limiting target when using --sub arg
    if args.sub:
        config_sub_path_list = [args.sub]

    # limiting target query when using --query arg
    if args.query:
        query_dict = { args.query: query_dict[args.query] } if args.query in query_dict else {}
        other_queries = [args.query] if args.query in other_queries else []

    dirs = map(lambda d: dir_info(d, base_dir), config_sub_path_list)
    for d in dirs:
        makedirs(d['csv_dir'], exist_ok=True)
        # batfish questsions
        if bool(query_dict):
            exec_query(query_dict, d['config_dir'], d['csv_dir'], d['config_name'])
        if 'edges_layer1' in other_queries:
            # l1 topology json
            convert_l1topology_to_csv(d['config_dir'], d['csv_dir'])
