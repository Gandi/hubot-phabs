# Description:
#   enable communication with Phabricator via Conduit api
#
# Dependencies:
#
# Configuration:
#   PHABRICATOR_URL
#   PHABRICATOR_API_KEY
#   PHABRICATOR_PROJECTS
#   PHABRICATOR_BOT_PHID
#
# Commands:
#   hubot phab new <project> <name of the task> - creates a new task
#   hubot phab assign Txx to <user> - assigns task Txxx to comeone
#   hubot phab <user> - checks if user is known or not
#   hubot phab me as <email> - makes caller known with <email>
#   hubot phab <user> = <email> - associates user to email
#   hubot phab list projects - list known projects according to configuration
#   anything Txxx - complements with the title of the task, file (F) or paste (P)
#
# Author:
#   mose

Phabricator = require '../lib/phabricator'
moment = require 'moment'
path = require 'path'

phabColumns = { }
if process.env.PHABRICATOR_PROJECTS isnt undefined
  for list in process.env.PHABRICATOR_PROJECTS.split(',')
    [code, label] = list.split ':'
    phabColumns[label] = code

humanFileSize = (size) ->
  i = Math.floor( Math.log(size) / Math.log(1024) )
  return ( size / Math.pow(1024, i) ).toFixed(2) * 1 + ' ' + ['B', 'kB', 'MB', 'GB', 'TB'][i]

module.exports = (robot) ->
  phab = new Phabricator robot, process.env

  # robot.respond /ph(?:ab)? create$/, (msg) ->
  #   id = 'T42'
  #   phab.recordPhid msg, id
  #   msg.finish()

  # robot.respond /ph(?:ab)? read$/, (msg) ->
  #   console.log phab.retrievePhid msg
  #   msg.finish()

  # robot.respond /ph(?:ab)? date$/, (msg) ->
  #   console.log moment(msg.message.user.lastTask).utc().format()
  #   console.log moment().utc().format()
  #   msg.finish()

  robot.respond (/ph(?:ab)? list projects$/), (msg) ->
    msg.send "Known Projects: #{Object.keys(phabColumns).join(', ')}"


  robot.respond /ph(?:ab)? version/, (msg) ->
    pkg = require path.join __dirname, '..', 'package.json'
    msg.send "hubot-phabs module is version #{pkg.version}"
    msg.finish()


  robot.respond (/ph(?:ab)? new ([-_a-zA-Z0-9]+) (.+)/), (msg) ->
    column = phabColumns[msg.match[1]]
    name = msg.match[2]
    if column?
      phab.createTask msg, column, name, (body) ->
        if body['error_info']
          msg.send "#{body['error_info']}"
        else
          id = body['result']['object']['id']
          url = process.env.PHABRICATOR_URL + "/T#{id}"
          phab.recordPhid msg, id
          msg.send "Task T#{id} created = #{url}"
    else
      msg.send 'Command incomplete.'


  robot.respond /ph(?:ab)?(?: T([0-9]+) ?)?$/, (msg) ->
    id = msg.match[1] ? phab.retrievePhid(msg)
    unless id?
      msg.send "Sorry, you don't have any task active right now."
      msg.finish()
      return
    phab.taskInfo msg, id, (body) ->
      if body.result?
        phab.withUserByPhid robot, body.result.ownerPHID, (owner) ->
          status = body.result.status
          priority = body.result.priority
          phab.recordPhid msg, id
          msg.send "T#{id} has status #{status}, " +
                   "priority #{priority}, owner #{owner.name}"
      else
        msg.send "Sorry, this task T#{id} was not found."
    msg.finish()


  robot.respond /ph(?:ab)?(?: T([0-9]+))? (?:is )?(open|resolved|wontfix|invalid|spite)$/, (msg) ->
    id = msg.match[1] ? phab.retrievePhid(msg)
    unless id?
      msg.send "Sorry, you don't have any task active right now."
      msg.finish()
      return
    status = msg.match[2]
    phab.updateStatus msg, id, status, (body) ->
      if body['result']['error_info'] is undefined
        msg.send "Ok, T#{id} now has status #{status}."
      else
        msg.send "oops T#{id} #{body['result']['error_info']}"
    msg.finish()


  robot.respond new RegExp(
    'ph(?:ab)?(?: T([0-9]+))? (?:is )?(unbreak|broken|none|unknown|high|normal|low|urgent|wish)$'
  ), (msg) ->
    id = msg.match[1] ? phab.retrievePhid(msg)
    unless id?
      msg.send "Sorry, you don't have any task active right now."
      msg.finish()
      return
    priority = msg.match[2]
    phab.updatePriority msg, id, priority, (body) ->
      if body['result']['error_info'] is undefined
        msg.send "Ok, T#{id} now has priority #{priority}."
      else
        msg.send "oops #{body['result']['error_info']}"
    msg.finish()


  robot.respond /ph(?:ab)? ([^ ]*)$/, (msg) ->
    name = msg.match[1]
    assignee = robot.brain.userForName(name)
    unless assignee
      msg.send "Sorry, I have no idea who #{name} is. Did you mistype it?"
      return
    phab.withUser msg, assignee, (userPhid) ->
      msg.send "Hey I know #{name}, he's #{userPhid}"


  robot.respond /ph(?:ab)? me as (.*@.*)$/, (msg) ->
    email = msg.match[1]
    msg.message.user.email_address = email
    msg.send "Okay, I'll remember your email is #{email}"


  robot.respond /ph(?:ab)? ([^ ]*) *?= *?([^ ]*@.*)$/, (msg) ->
    who = msg.match[1]
    email = msg.match[2]
    assignee = robot.brain.userForName(who)
    unless assignee
      msg.send "Sorry I have no idea who #{who} is. Did you mistype it?"
      return
    assignee.email_address = email
    msg.send "Okay, I'll remember #{who} email as #{email}"


  robot.respond new RegExp(
    'ph(?:ab)?(?: assign)? (?:([^ ]+)(?: (?:to|on) (T)([0-9]+))?|(?:T([0-9]+) )?(?:to|on) ([^ ]+))$'
  ), (msg) ->
    if msg.match[2] is 'T'
      who = msg.match[1]
      what = msg.match[3]
    else
      who = msg.match[5]
      what = msg.match[4]
    id = what ? phab.retrievePhid(msg)
    unless id?
      msg.send "Sorry, you don't have any task active right now."
      msg.finish()
      return
    assignee = robot.brain.userForName(who)
    unless assignee
      if msg.message.user.name is who
        msg.send "Sorry I don't know who you are, can you .phab me as <email>"
      else
        msg.send "Sorry I don't know who is #{who}, can you .phab #{who} = <email>"
      return
    phab.withUser msg, assignee, (userPhid) ->
      # console.log userPhid
      phab.assignTask msg, id, userPhid, (body) ->
        if body['result']['error_info'] is undefined
          msg.send "Ok. T#{id} is now assigned to #{assignee.name}"
        else
          msg.send "#{body['result']['error_info']}"
    msg.finish()


  robot.hear new RegExp(
    "(?:.+|^)(?:(#{process.env.PHABRICATOR_URL})/?| |^)(T|F|P)([0-9]+)"
  ), (msg) ->
    url = msg.match[1]
    type = msg.match[2]
    id = msg.match[3]
    switch type
      when 'T'
        phab.taskInfo msg, id, (body) ->
          if body['error_info']
            msg.send body['error_info']
          else
            closed = ''
            if body['result']['isClosed'] is true
              closed = " (#{body['result']['status']})"
            if url
              msg.send "T#{id}#{closed} - #{body['result']['title']} " +
                       "(#{body['result']['priority']})"
            else
              msg.send "#{body['result']['uri']}#{closed} - #{body['result']['title']} " +
                       "(#{body['result']['priority']})"
            phab.recordPhid msg, id
      when 'F'
        phab.fileInfo msg, id, (body) ->
          if body['error_info']
            msg.send body['error_info']
          else
            size = humanFileSize(body['result']['byteSize'])
            if url
              msg.send "F#{id} - #{body['result']['name']} " +
                       "(#{body['result']['mimeType']} #{size})"
            else
              msg.send "#{body['result']['uri']} - #{body['result']['name']} "+
                       "(#{body['result']['mimeType']} #{size})"
      when 'P'
        phab.pasteInfo msg, id, (body) ->
          if body['error_info']
            msg.send body['error_info']
          else
            for k, v of body['result']
              lang = ''
              if v['language'] isnt ''
                lang = " (#{v['language']})"
              if url
                msg.send "P#{id} - #{v['title']}#{lang}"
              else
                msg.send "#{v['uri']} - #{v['title']}#{lang}"
