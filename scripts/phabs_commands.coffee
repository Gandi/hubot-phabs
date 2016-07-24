# Description:
#   enable communication with Phabricator via Conduit api
#
# Dependencies:
#
# Configuration:
#   PHABRICATOR_URL
#   PHABRICATOR_API_KEY
#   PHABRICATOR_BOT_PHID
#
# Commands:
#   hubot phab version - give the version of hubot-phabs loaded
#   hubot phab new <project> <name of the task> - creates a new task
#   hubot phab paste <name of the paste> - creates a new paste
#   hubot phab count <project> - counts how many tasks a project has
#   hubot phab Txx - gives information about task Txxx
#   hubot phab Txx is <status> - modifies task Txxx status
#   hubot phab Txx is <priority> - modifies task Txxx priority
#   hubot phab assign Txx to <user> - assigns task Txxx to comeone
#   hubot phab <user> - checks if user is known or not
#   hubot phab me as <email> - makes caller known with <email>
#   hubot phab <user> = <email> - associates user to email
#
# Author:
#   mose

Phabricator = require '../lib/phabricator'
moment = require 'moment'
path = require 'path'

module.exports = (robot) ->
  phab = new Phabricator robot, process.env

  #   hubot phab version - give the version of hubot-phabs loaded
  robot.respond /ph(?:ab)? version$/, (msg) ->
    pkg = require path.join __dirname, '..', 'package.json'
    msg.send "hubot-phabs module is version #{pkg.version}"
    msg.finish()

  #   hubot phab new <project> <name of the task> - creates a new task
  robot.respond (/ph(?:ab)? new ([-_a-zA-Z0-9]+) ([^=]*)(?: = (.*))?$/), (msg) ->
    project = msg.match[1]
    name = msg.match[2]
    description = msg.match[3]
    phab.withProject msg, project, (projectData) ->
      phab.createTask msg, projectData.phid, name, description, (body) ->
        if body['error_info']?
          msg.send "#{body['error_info']}"
        else
          id = body['result']['object']['id']
          url = process.env.PHABRICATOR_URL + "/T#{id}"
          phab.recordPhid msg, id
          msg.send "Task T#{id} created = #{url}"

  #   hubot phab paste <name of the paste> - creates a new paste
  robot.respond /ph(?:ab)? paste (.*)$/, (msg) ->
    title = msg.match[1]
    phab.createPaste msg, title, (body) ->
      if body['error_info']?
        msg.send "#{body['error_info']}"
      else
        id = body['result']['object']['id']
        url = process.env.PHABRICATOR_URL + "/paste/edit/#{id}"
        phab.recordPhid msg, id
        msg.send "Paste P#{id} created = edit on #{url}"

  #   hubot phab count <project> - counts how many tasks a project has
  robot.respond (/ph(?:ab)? count ([-_a-zA-Z0-9]+)/), (msg) ->
    phab.withProject msg, msg.match[1], (projectData) ->
      phab.listTasks msg, projectData.phid, (body) ->
        if Object.keys(body['result']).length is 0
          msg.send "#{projectData.name} has no tasks."
        else
          msg.send "#{projectData.name} has #{Object.keys(body['result']).length} tasks."

  #   hubot phab Txx - gives information about task Txxx
  robot.respond /ph(?:ab)?(?: T([0-9]+) ?)?$/, (msg) ->
    id = msg.match[1] ? phab.retrievePhid(msg)
    unless id?
      msg.send "Sorry, you don't have any task active right now."
      msg.finish()
      return
    phab.taskInfo msg, id, (body) ->
      if body['error_info']?
        msg.send "oops T#{id} #{body['error_info']}"
      else
        phab.withUserByPhid robot, body.result.ownerPHID, (owner) ->
          status = body.result.status
          priority = body.result.priority
          phab.recordPhid msg, id
          msg.send "T#{id} has status #{status}, " +
                   "priority #{priority}, owner #{owner.name}"
    msg.finish()

  #   hubot phab Txx is <status> - modifies task Txxx status
  robot.respond new RegExp(
    "ph(?:ab)?(?: T([0-9]+))? (?:is )?(#{Object.keys(phab.statuses).join('|')})$"
  ), (msg) ->
    id = msg.match[1] ? phab.retrievePhid(msg)
    unless id?
      msg.send "Sorry, you don't have any task active right now."
      msg.finish()
      return
    status = msg.match[2]
    phab.updateStatus msg, id, status, (body) ->
      if body['error_info']?
        msg.send "oops T#{id} #{body['error_info']}"
      else
        msg.send "Ok, T#{id} now has status #{body['result']['statusName']}."
    msg.finish()

  #   hubot phab Txx is <priority> - modifies task Txxx priority
  robot.respond new RegExp(
    "ph(?:ab)?(?: T([0-9]+))? (?:is )?(#{Object.keys(phab.priorities).join('|')})$"
  ), (msg) ->
    id = msg.match[1] ? phab.retrievePhid(msg)
    unless id?
      msg.send "Sorry, you don't have any task active right now."
      msg.finish()
      return
    priority = msg.match[2]
    phab.updatePriority msg, id, priority, (body) ->
      if body['error_info']?
        msg.send "oops T#{id} #{body['error_info']}"
      else
        msg.send "Ok, T#{id} now has priority #{body['result']['priority']}"
    msg.finish()

  #   hubot phab <user> - checks if user is known or not
  robot.respond /ph(?:ab)? ([^ ]*)$/, (msg) ->
    name = msg.match[1]
    assignee = robot.brain.userForName(name)
    unless assignee
      msg.send "Sorry, I have no idea who #{name} is. Did you mistype it?"
      return
    phab.withUser msg, assignee, (userPhid) ->
      msg.send "Hey I know #{name}, he's #{userPhid}"

  #   hubot phab me as <email> - makes caller known with <email>
  robot.respond /ph(?:ab)? me as (.*@.*)$/, (msg) ->
    email = msg.match[1]
    msg.message.user.email_address = email
    robot.brain.save()
    msg.send "Okay, I'll remember your email is #{email}"

  #   hubot phab <user> = <email> - associates user to email
  robot.respond /ph(?:ab)? ([^ ]*) *?= *?([^ ]*@.*)$/, (msg) ->
    who = msg.match[1]
    email = msg.match[2]
    assignee = robot.brain.userForName(who)
    unless assignee
      msg.send "Sorry I have no idea who #{who} is. Did you mistype it?"
      return
    assignee.email_address = email
    msg.send "Okay, I'll remember #{who} email as #{email}"

  #   hubot phab assign Txx to <user> - assigns task Txxx to comeone
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
    if assignee?
      phab.withUser msg, assignee, (userPhid) ->
        phab.assignTask msg, id, userPhid, (body) ->
          if body['error_info']?
            msg.send "#{body['error_info']}"
          else
            msg.send "Ok. T#{id} is now assigned to #{assignee.name}"
    else
      msg.send "Sorry I don't know who is #{who}, can you .phab #{who} = <email>"
    msg.finish()
