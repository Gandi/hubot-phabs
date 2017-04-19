# Description:
#   enable communication with Phabricator via Conduit api
#
# Dependencies:
#
# Configuration:
#   PHABRICATOR_URL
#   PHABRICATOR_API_KEY
#
# Commands:
#   hubot phab version - give the version of hubot-phabs loaded
#   hubot phab new <project>[:<template>] <name of the task> - creates a new task
#   hubot phab paste <name of the paste> - creates a new paste
#   hubot phab count <project> - counts how many tasks a project has
#   hubot phab bl <id> - blacklists an id from phabs_hear
#   hubot phab unbl <id> - removes an id from blacklist
#   hubot phab Txx - gives information about task Txx
#   hubot phab Txx + <some comment> - add a comment to task Txx
#   hubot phab Txx in <project-tag> - add a tag to task Txx
#   hubot phab Txx to [project:]<columns> - move task Txx to columns
#   hubot phab Txx is <status> - modifies task Txx status
#   hubot phab Txx is <priority> - modifies task Txx priority
#   hubot phab assign Txx to <user> - assigns task Txx to comeone
#   hubot phab Txx next [<key>] - outputs next checkbox found in task Txx
#   hubot phab Txx prev [<key>] - outputs last checked checkbox found in task Txx
#   hubot phab Txx check [<key>] - update task Txx description by checking a box
#   hubot phab Txx uncheck [<key>] - update task Txx description by unchecking a box
#   hubot phab <user> - checks if user is known or not
#   hubot phab me as <email> - makes caller known with <email>
#   hubot phab <user> = <email> - associates user to email
#   hubot phab search [all] earch terms - searches for terms in tasks ([all] to search non-open)
#   hubot phab [all] <project> search terms - searches terms in project ([all] to search non-open)
#
# Author:
#   mose

Phabricator = require '../lib/phabricator'
moment = require 'moment'
path = require 'path'

module.exports = (robot) ->
  
  robot.phab ?= new Phabricator robot, process.env
  phab = robot.phab

  #   hubot phab version - give the version of hubot-phabs loaded
  robot.respond /ph(?:ab)? version *$/, (msg) ->
    pkg = require path.join __dirname, '..', 'package.json'
    msg.send "hubot-phabs module is version #{pkg.version}"
    msg.finish()

  #   hubot phab new <project>[:<template>] <name of the task>
  robot.respond (
    /ph(?:ab)? new ([-_a-zA-Z0-9]+)(?::([-_a-zA-Z0-9]+))? ([^=]+)(?: = (.*))? *$/
  ), (msg) ->
    data = {
      project: msg.match[1]
      template: msg.match[2]
      title: msg.match[3]
      description: msg.match[4]
      user: msg.envelope.user
    }
    phab.getPermission(msg.envelope.user, 'phuser')
    .then ->
      phab.createTask(data)
    .then (res) ->
      phab.recordId res.user, res.id
      msg.send "Task T#{res.id} created = #{res.url}"
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot phab paste <name of the paste> - creates a new paste
  robot.respond /ph(?:ab)? paste (.*)$/, (msg) ->
    title = msg.match[1]
    phab.getPermission(msg.envelope.user, 'phuser')
    .then ->
      phab.createPaste(msg.envelope.user, title)
    .then (id) ->
      url = process.env.PHABRICATOR_URL + "/paste/edit/#{id}"
      msg.send "Paste P#{id} created = edit on #{url}"
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot phab count <project> - counts how many tasks a project has
  robot.respond (/ph(?:ab)? count ([-_a-zA-Z0-9]+) *$/), (msg) ->
    project = msg.match[1]
    name = null
    phab.getProject(project)
    .then (proj) ->
      name = proj.data.name
      phab.listTasks(proj.data.phid)
    .then (body) ->
      if Object.keys(body['result']).length is 0
        msg.send "#{name} has no tasks."
      else
        msg.send "#{name} has #{Object.keys(body['result']).length} tasks."
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot bl <id> - blacklists <id> from auto-resopnses
  robot.respond /ph(?:ab)? bl ((?:T|F|P|M|B|Q|L|V)(?:[0-9]+)|(?:r[A-Z]+[a-f0-9]{10,}))/, (msg) ->
    phab.getPermission(msg.envelope.user, 'phuser')
    .then ->
      phab.blacklist msg.match[1]
      msg.send "Ok. #{msg.match[1]} won't react anymore to auto-detection."
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot bl <id> - blacklists <id> from auto-resopnses
  robot.respond /ph(?:ab)? unbl ((?:T|F|P|M|B|Q|L|V)(?:[0-9]+)|(?:r[A-Z]+[a-f0-9]{10,}))/, (msg) ->
    phab.getPermission(msg.envelope.user, 'phuser')
    .then ->
      phab.unblacklist msg.match[1]
      msg.send "Ok. #{msg.match[1]} now will react to auto-detection."
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot phab Txx - gives information about task Txxx
  robot.respond /ph(?:ab)?(?: T([0-9]+)| (last))? *$/, (msg) ->
    what = msg.match[1] or msg.match[2]
    id = null
    body = null
    phab.getId(msg.envelope.user, what)
    .bind(id)
    .bind(body)
    .then (@id) ->
      phab.getTask(@id)
    .then (@body) ->
      phab.getUserByPhid(@body.result.ownerPHID)
    .then (owner) ->
      status = @body.result.status
      priority = @body.result.priority
      title = @body.result.title
      if @body.result.status is 'open'
        ago = moment(@body.result.dateCreated, 'X').fromNow()
      else
        ago = moment(@body.result.dateModified, 'X').fromNow()
      phab.recordId msg.envelope.user, @id
      msg.send "T#{@id} - #{title} (#{status} #{ago}, #{priority}, owner #{owner})"
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot phab Txx + <some comment> - add a comment to task Txx
  robot.respond /ph(?:ab)?(?: T([0-9]+)| (last))? \+ (.+) *$/, (msg) ->
    what = msg.match[1] or msg.match[2]
    comment = msg.match[3]
    id = null
    phab.getPermission(msg.envelope.user, 'phuser')
    .then ->
      phab.getId(msg.envelope.user, what)
    .then (id) ->
      phab.addComment(msg.envelope.user, id, comment)
    .then (id) ->
      msg.send "Ok. Added comment \"#{comment}\" to T#{id}."
    .catch (e) ->
      msg.send e
    msg.finish()

  # hubot phab Txx <status> - modifies task Txxx status
  robot.respond new RegExp(
    "ph(?:ab)?(?: T([0-9]+)| (last))? (?:is )?(#{Object.keys(phab.statuses).join('|')})" +
    '(?: (?:=|\\+) (.+))? *$'
  ), (msg) ->
    what = msg.match[1] or msg.match[2]
    status = msg.match[3]
    comment = msg.match[4]
    phab.getPermission(msg.envelope.user, 'phuser')
    .then ->
      phab.getId(msg.envelope.user, what)
    .then (id) ->
      phab.doActions(msg.envelope.user, id, "is #{status}", comment)
    .then (back) ->
      if back.message? and back.message isnt ''
        msg.send "Ok, T#{back.id} now has #{back.message}."
      if back.notices.length > 0
        for notice in back.notices
          msg.send notice
    .catch (e) ->
      msg.send e
    msg.finish()

  # hubot phab Txx <priority> - modifies task Txxx priority
  robot.respond new RegExp(
    "ph(?:ab)?(?: T([0-9]+)| (last))? (?:is )?(#{Object.keys(phab.priorities).join('|')})" +
    '(?: (?:=|\\+) (.+))? *$'
  ), (msg) ->
    what = msg.match[1] or msg.match[2]
    priority = msg.match[3]
    comment = msg.match[4]
    phab.getPermission(msg.envelope.user, 'phuser')
    .then ->
      phab.getId(msg.envelope.user, what)
    .then (id) ->
      phab.doActions(msg.envelope.user, id, "is #{priority}", comment)
    .then (back) ->
      if back.message? and back.message isnt ''
        msg.send "Ok, T#{back.id} now has #{back.message}."
      if back.notices.length > 0
        for notice in back.notices
          msg.send notice
    .catch (e) ->
      msg.send e
    msg.finish()

  robot.respond new RegExp(
    'ph(?:ab)?(?: T([0-9]+)| (last))?((?:' +
    ' is [^ ]+|' +
    ' on [^ ]+|' +
    ' for [^ ]+|' +
    ' to [^ ]+|' +
    ' sub [^ ]+|' +
    ' unsub [^ ]+|' +
    ' in [^ ]+|' +
    ' not in [^ ]+)*)' +
    '(?: (?:=|\\+) (.+))? *$'
  ), (msg) ->
    what = msg.match[1] or msg.match[2]
    commands = msg.match[3]
    comment = msg.match[4]
    phab.getPermission(msg.envelope.user, 'phuser')
    .then ->
      phab.getId(msg.envelope.user, what)
    .then (id) ->
      phab.doActions(msg.envelope.user, id, commands, comment)
    .then (back) ->
      if back.message? and back.message isnt ''
        msg.send "Ok, T#{back.id} now has #{back.message}."
      if back.notices.length > 0
        for notice in back.notices
          msg.send notice
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot phab Txx next [<key>]- outputs the next checkbox in a given task
  robot.respond /ph(?:ab)?(?: T([0-9]+)| (last))? next(?: (.+))? *$/, (msg) ->
    what = msg.match[1] or msg.match[2]
    key = msg.match[3]
    id = null
    phab.getPermission(msg.envelope.user, 'phuser')
    .bind(id)
    .then ->
      phab.getId(msg.envelope.user, what)
    .then (@id) ->
      phab.nextCheckbox(msg.envelope.user, @id, key)
    .then (line) ->
      msg.send "Next on T#{@id} is: #{line}"
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot phab Txx prev [<key>]- outputs the last checked checkbox in a given task
  robot.respond /ph(?:ab)?(?: T([0-9]+)| (last))? prev(?:ious)?(?: (.+))? *$/, (msg) ->
    what = msg.match[1] or msg.match[2]
    key = msg.match[3]
    id = null
    phab.getPermission(msg.envelope.user, 'phuser')
    .bind(id)
    .then ->
      phab.getId(msg.envelope.user, what)
    .then (@id) ->
      phab.prevCheckbox(msg.envelope.user, @id, key)
    .then (line) ->
      msg.send "Previous on T#{@id} is: #{line}"
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot phab Txx check [<key>] - update task Txx description by checking a box
  robot.respond /ph(?:ab)?(?: T([0-9]+)| (last))? check(!)?(?: ([^\+]+))?(?: \+ (.+))? *$/, (msg) ->
    what = msg.match[1] or msg.match[2]
    withNext = msg.match[3]
    key = msg.match[4]
    comment = msg.match[5]
    id = null
    phab.getPermission(msg.envelope.user, 'phuser')
    .bind(id)
    .then ->
      phab.getId(msg.envelope.user, what)
    .then (@id) ->
      phab.checkCheckbox(msg.envelope.user, @id, key, withNext, comment)
    .then (line) ->
      msg.send "Checked on T#{@id}: #{line[0]}"
      if line[1]?
        msg.send "Next on T#{@id}: #{line[1]}"
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot phab Txx uncheck [<key>] - update task Txx description by unchecking a box
  robot.respond /ph(?:ab)?(?: T([0-9]+)| (last))? uncheck(!)?(?: ([^\+]+))?(?: \+ (.+))? *$/
  , (msg) ->
    what = msg.match[1] or msg.match[2]
    withNext = msg.match[3]
    key = msg.match[4]
    comment = msg.match[5]
    id = null
    phab.getPermission(msg.envelope.user, 'phuser')
    .bind(id)
    .then ->
      phab.getId(msg.envelope.user, what)
    .then (@id) ->
      phab.uncheckCheckbox(msg.envelope.user, @id, key, withNext, comment)
    .then (line) ->
      msg.send "Unchecked on T#{@id}: #{line[0]}"
      if line[1]?
        msg.send "Previous on T#{@id}: #{line[1]}"
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot phab user <user> - checks if user is known or not
  robot.respond /ph(?:ab)? (?:user|who) ([^ ]*) *$/, (msg) ->
    assignee = { name: msg.match[1] }
    phab.getPermission(msg.envelope.user, 'phuser')
    .then ->
      phab.getUser(msg.envelope.user, assignee)
    .then (userPhid) ->
      msg.send "Hey I know #{assignee.name}, he's #{userPhid}"
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot phab me as <email> - makes caller known with <email>
  robot.respond /ph(?:ab)? me as (.*@.*) *$/, (msg) ->
    email = msg.match[1]
    phab.getPermission(msg.envelope.user, 'phuser')
    .then ->
      msg.envelope.user.email_address = msg.match[1]
      phab.getUser(msg.envelope.user, msg.envelope.user)
    .then (userPhid) ->
      msg.send "Now I know you, you are #{userPhid}"
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot phab user <user> = <email> - associates user to email
  robot.respond /ph(?:ab)? user ([^ ]*) *?= *?([^ ]*@.*) *$/, (msg) ->
    assignee = { name: msg.match[1], email_address: msg.match[2] }
    phab.getPermission(msg.envelope.user, 'phuser')
    .then ->
      phab.getUser(msg.envelope.user, assignee)
    .then (userPhid) ->
      msg.send "Now I know #{assignee.name}, he's #{userPhid}"
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot phab [all] [limit] search <search terms> - searches for terms in project
  robot.respond /ph(?:ab)?( all)?(?: (\d+))? search (.+)$/, (msg) ->
    status = if msg.match[1]?
      undefined
    else
      'open'
    limit = msg.match[2] or 3
    terms = msg.match[3]
    phab.searchAllTask(terms, status, limit)
    .then (payload) ->
      if payload.result.data.length is 0
        msg.send "There is no task matching '#{terms}'."
      else
        for task in payload.result.data
          if task.fields.status.name is 'Open'
            ago = moment(task.fields.dateCreated, 'X').fromNow()
          else
            ago = moment(task.fields.dateModified, 'X').fromNow()
          msg.send "#{process.env.PHABRICATOR_URL}/T#{task.id} - #{task.fields['name']}" +
                   " (#{task.fields.status.name} #{ago})"
        if payload.result.cursor.after?
          msg.send '... and there is more.'
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot phab [all] [limit] <project> <search terms> - searches for terms in project
  robot.respond /ph(?:ab)?( all)?(?: (\d+))? ([^ ]+) (.+)$/, (msg) ->
    status = if msg.match[1]?
      undefined
    else
      'open'
    limit = msg.match[2] or 3
    project = msg.match[3]
    terms = msg.match[4]
    name = null
    phab.getProject(project)
    .then (proj) ->
      name = proj.data.name
      phab.searchTask(proj.data.phid, terms, status, limit)
    .then (payload) ->
      if payload.result.data.length is 0
        msg.send "There is no task matching '#{terms}' in project '#{name}'."
      else
        for task in payload.result.data
          if task.fields.status.name is 'Open'
            ago = moment(task.fields.dateCreated, 'X').fromNow()
          else
            ago = moment(task.fields.dateModified, 'X').fromNow()
          msg.send "#{process.env.PHABRICATOR_URL}/T#{task.id} - #{task.fields['name']}" +
                   " (#{task.fields.status.name} #{ago})"
        if payload.result.cursor.after?
          msg.send '... and there is more.'
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot phid <phid> - returns info about an arbitrary phid
  robot.respond /phid ([^ ]+) *$/, (msg) ->
    item = msg.match[1]
    if /^PHID-/.test item
      phab.getPHID(item)
      .then (data) ->
        msg.send "#{item} is #{data.name} - #{data.uri} (#{data.status})"
      .catch (e) ->
        msg.send e
      msg.finish()
    else
      phab.genericInfo(item)
      .then (body) ->
        if Object.keys(body.result).length < 1
          msg.send "#{item} not found."
        else
          msg.send "#{item} is #{body.result[item].phid}"
      .catch (e) ->
        msg.send e
      msg.finish()
