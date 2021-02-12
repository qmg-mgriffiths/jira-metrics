#!/usr/bin/env python3
import requests
import sys
import csv
import json
from pprint import pprint
from urllib.parse import urlencode

def config(name: str):
    with open('.' + name, 'r') as config_file:
        return config_file.read().replace('\n', '')

ESTIMATE_FIELDS = ['customfield_10026', 'customfield_10016']

EMAIL = config('email')
PASSWORD = config('apikey')
PROJECT = config('project')
BOARD = config('board')
JIRA = config('jira-url').rstrip('/')
RESULTS_PER_PAGE = 50

# Debug only: run only one API call per query type, even if multiple would be needed.
LIMIT_API_CALLS = False

# Send off an API request
def retrieve(url: str):
    response = requests.get(JIRA + url, auth=(EMAIL, PASSWORD))
    if response.status_code != 200:
        raise Exception('Received status ' + str(response.status_code) + ' from ' + JIRA + url)
    return response.json()

# Send off a series of API requests, incrementing 'start' each time, until they return nothing
def retrieve_all(base_url: str, get_items, simplify_items):
    page = 0
    start = 0
    all_data = []
    while True:
        try:
            url = base_url + '&startAt=' + str(start) + '&maxResults=' + str(RESULTS_PER_PAGE)
            print("Page {} ({}-{}): {}{}".format(
                page, start, start + RESULTS_PER_PAGE, JIRA, url), file=sys.stderr)
            response = retrieve(url)
            new_data = get_items(response)
            new_data = [ simplify_items(item) for item in new_data ]
            total_results = response['total'] if 'total' in response else None
            if (len(new_data) == 0):
                break
            all_data.extend(new_data)
            if total_results is not None and total_results < start + RESULTS_PER_PAGE:
                break
            page = page + 1
            start = start + RESULTS_PER_PAGE
            if LIMIT_API_CALLS and page > 0:
                break
        except ValueError as e:
            raise e
        except Exception as e:
            print(e)
            break
    return all_data

def prompt_for_estimate_field():
    fields = retrieve("/rest/api/2/field")
    pprint([{
        'id': field['id'],
        'name': field['name']
    } for field in fields])
    print("* Please check the above data structure for an estimate field,")
    print("* then add its 'id' to ESTIMATE_FIELDS in retrieve.py.")
    raise ValueError('No estimate field found')

def issue_estimate(details):
    for field in ESTIMATE_FIELDS:
        if field in details['fields'].keys():
            return details['fields'][field]
    prompt_for_estimate_field()


# Simplify the dict relating to an issue
def issue_details(details):
    return {
        'id': details['key'],
        'created': details['fields']['created'],
        'status': details['fields']['status']['name'],
        'priority': details['fields']['priority']['id'] if details['fields']['priority'] is not None else None,
        'priority_name': details['fields']['priority']['name'] if details['fields']['priority'] is not None else None,
        'type': details['fields']['issuetype']['name'],
        'points': issue_estimate(details),
        'assignee': details['fields']['assignee']['displayName']
            if details['fields']['assignee'] is not None
            else None
    }

# Retrieve meaningful details of the given issue
def issue(issue_id):
    details = retrieve(JIRA + '/rest/api/2/issue/' + issue_id)
    return issue_details(issue_id)

# Retrieve meaningful details of all issues matching the given JQL
def issues(jql):
    return retrieve_all('/rest/api/2/search?jql=' + jql,
        lambda obj: obj['issues'],
        issue_details)

# Simplify the dict relating to a series of status transitions
def transitions_of(issue_details):
    return [
        {
            'issue': issue_details['key'],
            'from': event['fromString'] if 'fromString' in event else None,
            'to': event['toString'] if 'toString' in event else None,
            'date': events['created'] if 'created' in events else None
        }
        for events in issue_details['changelog']['histories']
        for event in events['items']
        if event['field'] == 'status'
    ]

# Retrieve meaningful details of all transitions of all issues matching search query
def transitions(jql):
    all_changesets = retrieve_all(
        '/rest/api/2/search?jql=' + jql + '&expand=changelog',
        lambda row: row['issues'],
        transitions_of)
    return [ changeset for issue_changesets in all_changesets
        for changeset in issue_changesets]

# Retrieve metadata about a given board
def board(name):
    details = retrieve('/rest/agile/1.0/board?' + urlencode({ 'name': name }))
    return details['values'][0]

# Simplify the dict relating to a sprint to just store iteration info
def sprint_details(details):
    issue_keys = retrieve_all(
        '/rest/agile/1.0/sprint/{}/issue?'.format(details['id']),
        lambda row: row['issues'],
        lambda row: row['key'])
    return {
        'name': details['name'] if 'name' in details else None,
        'start': details['startDate'] if 'startDate' in details else None,
        'end': details['completeDate'] if 'completeDate' in details else None,
        'state': details['state'] if 'state' in details else None,
        'issues': ';'.join(issue_keys)
    }

def sprints(board_name):
    board_details = board(board_name)
    return retrieve_all(
        '/rest/agile/1.0/board/{}/sprint?'.format(board_details['id']),
        lambda row: row['values'],
        sprint_details)

# Write a list of dicts to a CSV file
def write_csv(filename, dataset):
    if len(dataset) == 0:
        raise ValueError("No '{}' data available".format(filename))
    keys = dataset[0].keys()
    filename = filename + '.csv'
    with open(filename, 'w', newline='') as output_file:
        dict_writer = csv.DictWriter(output_file, keys)
        dict_writer.writeheader()
        dict_writer.writerows(dataset)

# Write a list of dicts to a JSON file
def write_json(filename, dataset):
    filename = filename + '.json'
    with open(filename, 'w') as output_file:
        json.dump(dataset, output_file)

# Write a list of dicts out to file so it can be accessed flexibly
def write(name, dataset):
    write_csv(name, dataset)
    write_json(name, dataset)

# Retrieve all data

# issues = issue('CAR-256')
issues = issues('project=' + PROJECT)
write('issues', issues)

iterations = sprints(BOARD)
write('iterations', iterations)

# Warning: this will send off quite a number of API calls
changes = transitions('project=' + PROJECT) # &status=Done
write('transitions', changes)
