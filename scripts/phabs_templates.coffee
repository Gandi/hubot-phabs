# Description:
#   manages the concept of templating for Phabricator Tasks
#
# Dependencies:
#
# Configuration:
#   PHABRICATOR_URL
#   PHABRICATOR_API_KEY
#
# Commands:
#   hubot pht new <name> T123
#   hubot pht show <name>
#   hubot pht search <term>
#   hubot pht remove <name>
#   hubot pht update <name> T321
#   hubot pht rename <name> <newname>
#
# Author:
#   mose

Phabricator = require '../lib/phabricator'

module.exports = (robot) ->

  phab = new Phabricator robot, process.env
  data = robot.brain.data['phabricator']

  #   hubot pht new <name> T123
  robot.respond (/pht new ([-_a-zA-Z0-9]+) T([0-9]+)$/), (msg) ->
    phab.withPermission msg, msg.envelope.user, 'phadmin', ->
      name = msg.match[1]
      taskid = msg.match[2]
      phab.addTemplate name, taskid, (body) ->
        if body.error_info?
          msg.send body.error_info
        else
          msg.send "Ok. Template '#{name}' will use T#{taskid}."

  #   hubot pht show <name>
  robot.respond (/pht show ([-_a-zA-Z0-9]+)$/), (msg) ->
    phab.withPermission msg, msg.envelope.user, 'phuser', ->
      name = msg.match[1]
      phab.showTemplate name, (body) ->
        if body.error_info?
          msg.send body.error_info
        else
          msg.send "Ok. Template '#{name}' uses T#{body.task}."

  #   hubot pht search <term>
  robot.respond (/pht search ([-_a-zA-Z0-9]+)$/), (msg) ->
    phab.withPermission msg, msg.envelope.user, 'phuser', ->
      term = msg.match[1]
      phab.searchTemplate term, (body) ->
        if body.error_info?
          msg.send body.error_info
        else
          for found in body.results
            msg.send "Template '#{found.name}' uses T#{found.task}."

  #   hubot pht remove <name>
  robot.respond (/pht remove ([-_a-zA-Z0-9]+)$/), (msg) ->
    phab.withPermission msg, msg.envelope.user, 'phadmin', ->
      name = msg.match[1]
      msg.send 'Not implemented'

  #   hubot pht update <name> T321
  robot.respond (/pht update ([-_a-zA-Z0-9]+) T([0-9]+)$/), (msg) ->
    phab.withPermission msg, msg.envelope.user, 'phadmin', ->
      name = msg.match[1]
      taskid = msg.match[2]
      msg.send 'Not implemented'

  #   hubot pht rename <name> <newname>
  robot.respond (/pht rename ([-_a-zA-Z0-9]+) ([-_a-zA-Z0-9]+)$/), (msg) ->
    phab.withPermission msg, msg.envelope.user, 'phadmin', ->
      name = msg.match[1]
      newname = msg.match[2]
      msg.send 'Not implemented'
