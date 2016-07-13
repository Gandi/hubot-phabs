# Description:
#   enable communication with Phabricator via Conduit api
#
# Dependencies:
#
# Configuration:
# PHABRICATOR_URL
# PHABRICATOR_API_KEY
# PHABRICATOR_PROJECTS
#
# Commands:
#   <bot> phab new <board> <name of the card>
#
# Author:
#   mose

Phabricator = require '../lib/phabricator'

phabColumns = {}
if process.env.PHABRICATOR_PROJECTS != undefined
  for list in process.env.PHABRICATOR_PROJECTS.split(',')
    [code, label] = list.split ':'
    phabColumns[label] = code

module.exports = (robot) ->
  phab = new Phabricator robot, process.env

  robot.respond (/ph(?:ab)? help/i), (msg) ->
    text =  "  phab new <board> <name of a new card>\n"
    text += "       creates a new card in a given column in Phabricator.\n"
    text += "       Known columns are #{Object.keys(phabColumns).join(', ')}.\n"
    msg.send text


  robot.respond (/ph(?:ab)? new ([a-z]+) (.+)/i), (msg) ->
    column = phabColumns[msg.match[1]]
    name = msg.match[2]
    if column and name
      phab.createTask msg, column, name, (body) ->
        if body['error_info']
          msg.send "#{body['error_info']}"
        else
          id = body['result']['object']["id"]
          url = process.env.PHABRICATOR_URL + "/T#{id}"
          msg.send "Task T#{id} created = #{url}"
    else
      msg.send "Command incomplete."


  robot.respond /ph(?:ab)? ([^ ]*)$/i, (msg) ->
    name = msg.match[1]
    assignee = robot.brain.userForName(name)
    unless assignee
      msg.send "Sorry I have no idea who #{name} is. Did you mistype it?"
      return
    phab.withUser msg, assignee, (userPhid) ->
      msg.send "Hey I know #{name}, he's #{userPhid}"


  robot.respond /ph(?:ab)? me as (.*@.*)$/i, (msg) ->
    email = msg.match[1]
    msg.message.user.email_address = email
    msg.send "Okay, I'll remember your email is #{email}"


  robot.respond /ph(?:ab)? ([^ ]*) *?= *?([^ ]*@.*)$/i, (msg) ->
    who = msg.match[1]
    email = msg.match[2]
    assignee = robot.brain.userForName(who)
    unless assignee
      msg.send "Sorry I have no idea who #{who} is. Did you mistype it?"
      return
    assignee.email_address = email
    msg.send "Okay, I'll remember #{who} email as #{email}"


  robot.respond /ph(?:ab)? assign (?:([^ ]+) (?:to|on) (T)([0-9]+)|T([0-9]+) (?:to|on) ([^ ]+))$/i, (msg) ->
    if msg.match[2] == "T"
      who = msg.match[1]
      what = msg.match[3]
    else
      who = msg.match[5]
      what = msg.match[4]
    assignee = robot.brain.userForName(who)
    unless assignee
      if msg.message.user.name == who
        msg.send "Sorry I don't know who you are, can you .phab me as <email>"
      else
        msg.send "Sorry I don't know who is #{who}, can you .phab #{who} = <email>"
      return
    phab.withUser msg, assignee, (userPhid) ->
      # console.log userPhid
      phab.assignTask msg, what, userPhid, (body) ->
        if body['result']['error_info'] == undefined
          msg.send "Ok. T#{what} is now assigned to #{assignee.name}"
        else
          msg.send "#{body['result']['error_info']}"


  robot.hear new RegExp("(\.ph(?:ab)? )?(?:.+)?(?:(#{process.env.PHABRICATOR_URL})/?| |^)(T|F|P)([0-9]+)"), (msg) ->
    if msg.match[1] == undefined
      url = msg.match[2]
      type = msg.match[3]
      id = msg.match[4]
      switch type
        when 'T'
          phab.taskInfo msg, id, (body) ->
            if body['error_info']
              msg.send body['error_info']
            else
              if url
                msg.send "T#{id} - #{body['result']['title']}"
              else
                msg.send "#{body['result']['uri']} - #{body['result']['title']}"
        when 'F'
          phab.fileInfo msg, id, (body) ->
            if body['error_info']
              msg.send body['error_info']
            else
              size = humanFileSize(body['result']['byteSize'])
              if url
                msg.send "T#{id} - #{body['result']['name']} (#{body['result']['mimeType']} #{size})"
              else
                msg.send "#{body['result']['uri']} - #{body['result']['name']} (#{body['result']['mimeType']} #{size})"
        when 'P'
          phab.pasteInfo msg, id, (body) ->
            if body['error_info']
              msg.send body['error_info']
            else
              for k, v of body['result']
                lang = ''
                if v['language'] != ''
                  lang = " (#{v['language']})"
                if url
                  msg.send "T#{id} - #{v['title']}#{lang}"
                else
                  msg.send "#{v['uri']} - #{v['title']}#{lang}"
