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
- `PHABRICATOR_BOT_PHID` - the phid for the bot user (so we can remove him from tasks he creates)
- `HUBOT_AUTHORIZED_IP_REGEXP` - an optional configuration var to limit access to the webhook feeds endpoint


Commands
--------------

Commands prefixed by `.phab` are here taking in account we use the `.` as hubot prefix, just replace it with your prefix if it is different. Also, `phab` can be shortened to `ph` in the commands.

Requests can be done on arbitrary projects. Their PHID will be retrieved at first call and cached in hubot brain. Those projects can use aliases, like short names, interchangeably, for convenience (set them up using the `.phad` command).

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

    .phab <project> search terms
        will grab the 3 newest matches in tasks matching search terms.
        note that there are some special rules:
        - non-alphanumeric chars will be mess up
        - the match is done on full-words: test won't match tests

    .phab new <project> <task title>
    .phab new <project> <task title> = <description>
        creates a new task in an arbitrary project. 
        A project alias can also be used.
        The new task will be created in the default column of the project board.
        The issuer of the command will be added in the list of subscribers
        for the newly created task.
        The <description> is optional, and will be used as description if provided
        NOTE: this call will record this Task id associated to you for 5 minutes

    .phab paste <new paste title>
        creates a new paste and provide the link to edit it

    .phab Txxx
    .phab
        gives the status, priority and owner of the task xxx
        NOTE: this call will record this Task id associated to you for 5 minutes

    .phab Txxx is open
    .phab Txxx broken
    .phab low
        changes status or priority for task Txxx. the 'is' is optional.
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
        NOTE: this call will record this Task id associated to you for 5 minutes

    .phab assign T123 to <someone>
    .phab assign <someone> to T123
    .phab assign T123 on <simone>
    .phab T123 on <someone>
    .phab <someone> on T123
    .phab on <someone>
        assigns the given task to a user (or the given user to the task, 
        which is exactly the same). 
        The 'to' and 'on' conjunctions are inter-changeable.
        NOTE: this call will record this Task id associated to you for 5 minutes

    .phab <someone>
        will check is <someone> is linked to his phabricator account 
        (using email address)

    .phab me as <email@example.com>
        registers your email in the bot. You need to specify the email address 
        registered in Phabricator

    .phab <someone> = <email@example.com>
        registers email for another user, follows the same concept as 
        .phab me as ..

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
    .phad <project> as <alias>
        adds an alias <alias> to <project>. Aliases are unique 

    .phad forget <alias>
        removes the alias <alias>

    .phad <project> feed to <room>
    .phad <project> feeds <room>
        creates a feed for <project> to <room>.
        Feeds are comming from feed.http-hooks

    .phad <project> remove from <room>
    .phad <project> remove <room>
        remove a feed

Feeds
----------------

A http endpoint is open for receiving feeds from `feed.http-hooks` as explained in https://secure.phabricator.com/T5462

You can use the `.phad` commands to associate Projects to rooms. Each Feed Story will then be dispatched on one or several rooms according to the project the task belongs to. This only works with Tasks (for now).

The feed has an optional way to limit the IP of the sender, by setting the HUBOT_AUTHORIZED_IP_REGEXP env variable. If this variable is not set, there is not access control. It's a limited soft protection, if you really need a heavy secure protection, do something on your network for it.

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
