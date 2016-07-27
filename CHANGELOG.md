Hubot-phabs Changelog
==========================

### 1.2.3 - 2016-07-27
- improve search result feedbacks
- fix full test coverage for feeds and search
- fix the case when adding an alias to an alias with .phad

### 1.2.2 - 2016-07-27
- fix task creation
- add search on tasks

### 1.2.1 - 2016-07-26
- add an optional ip control over the http endpoint
- fix some cases where the bot was giving double-replies

### 1.2.0 - 2016-07-25
- add admin function `.phad` for managing parameteres about projects
- split files for better code readability
- make project phid guessing rely on phad memory rather than env variable
  PHABRICATOR_PROJECTS is now useless. 
  As a side effect columns are not considered useful anymore, new tasks will 
  go in teh default column of the project. wokring with columns may come back 
  asd dashboards are still under fast development on phabricator side
- added phabs_feeds to open a webhook endpoint for `feed.http-hooks`
  and announce tasks changes on specified channels 
  (configured via the .phad commands)

### 1.1.0 - 2016-07-23
- sort out dependencies 
  you may need to `rm -rf node_modules && npm install` for dev
- changed hardcoded 'irc' by adapter name in task creation data
- fix output of mocks recognition to avoid repeating object name
- add recognition for the Diffusion kind of object (commits)
  rP46ceba728fee8a775e2ddf0cdae332a0679413a4 or rP46ceba728fee
- add recognition for Harbormaster kind of object (builds)
- add recognition for Ponder kind of object (questions)
- add recognition for Legalpad kind of object
- add recognition for Slowvote kind of object (polls)

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
