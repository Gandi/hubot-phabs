import json
import subprocess
import argparse

def conduit_allprojects():
    result = execute_apicall(
        'project.query',
        {
        }
    )
    projectIds = result['response']['data'].keys()
    projects = conduit_phidlookup(list(projectIds))
    return projects

def conduit_projPHID(project):
    result = execute_apicall(
        'project.query',
        {
            'names' : [project]
        }
    )

    projPHID = result['response']['data'].keys()[0]

    return projPHID

def conduit_tasktransactions(taskids):
    result = execute_apicall(
        'maniphest.gettasktransactions',
        {
            'ids': taskids
        }
    )

    tasktransactions = result['response']

    return tasktransactions

def conduit_phidlookup(phids):
    result = execute_apicall(
        'phid.lookup',
        {
            'names': phids
        }
    )
    phidlookup = {}
    if len(result['response']):
        phidlookup = { x: result['response'][x]['fullName'] for x in result['response'].keys() }

    return phidlookup

def find_first(iterable, f):
    for x in iterable:
        if f(x):
            yield x
            raise StopIteration
    raise StopIteration

def conduit_columns(projPHID):
    result = execute_apicall(
        'maniphest.query',
        {
            'projectPHIDs': [projPHID],
            'order': 'order-priority'
        }
    )
    cols = {}
    if len(result['response']):
        taskPHIDs = result['response'].keys()
        
        all_tasktransactions = conduit_tasktransactions(
            [int(x['id']) for x in result['response'].values()]
        )
        # print json.dumps(all_tasktransactions, indent=4, separators=(',', ': '))
        columns = []
        for tasktransactions in all_tasktransactions.values():
            first = find_first(
                    tasktransactions,
                    lambda x: x['transactionType'] == 'core:columns' and \
                    x['newValue'][0]['boardPHID'] == projPHID
                )
            for x in first:
                columns.append(x['newValue'][0]['columnPHID'])
        cols = conduit_phidlookup(list(set(columns)))

    return cols

def execute_apicall(apicall, query):
    p = subprocess.Popen(
        ['arc', 'call-conduit', apicall],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT
    )
    p.stdin.write(json.dumps(query))
    stdout = p.communicate()[0]
    p.stdin.close()
    p.wait()
    
    if p.returncode != 0:
        raise Exception(stdout)
    return json.loads(stdout)

def main():
    projects = conduit_allprojects()
    print json.dumps(projects, indent=4)

    for i in projects.keys():
        print "%s (%s)" % (projects[i], i)
        columns = conduit_columns(i)
        print json.dumps(columns, indent=4)

if __name__ == '__main__':
    main()
