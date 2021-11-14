from pybatfish.client.commands import *
from pybatfish.question.question import load_questions
from pybatfish.question import bfq
from os import path, makedirs


def exec_query(snapshot_dir, snapshot_name, csv_dir):
    # load question
    load_questions()
    # init snapshot
    bf_init_snapshot(snapshot_dir, name=snapshot_name)
    # query
    queries = {
        'ip_owners': lambda: bfq.ipOwners(),
        'edges_layer1': lambda: bfq.edges(edgeType='layer1'),
        'edges_layer3': lambda: bfq.edges(edgeType='layer3'),
        'interface_props': lambda: bfq.interfaceProperties(nodes='.*', properties='.*'),
        'node_props': lambda: bfq.nodeProperties(nodes='.*', properties='Configuration_Format, VRFs, Interfaces'),
        'sw_vlan_props': lambda: bfq.switchedVlanProperties(nodes='.*')
    }
    # exec query
    for query in queries:
        print("# Exec Query = %s" % query)
        with open(path.join(csv_dir, query + '.csv'), 'w') as outfile:
            outfile.write(queries[query]().answer().frame().to_csv())


def dir_info(config_sub_path):
    base_dir = path.expanduser('../batfish-test-topology/')
    config_name = config_sub_path.replace('/', '_')
    return {
        'config_name': config_name,
        'config_dir': path.join(base_dir, config_sub_path),
        'csv_dir': path.join('./csv', config_name)
    }


if __name__ == '__main__':
    config_sub_path_list = [
        'l2/sample3',
        'l2/sample4',
        'l2/sample5',
        'l2l3/sample3'
    ]
    dirs = map(lambda d: dir_info(d), config_sub_path_list)
    for d in dirs:
        makedirs(d['csv_dir'], exist_ok=True)
        exec_query(d['config_dir'], d['config_name'], d['csv_dir'])
