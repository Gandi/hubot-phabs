Hubot Phabricator Plugin
=================================

[![Version](https://img.shields.io/npm/v/hubot-phabs.svg)](https://www.npmjs.com/package/hubot-phabs)
[![Downloads](https://img.shields.io/npm/dt/hubot-phabs.svg)](https://www.npmjs.com/package/hubot-phabs)
[![Build Status](https://img.shields.io/travis/Gandi/hubot-phabs.svg)](https://travis-ci.org/Gandi/hubot-phabs)
[![Dependency Status](https://gemnasium.com/Gandi/hubot-phabs.svg)](https://gemnasium.com/Gandi/hubot-phabs)
[![Coverage Status](http://img.shields.io/codeclimate/coverage/github/Gandi/hubot-phabs.svg)](https://codeclimate.com/github/Gandi/hubot-phabs/coverage)
[![Code Climate](https://img.shields.io/codeclimate/github/Gandi/hubot-phabs.svg)](https://codeclimate.com/github/Gandi/hubot-phabs)

This plugin is designed to work as an addon for [Hubot](https://hubot.github.com/). Its role is to make interactions possible between a chat room (irc, slack, gitter) and a [phabricator](https://www.phacility.com/phabricator/) instance.

When installed this plugin will check the channels where the bot lurks, to see if someone is talking about Phabricator objects (T32 or P156 or F1526) to complement the conversation with the name of the referred item.

It also makes available some commands to interact directly with Phabricator items, like create a task, assign a task to a user. This is a work in progress and more commands will be added with time.

This plugin is used in production internally at [Gandi](https://gandi.net) since 2016-07-13.

> TOC
> --------------
>
> - [Installation](#installation)
> - [Permission System](#permission-system)
> - [Configuration](#configuration)
> - [Features](#features)
>   - [events](#events-feature)
>   - [api](#api-feature)
>   - [commands](#commands-feature)
>   - [templates](#templates-feature)
>   - [admin](#admin-feature)
>   - [feeds](#feeds-feature)
>   - [hear](#hear-feature)
> - [Development](#development)
>   - [Changelog](#changelog)
>   - [Testing](#testing)
>   - [Contribute](#contribute)
> - [Attribution](#attribution)
>   - [Authors](#authors)
>   - [License](#license)
>   - [Copyright](#copyright)

Installation
--------------
In your hubot directory:    

    npm install hubot-phabs --save

Then add `hubot-phabs` to `external-scripts.json`

Next you need to create a `bot` user in Phabricator and grab its api key.


Permission system
-------------------

By default every action is usable by any user. But you can follow the optional permission system by using the `hubot-auth` module.

There are mainly 3 permissions groups:

- `admin` group, for which everything is permitted everywhere
- `phadmin` group, required for which everything is permitted on `.phab` and `.phad` commands
- `phuser` group, which cannot use 
    - the `.phad` command except `.phad projects`
    - the `.phab user = email` command
- the 'not in any group' user, which cannot
    - create new task
    - create new paste
    - change status or permission
    - assign a task to someone
    - set an email or check other users

If you set the variable `PHABRICATOR_TRUSTED_USERS` to `y`, then the 'not in any group' users can access all the features reserved for the `phuser` group. Typically the `phuser` role is designed to be used on public irc or gitter channels, but is not needed in closed slack channels.

Configuration
-----------------

- `PHABRICATOR_URL` - main url of your Phabricator instance
- `PHABRICATOR_API_KEY` - api key for the bot user

If you use `hubot-auth`
- `HUBOT_AUTH_ADMIN` - hardcoded list of hubot admins
- `PHABRICATOR_TRUSTED_USERS` - if set to 'y', bypasses the requirement of belonging to `phuser` group for  commands restricted to users. Makes sense in places where all users are internal or invited-only and trustable.

You also should use `hubot-restrict-ip` to limit the access to the web endpoints (api and feeds endpoints), or serve only on localhost (`EXPRESS_BIND_ADDRESS=127.0.0.1`) and use a proxy to access those endpoints.

Features
----------------

The `hubot-phabs` plugin has a lot of features, and some of them could be useless, or dangerous if activated under an un-protected environment. There are 2 envirnment variables that can be used to limit what features are lodaed and active:

- `PHABS_ENABLED_FEATURES` can be a comma-separated list of the only plugins enabled. 
- `PHABS_DISABLED_FEATURES` is also a comma-separated list of features, to only restrict a few ones. It won't be any use if the `PHABS_ENABLED_FEATURES` is declared, as it would take priority.

Typical examples of usage are:

- `PHABS_ENABLED_FEATURES="hear"` if you only want the bot to do automatic announces
- `PHABS_DISABLED_FEATURES="feeds,api"` if you don't want to expose http endpoints
- `PHABS_DISABLED_FEATURES="admin,feeds"` if you don't use `hubot-auth`. Note that you can do the setup with the admin feature at first,m and then just disable it (and relaunch the bot in between).

Available fetaures are loaded in that order:

- `events`
- `api`
- `commands`
- `templates`
- `admin`
- `feeds`
- `hear`


### Events feature

There is some events available for interaction with other plugins, to chain actions or automate them. The specific use case we had was to use [hubot-cron-events](https://github.com/Gandi/hubot-cron-events) to create templated tasks are given times. It is making sense in our workflow. The principle is pretty useful, so there will be more events declared further on.

    phab.createTask
        payload:
        - project (by name or alias)
        - template (null if none)
        - title
        - description
        - user (either a user object or a string)
        - assign (as a user name)
        - announce (optinoal: the name of a room where to announce the task creation and id)
        It will create a task from an event, 
        and talk on the logger when done or if it fails.

### API feature

It may seem a little weird, but circumstances led us to use our hubot as an API endpoint for creating tasks from inside our internal network. Of course we could just use conduit and hit Phabricator directly but:

- we save the hassle of spreading the API key around
- we are inside a trusted network, and use hubot-restrict-ip
- we expose REST endpoints, with only very simplified payload description

To avoid exposure of that weak API endpoint, you should:

- set the env var PHABS_NO_API to any value, if it's defined, the api code is not loaded
- use [hubot-restrict-ip](https://github.com/Gandi/hubot-restrict-ip) to set up your own policy
- set your hubot to respond http calls through a well configured apache or nginx proxy

Currently the API only has one endpoint, that triggers the `phab.createTask` event

    POST /<robot.name>/phabs/api/:project/task
    where :project can be a project name or an alias 
    that you have set with .phad
    the content-type has to be application/json
    and the payload should conform to the payload 
    for the phab.createTask event

### Commands feature

Commands prefixed by `.phab` are here taking in account we use the `.` as hubot prefix, just replace it with your prefix if it is different. Also, `phab` can be shortened to `ph` in the commands.

Requests can be done on arbitrary projects. Their PHID will be retrieved at first call and cached in hubot brain. Those projects can use aliases, like short names, interchangeably, for convenience (set them up using the `.phad` command).

    .phab <project> search terms
        will grab the 3 newest matches in tasks matching search terms.
        note that there are some special rules:
        - non-alphanumeric chars will be mess up
        - the match is done on full-words: test won't match tests
        permission: all

    .phab new <project> <task title>
    .phab new <project> <task title> = <description>
        creates a new task in an arbitrary project. 
        A project alias can also be used.
        The new task will be created in the default column of the project board.
        The issuer of the command will be added in the list of subscribers
        for the newly created task.
        The <description> is optional, and will be used as description if provided
        NOTE: this call will record this Task id associated to you for 5 minutes
        permission: phuser

    .phab new <project>:<template> <task title>
    .phab new <project>:<template> <task title> = <description>
        creates a new task using a template.
        if a description is provided, it will prepend the template description
        For the rest, it behaves like the .phab new command
        permission: phuser

    .phab paste <new paste title>
        creates a new paste and provide the link to edit it
        permission: phuser

    .phab Txxx
    .phab
        gives the status, priority and owner of the task xxx
        NOTE: this call will record this Task id associated to you for 5 minutes
        permission: all

    .phab Txxx + <some comment>
    .phab + <some comment>
        adds a comment to task Txxx (or the one in short memory).
        permission: phuser

    .phab Txxx is open
    .phab Txxx broken
    .phab low
    .phab low = this is a reason
    .phab low + this is a reason
        Changes status or priority for task Txxx. the 'is' is optional.
        If the optional '=' or '+' is used, it will add a comment to that change
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
        permission: phuser

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
        permission: phuser

    .phab T123 next <term>
    .phab T123 next
    .phab next
        This will return the first match in the Task T123 description 
        that begins with a [ ] (a checkbox)
        if a <term> is provided, it will match the first line 
        that begins with '[ ] term'
        the first word on the line, just after the checkbox, is used
        as a keyword, but it's totally optional
        permission: phuser

    .phab T123 prev <term>
    .phab T123 prev
    .phab previous
    .phab prev
        This will return the last match in the Task T123 description 
        that begins with a [x] (a checked checkbox)
        if a <term> is provided, it will match the last line 
        that begins with '[x] term'
        permission: phuser

    .phab T123 check <term>
    .phab T123 check
    .phab check
    .phab check! <term>
    .phab check!
    .phab check! + <comment>
        This will update the description of T123
        and replace the checkbox line with a checked box '[x]'
        If a term is provided, the first matching line will be the checked one
        If the '!' is added, it will also return the next unchecked checkbox
        If a '+' is added at the end of any above syntax, it will append a comment 
        in the modification
        permission: phuser

    .phab T123 uncheck <term>
    .phab T123 uncheck
    .phab uncheck
    .phab uncheck! <term>
    .phab uncheck!
    .phab uncheck! + <comment>
        This will update the description of T123
        and replace the checked checkbox line with a checked box '[ ]'
        If a term is provided, the last matching line will be the unchecked one
        If the '!' is added, it will also return the previous checked checkbox
        If a '+' is added at the end of any above syntax, it will append a comment 
        in the modification
        permission: phuser

    .phab <someone>
        will check is <someone> is linked to his Phabricator account 
        (using email address)
        permission: phuser

    .phab me as <email@example.com>
        registers your email in the bot. You need to specify the email address 
        registered in Phabricator
        permission: phuser

    .phab <someone> = <email@example.com>
        registers email for another user, follows the same concept as 
        .phab me as ..
        permission: phadmin

    .phab count <project>
        return the number of tasks in the given <project>
        permission: all

    .phab version
        displays the version of hubot-phabs that is installed
        permission: all


### Templates feature

There is also a way to specify a list of templates for creating new Tasks with prefilled descriptions. Any task can be used as a template, whatever the status, as far as they are readable by the bot user. Typically those can be relevant closed Tasks form the past that we fit for templating.

The management of those templates is done with the `.pht` command:

    .pht new <name> T123
        creates a new template named <name>, using the task T123 as a template
        permission: phadmin

    .pht show <name>
    .pht info <name>
        shows what task is used as a template
        permission: phuser

    .pht search <term>
    .pht list <term>
        search through templates which names contain <term>
        If <term> is omitted, it just retruns the whole list 
        of all templates
        permission: phuser

    .pht remove <name>
        removes template named <name> from the brain memory
        permission: phadmin

    .pht update <name> T321
        updated template named <name> with the new template task T321
        permission: phadmin

    .pht rename <name> <newname>
        rename the template named <name> with <newname>
        permission: phadmin


### Admin features

Some configuration variables are stored the brain. They are managed by the phabs_admin module, driven with the `.phad` command. **note** the syntax changed in v1.5.1

    .phad projects
        lists projects listed in brain
        permission: all

    .phad delete <project>
    .phad del <project>
        removes information about <projects> from the brain
        (useful when a project is deleted or renamed in phabricator)
        permission: phadmin

    .phad info <project>
    .phad show <project>
        gives info about <project>
        permission: all

    .phad alias <project> as <alias>
        adds an alias <alias> to <project>. Aliases are unique 
        permission: phadmin

    .phad forget <alias>
        removes the alias <alias>
        permission: phadmin

    .phad feed <project> to <room>
    .phad feeds <project> to <room>
        creates a feed for <project> to <room>.
        Feeds are comming from feed.http-hooks
        permission: phadmin

    .phad remove <project> from <room>
        remove a feed
        permission: phadmin


### Feeds feature

A http endpoint is open for receiving feeds from `feed.http-hooks` as explained in https://secure.phabricator.com/T5462

You can use the `.phad` commands to associate Projects to rooms. Each Feed Story will then be dispatched on one or several rooms according to the project the task belongs to. This only works with Tasks (for now).

The feed has an optional way to limit the IP of the sender, by setting the HUBOT_AUTHORIZED_IP_REGEXP env variable. If this variable is not set, there is not access control. It's a limited soft protection, if you really need a heavy secure protection, do something on your network for it.


### Hear feature

There is a `.hear` feature that also will give information about items that are cited on channel. It tries to do precise pattern matching but sometimes there are some unfortunate coincidences. For example, we work with level3 and talk about it under L3 often. Or one of our project involves a V5. It's kind of annoying to have the bot react on those specific case, so it' possible to blacklist them.

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
        it will just say nothing if the pattern matched is in the blacklist
        permission: all

    .phab bl T123
        this will add T123 to the blacklist
        permission: phuser

    .phab unbl T123
        this will remove T123 from the blacklist
        permission: phuser

Development
--------------

### Changelog

All changes are listed in the [CHANGELOG](CHANGELOG.md)

### Testing

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


### Contribute

Feel free to open a PR if you find any bug, typo, want to improve documentation, or think about a new feature. 

Gandi loves Free and Open Source Software. This project is used internally at Gandi but external contributions are **very welcome**. 

Attribution
-----------

### Authors

- [@mose](https://github.com/mose) - author and maintainer

### License

This source code is available under [MIT license](LICENSE).

### Copyright

Copyright (c) 2016 - Gandi - https://gandi.net
