Hubot-phabs Changelog
==========================

### 1.0.6 - wip
- sort out dependencies
- changed hardcoded 'irc' by adapter name in task creation data

### 1.0.5 - 2016-07-22
- add some more alternatives for changing statuses and priorities
- add an optional description ofr new tasks

### 1.0.4 - 2016-07-22
- add information gathering for M* objects (Pholio mocks)

### 1.0.3 - 2016-07-21
- fix detection of information about Paste

### 1.0.2 - 2016-07-21
- fix error detection (yeah, again)

### 1.0.1 - 2016-07-21
- add a .phab paste some new paste
- fix error handling

### 1.0.0 - 2016-07-19
- add a .phab version command
- add a .phab count proj to count number of tasks in a paroject
- write full code coverage for further tests implementation
- make project alias can use numbers, underscores and dashes
- fixing various error management cases (lovely tests)

### 0.1.7 - 2016-07-16
- create a 5-minute memory of the last Task called, to shorten further commands

### 0.1.6 - 2016-07-15
- add more information on tasks output
- changed .ph assign Txx to <user> to be able to omit the 'assign' part

### 0.1.5 - 2016-07-15
- add command to change task status and priority

### 0.1.4 - 2016-07-15
- fix `.phab new <project> <task>` that regressed in last release

### 0.1.3 - 2016-07-14
- refactoring on phabricator lib
- add a `.phab Txxx` to get task status and owner

### 0.1.2 - 2016-07-13
- add `.phab list projects` command to list known projects from configuration

### 0.1.1 - 2016-07-13
- fix objects output, and filesize for Files

### 0.1.0 - 2016-07-13
- inital extraction from Gandi codebase
