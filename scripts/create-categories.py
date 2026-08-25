#!/usr/python

import os
import sys
import argparse
import getpass

import requests
from requests.auth import HTTPBasicAuth

def create_category(auth, name, description, parent_pk=None):
    body = {
            "name": name,
            "description": description,
            "parent": parent_pk,
        }

    response = requests.post(url + "/api/part/category/", auth=basic, json=body)
    resp_data = response.json()

    if response.status_code != 201:
        print("ERROR in request, creating category")
        print(resp_data)
        sys.exit(-1)


    print(response.status_code, response.json()['name'])

    
    return resp_data['pk']

def parse_file(filename, auth):
    positions = [-5]
    parents = [None]

    with open(filename) as file_data:
        for line in file_data.readlines():
            position = len(line) - len(line.lstrip(' '))
            line = line.strip()
            if not line:
                continue

            name, description = ([s.strip() for s in line.split("|")] + [""]*2)[:2]


            while position < positions[-1] or (position == positions[-1] and len(positions) > 1):
                positions.pop()
                parents.pop()

            cat_pk = create_category(auth, name, description, parents[-1])

            if position > positions[-1]: # indentated
                parents.append(cat_pk)
                positions.append(position)





if __name__ == "__main__":
    parser = argparse.ArgumentParser(
                    prog='Populate Inventree with Categories',
                    description='Connect to the server, log in, and create categories from given file')

                    
    parser.add_argument('filename')
    parser.add_argument('url')

    args = parser.parse_args()


    url = args.url
    filename = args.filename
    username = input("Username: ")
    password = getpass.getpass("Password: ")

    basic = HTTPBasicAuth(username, password)

    parse_file(filename, basic)