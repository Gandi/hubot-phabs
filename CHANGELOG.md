Hubot-phabs Changelog
==========================

### 2.3.1 - 2017-03-15
- `.phab Txx sub user` and unsub makes possible to add subscribers to tasks
  (and ubsubscribe)
- fix on multi-commands so that columns change don't block further commands

### 2.3.0 - 2017-03-14
- `.phad info <project>` now recognize projects that don't have columns or tickets
- `.phad feedall to #channel` for a catchall feed command
- `.phad removeall from #channel` to remove catchall
- `.phad info <project>` now stores and show parent project if any
  - NOTE: you may need to `.phad refresh <project>` on existing projects 
    to re-populate the cached data.
- feeds now are also announced on parent projects feeds (useful for milestones)
- fix on `.ph user x = email` to override previously recorded email

### 2.2.6 - 2017-03-04
- .phid command now returns phid for arbitrary id, when item don't start with PHID

### 2.2.5 - 2017-03-03
- add a .phid command

### 2.2.4 - 2017-02-28
- fix adding and removing tags

### 2.2.3 - 2017-02-20
- make last-task rememberance configurable with PHABRICATOR_LAST_TASK_LIFETIME
  (default 60 min)

### 2.2.2 - 2017-01-21
- make the `is` for status and priority change on tasks optional again

### 2.2.1 - 2017-01-20
- oops forgot to rename xph in ph

### 2.2.0 - 2017-01-19
- made possible to restrict what items trigger the passive listening
- major change in tasks manipulation commands:
  - `.ph assign T123 on <user>` is not usable anymore,
    replaced by `.ph T123 on <user>`
  - `.ph is open` the `is` is now mandatory
  - commands can now be chained in one go, ie.
    `.ph T123 is open is normal on <user> in <tag> not in <other-tag>`

### 2.1.4 - 2017-01-11
- fix typo in index.coffee (aboron)

### 2.1.3 - 2017-01-03
- remove the modification of assignment when changing status or priority

### 2.1.2 - 2016-10-19
- add a way to specify a comment when moving task to another column

### 2.1.1 - 2016-10-13
- fix pattern matching for diffusion objects

### 2.1.0 - 2016-09-29
- add a '.ph Txxx to <column>' to move tasks on the board
  the column name can be a partial name
- add a '.phad refresh <project>'
- now .phad info gathers also the columns for a project
  which can delay the operation quite a lot on the first call
  subsequent calls will hit the cache, and '.phad refresh'
  can be used to update that cache
- change '.ph assign x to user' to only accept 'on' or 'for'
  instead of 'to' because the 'to' will be used to move tasks
  across columns

### 2.0.4 - 2016-09-24
- fix naming for project the lowercasing fucks things up (more better)

### 2.0.3 - 2016-09-24
- fix naming for project the lowercasing fucks things up (better)

### 2.0.2 - 2016-09-24
- fix naming for project the lowercasing fucks things up

### 2.0.1 - 2016-09-23
- change log level for feeds from info to debug

### 2.0.0 - 2016-09-22
- remove all callbacks and replace them by promises
  for a smoother addition of features later on
  It's been tested not to break anything but that's a move big enough
  to motivate a major version bumping
- phad delete also deletes aliases now
- fix case issue with project names occurring in some occasions
- add a '.ph Txx in proj not in proj' to change tags on tasks

### 1.6.0 - 2016-09-08
- remove all dependency on brain.users to
  make it compatible with last version of hubot-slack
  (hubot-auth still use it though)
- change syntax for user commands to .phab user <name>
- when user registers email with .phab me as <email> 
  it checks for phid immediately
- check for permission before advising to use
  .phab user <name> = <email>

### 1.5.9 - 2016-09-01
- add flexibility on status and priority change, 
  to be able to use + instead of = for comment addition

### 1.5.8 - 2016-08-29
- extend private message memory fix to status and priority

### 1.5.7 - 2016-08-27
- fix access to temporary memory while in private message

### 1.5.6 - 2016-08-26
- add an announce param to the createTask event

### 1.5.5 - 2016-08-25
- add possibility to add owner to createTask dataset (for events)

### 1.5.4 - 2016-08-25
- make checkbox command key search case insensitive

### 1.5.3 - 2016-08-25
- add a .pht list command

### 1.5.2 - 2016-08-25
- add a way to add a comment when checking or unchecking boxes
- made term not needed to be the start of the line when searching for checkbox

### 1.5.1 - 2016-08-23
- change .phad commands syntax to be more grammatically consistent
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
