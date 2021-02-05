#!/usr/bin/env python3
import requests
import sys
import csv
import json
from pprint import pprint

def email():
    return 'mmccaffery@qmetric.co.uk'
def apikey():
    with open('.apikey', 'r') as apikey_file:
        return apikey_file.read().replace('\n', '')

# NB not needed: for interest only
# from requests.auth import HTTPBasicAuth
# from base64 import b64encode, b64decode
# def auth_header():
#     raw_header = (email() + ':' + apikey()).encode('utf-8')
#     return 'Basic ' + str(b64encode(raw_header), "utf-8")

EMAIL = email()
PASSWORD = apikey()
RESULTS_PER_PAGE = 50

# Send opff an API request
def retrieve(url: str):
    response = requests.get(url, auth=(EMAIL, PASSWORD))
    if response.status_code != 200:
        raise Exception('Received status ' + str(response.status_code) + ' from ' + url)
    return response.json()

# Send off a series of API requests, incrementing 'start' each time, until they get a 404
def retrieve_all(base_url: str, get_items, simplify_items):
    page = 0
    start = 0
    all_data = []
    while True:
        try:
            url = base_url + '&startAt=' + str(start) + '&maxResults=' + str(RESULTS_PER_PAGE)
            print("Page {} ({}-{}): {}".format(
                page, start, start+50, url), file=sys.stderr)
            response = retrieve(url)
            new_data = get_items(response)
            new_data = [ simplify_items(item) for item in new_data ]
            if (len(new_data) == 0):
                break
            all_data.extend(new_data)
            page = page + 1
            start = start + RESULTS_PER_PAGE
            # if page > 0:
            #     break
        except Exception as e:
            print(e)
            break
    return all_data

# Simplify the dict relating to an issue
def issue_details(details):
    return {
        'id': details['key'],
        'status': details['fields']['status']['name'],
        'priority': details['fields']['priority']['id'],
        'priority_name': details['fields']['priority']['name'],
        'type': details['fields']['issuetype']['name'],
        'assignee': details['fields']['assignee']['displayName']
    }

# Retrieve meaningful details of the given issue
def issue(issue_id):
    details = retrieve('https://policy-expert.atlassian.net/rest/api/2/issue/' + issue_id)
    return issue_details(issue_id)

# Simplify the dict relating to a series of status transitions
def transitions_of(issue_details):
    history = issue_details['changelog']['histories']
    issue_id = issue_details['key']
    status_changes = list(filter(lambda event: event['items'][0]['field'] == 'status', history))
    return list(map(lambda change: {
        'issue': issue_id,
        'from': change['items'][0]['fromString'],
        'to': change['items'][0]['toString'],
        'date': change['created']
    }, status_changes))

# Retrieve meaningful details of all transitions of all issues matching search query
def transitions(jql):
    all_changesets = retrieve_all(
        'https://policy-expert.atlassian.net/rest/api/2/search?jql=' + jql + '&expand=changelog',
        lambda row: row['issues'],
        transitions_of)
    return [ changeset for issue_changesets in all_changesets
        for changeset in issue_changesets]

def write_csv(filename, dataset):
    keys = dataset[0].keys()
    filename = filename + '.csv'
    with open(filename, 'w', newline='') as output_file:
        dict_writer = csv.DictWriter(output_file, keys)
        dict_writer.writeheader()
        dict_writer.writerows(dataset)

def write_json(filename, dataset):
    filename = filename + '.json'
    with open(filename, 'w') as output_file:
        json.dump(dataset, output_file)

# Warning: this will send off an absurd number of API calls
changes = transitions('project=Car&status=Done')
write_csv('transitions', changes)
write_json('transitions', changes)
# pprint(changesets)



# changes = list(filter(lambda changeset: len(changeset), changes))
# pprint(issue('CAR-256'))
# pprint(transitions('key=CAR-256'))
