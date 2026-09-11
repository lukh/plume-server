#!/usr/python

import os
from pathlib import Path
import sys
import argparse
import getpass
import collections


def tree(fd, path: Path, prefix=""):
    entries = sorted(path.iterdir())

    for i, entry in enumerate(entries):

        if entry.is_dir():
            if entry.name in ['.svn', 'branches', "tags", "exports", "releases"]:
                continue

            if entry.name == "trunk":
                tree(fd, entry, prefix)
            else:
                print(prefix + entry.name)
                fd.write(prefix + entry.name + "\n")
                tree(fd, entry, prefix + " ")




if __name__ == "__main__":
    parser = argparse.ArgumentParser(
                    prog='Generate a categories.txt file from a WC',
                    description='')

                    
    parser.add_argument('WC')
    parser.add_argument('output')

    args = parser.parse_args()
    
    wc = Path(args.WC).resolve()
    with open(args.output, "w") as fd:
        tree(fd, wc)

