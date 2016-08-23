Hubot-phabs Changelog
==========================

### 1.5.1 - 2016-08-23
- change .phad commands syntax to be more gramatically consistent
  ie. .phad verb object complement

### 1.5.0 - 2016-08-21
- make all commands more tolerant, if people add spaces at the end of the line
- add feature flags for the various parts of this plugin
- made possible to use either a user object or user string
  when calling createTask event and api

### 1.4.4 - 2016-08-19
- add a REST endpoint to create a task
- rely on hubot-restrict-ip for web endpoints protection

### 1.4.3 - 2016-08-16
- fix .ph check so it's not mistaken for a .ph check!

### 1.4.2 - 2016-08-16
- add .ph check! and .ph uncheck! for it also returns the next or previous checkbox

### 1.4.1 - 2016-08-16
- add .ph prev command to see the last unchecked box in a task
- add .ph uncheck to uncheck the last checked box in a task

### 1.4.0 - 2016-08-15
- add checkbox checking commands .ph next and .ph check
- fix subscribers removal of bot for assign command

### 1.3.3 - 2016-08-14
- make the bl and unbl command able to use the short .ph

### 1.3.2 - 2016-08-14
- add a way to blacklist auto-detection on given items
- add the possibility to use 'last' instead of T123 to get the last task called
  without timeout consideration
- avoid remembering id for paste (as it only apply to tasks)
- make any call on task commands extend the temporary memory

### 1.3.1 - 2016-08-10
- fix the template description when no prepend is provided

### 1.3.0 - 2016-08-10
- add phabs_template feature to create tasks according to a task template
  - collection of new .pht commands to setup templates
  - option to chose a template when creating new tasks

### 1.2.10 - 2016-08-09
- add a search all command to also search in closed tasks

### 1.2.9 - 2016-08-06
- fix the transition from bot-phid to no-bot-phid in config

### 1.2.8 - 2016-08-05
- get back on track with full test coverage
- remove the need to set the bot phid in config
- big refactoring to make phabricator lib easier to use by other plugins

### 1.2.7 - 2016-07-31
- add a way to add comment on status and priority changes
- add a way to add comments to a task

### 1.2.6 - 2016-07-30
- changes priority modification to use maniphest.edit with a transaction
- remove bot from subscribers when task assignment is changed

### 1.2.5 - 2016-07-29
- finaly really ensure all commands will work in private messages to bot
- fix the order of requires to avoid double-matches
- changes status modification to use maniphest.edit with a transaction

### 1.2.4 - 2016-07-28
- document and test the `.phad <project> delete` command
- add an optional usage of hubot-auth (see readme for extensive explanation)
- fixed some cases where phab commands could not be called in private

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
- add admin function `.phad` for managing parameters about projects
- split files for better code readability
- make project phid guessing rely on phad memory rather than env variable
  PHABRICATOR_PROJECTS is now useless. 
  As a side effect columns are not considered useful anymore, new tasks will 
  go in the default column of the project. working with columns may come back 
  as dashboards are still under fast development on phabricator side
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
- add a .phab count proj to count number of tasks in a project
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
- initial extraction from Gandi codebase
