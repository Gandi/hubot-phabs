Hubot Phabricator Plugin
=================================

[![Version](https://img.shields.io/npm/v/hubot-phabs.svg)](https://www.npmjs.com/package/hubot-phabs)
[![Downloads](https://img.shields.io/npm/dt/hubot-phabs.svg)](https://www.npmjs.com/package/hubot-phabs)
[![Build Status](https://img.shields.io/travis/Gandi/hubot-phabs.svg)](https://travis-ci.org/Gandi/hubot-phabs)
[![Dependency Status](https://gemnasium.com/Gandi/hubot-phabs.svg)](https://gemnasium.com/Gandi/hubot-phabs)
[![Coverage Status](http://img.shields.io/coveralls/Gandi/hubot-phabs.svg)](https://coveralls.io/r/Gandi/hubot-phabs)
[![Code Climate](https://img.shields.io/codeclimate/github/Gandi/hubot-phabs.svg)](https://codeclimate.com/github/Gandi/hubot-phabs)

This plugin is designed to work as an addon for [Hubot](https://hubot.github.com/). Its role is to make interactions possible between a chat room (irc, slack, gitter) and a [phabricator](https://www.phacility.com/phabricator/) instance.

When installed this plugin will check the channels where the bot lurks, to see if someone is talking about Phabricator objects (T32 or P156 or F1526) to complement the conversation with the name of the referred item.

It also makes available some commands to interact directly with Phabricator items, like create a task, assign a task to a user. This is a work in progress and more commands will be added with time.

Installation
--------------
In your hubot directory:    

    npm install hubot-phabs --save

Then add `hubot-phabs` to `external-scripts.json`

Next you need to create a `bot` user in Phabricator and grab its api key.

Configuration
-----------------

- `PHABRICATOR_URL` - main url of your Phabricator instance
- `PHABRICATOR_API_KEY` - api key for the bot user
- `PHABRICATOR_PROJECTS` - list of projects, with this format: `PHID-PROJ-xxx:name,PHID-PCOL-xxx:another`
- `PHABRICATOR_BOT_PHID` - the phid for the bot user (so we can remove him from tasks he creates)

The declarative list of projects is declared that way because name of projects can be long sometimes, and we want to use a short name for irc/slack commands. 

If a PHID-PROJ-xxx is given, it will target the project, and if a dashboard exist, put the task in the default column.

If a PHID-PCOL-xxx is given, it will target the column in whatever project this column is. Finding PHID-PCOL-xxx is tricky, you can only find columns PHIDs if there are items in it. You can use the [`columns.py`](columns.py) script for discovery.

Commands
--------------

Commands prefixed by `.phab` are here taking in account we use the `.` as hubot prefix, just replace it with your prefix if it is different. Also, `phab` can be shortened to `ph` in the commands.

    something about https://phabricator.example.com/T2#17207
    just talking about T123. did you see that one?
        the plugin will watch if it sees 
        - T[0-9]+ for tasks (of Maniphest)
        - P[0-9]+ for pastes 
        - F[0-9]+ for files 
        - M[0-9]+ for mocks (of Pholio)
        - B[0-9]+ for builds (of Harbormaster)
        - L[0-9]+ for legalpads
        - V[0-9]+ for polls (of Slowvote)
        - r[A-Z]+[a-f0-9]+ for commit (of Diffusion)
        if it is in an url, it will reply with 
          T2 - <title of the task>
        if it's not in an url it will reply with
          <task url> - <task title>
        NOTE: this call will record this Task id associated to you for 5 minutes

    .phab new <project-or-column> <task title>
    .phab new <project-or-column> <task title> = <description>
        creates a new task in the list of the ones defined in cactus configuration
        Supported projects are listed by the PHABRICATOR_PROJECTS env var.
        The new task will be created in the default column of the project board.
        the issuer of the command will be added in the list of subscribers for the
        newly created task.
        The <description> is optional, and will be used as description if provided
        NOTE: this call will record this Task id associated to you for 5 minutes

    .phab paste <new paste title>
        creates a new paste and provide the link to edit it

    .phab Txxx
    .phab
        gives the status, priority and owner of the task xxx
        NOTE: you don't need to specify the Txx if you have one in your 5 minutes memory

    .phab Txxx is open
    .phab Txxx broken
    .phab low
        changes status or priority for task Txxx. the 'is' is optional.
        NOTE: you don't need to specify the Txx if you have one in your 5 minutes memory
        Available statuses are:
        - open, opened                     -> open
        - resolved, resolve, closed, close -> resolved
        - wontfix, noway                   -> wontfix
        - invalid, rejected                -> invalid
        - spite, lame                      -> spite
        Available priorities are
        - broken, unbreak         -> Unbreak Now!
        - none, unknown, triage   -> Needs Triage
        - high, urgent            -> High
        - normal                  -> Normal
        - low                     -> Low
        - wish, wishlist          -> Whishlist

    .phab assign T123 to <someone>
    .phab assign <someone> to T123
    .phab assign T123 on <simone>
    .phab T123 on <someone>
    .phab <someone> on T123
    .phab on <someone>
        assigns the given task to a user (or the given user to the task, which is exactly the same).
        the 'to' and 'on' conjunctions are inter-changeable.
        NOTE: you don't need to specify the Txx if you have one in your 5 minutes memory

    .phab <someone>
        will check is <someone> is linked to his phabricator account (using email address)

    .phab me as <email@example.com>
        registers your email in the bot. You need to specify the email address registered in Phabricator

    .phab <someone> = <email@example.com>
        registers email for another user, follows the same concept as .phab me as ..

    .phab list projects
        will list known projects and columns according to configuration param

    .phab count <project>
        return the number of tasks in the given <project>

    .phab version
        displays the version of hubot-phabs that is installed

As an experiment, I moved some configuration variables to the brain. They are managed by the phabs_admin module, driven with the `.phad` command. 

    .phad projects
        lists projects listed in brain

    .phad <project> info
        gives info about <project>

    .phad <project> alias <alias>
        adds an alias <alias> to <project>. Aliases are unique 

    .phad forget <alias>
        removes the alias <alias>

    .phad <project> feed to <room>
        creates a feed for <project> to <room>.
        Feeds are comming from feed.http-hooks

    .phad <project> remove from <room>
        remove a feed


Testing
----------------

    npm install

    # will run make test and coffeelint
    npm test 
    
    # or
    make test
    
    # or, for watch-mode
    make test-w

    # or for more documentation-style output
    make test-spec

    # and to generate coverage
    make test-cov

    # and to run the lint
    make lint

    # run the lint and the coverage
    make

Changelog
---------------
All changes are listed in the [CHANGELOG](CHANGELOG.md)

Contribute
--------------
Feel free to open a PR if you find any bug, typo, want to improve documentation, or think about a new feature. 

Gandi loves Free and Open Source Software. This project is used internally at Gandi but external contributions are **very welcome**. 

Authors
------------
- [@mose](https://github.com/mose) - author and maintainer

License
-------------
This source code is available under [MIT license](LICENSE).

Copyright
-------------
Copyright (c) 2016 - Gandi - https://gandi.net
