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
  robot.respond (/pht new ([-_a-zA-Z0-9]+) (T[0-9]+)$/), (msg) ->
    name = msg.match[1]
    task = msg.match[2]
    msg.send 'Not implemented'

  #   hubot pht show <name>
  robot.respond (/pht show ([-_a-zA-Z0-9]+)$/), (msg) ->
    name = msg.match[1]
    msg.send 'Not implemented'

  #   hubot pht search <term>
  robot.respond (/pht search ([-_a-zA-Z0-9]+)$/), (msg) ->
    term = msg.match[1]
    msg.send 'Not implemented'

  #   hubot pht remove <name>
  robot.respond (/pht remove ([-_a-zA-Z0-9]+)$/), (msg) ->
    name = msg.match[1]
    msg.send 'Not implemented'

  #   hubot pht update <name> T321
  robot.respond (/pht update ([-_a-zA-Z0-9]+) (T[0-9]+)$/), (msg) ->
    name = msg.match[1]
    task = msg.match[2]
    msg.send 'Not implemented'

  #   hubot pht rename <name> <newname>
  robot.respond (/pht rename ([-_a-zA-Z0-9]+) ([-_a-zA-Z0-9]+)$/), (msg) ->
    name = msg.match[1]
    newname = msg.match[2]
    msg.send 'Not implemented'
