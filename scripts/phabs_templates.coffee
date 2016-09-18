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

  #   hubot pht new <name> T123
  robot.respond (/pht new ([-_a-zA-Z0-9]+) T([0-9]+) *$/), (msg) ->
    name = msg.match[1]
    taskid = msg.match[2]
    phab.getPermission(msg.envelope.user, 'phadmin')
    .then ->
      phab.addTemplate(name, taskid)
    .then (body) ->
      msg.send "Ok. Template '#{name}' will use T#{taskid}."
    .catch (e) ->
      msg.send e
    msg.finish()
    

  #   hubot pht show <name>
  robot.respond (/pht (?:show|info) ([-_a-zA-Z0-9]+) *$/), (msg) ->
    name = msg.match[1]
    phab.getPermission(msg.envelope.user, 'phuser')
    .then ->
      phab.showTemplate(name)
    .then (body) ->
      msg.send "Template '#{name}' uses T#{body.task}."
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot pht search <term>
  robot.respond (/pht (?:search|list) *([-_a-zA-Z0-9]+)? *$/), (msg) ->
    term = msg.match[1]
    phab.getPermission(msg.envelope.user, 'phuser')
    .then ->
      phab.searchTemplate(term)
    .then (body) ->
      for found in body
        msg.send "Template '#{found.name}' uses T#{found.task}."
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot pht remove <name>
  robot.respond (/pht remove ([-_a-zA-Z0-9]+) *$/), (msg) ->
    name = msg.match[1]
    phab.getPermission(msg.envelope.user, 'phadmin')
    .then ->
      phab.removeTemplate(name)
    .then (body) ->
      msg.send "Ok. Template '#{name}' was removed."
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot pht update <name> T321
  robot.respond (/pht update ([-_a-zA-Z0-9]+) T([0-9]+) *$/), (msg) ->
    name = msg.match[1]
    taskid = msg.match[2]
    phab.getPermission(msg.envelope.user, 'phadmin')
    .then ->
      phab.updateTemplate(name, taskid)
    .then (body) ->
      msg.send "Ok. Template '#{name}' will now use T#{taskid}."
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot pht rename <name> <newname>
  robot.respond (/pht rename ([-_a-zA-Z0-9]+) ([-_a-zA-Z0-9]+) *$/), (msg) ->
    name = msg.match[1]
    newname = msg.match[2]
    phab.getPermission(msg.envelope.user, 'phadmin')
    .then ->
      phab.renameTemplate(name, newname)
    .then (body) ->
      msg.send "Ok. Template '#{name}' will now bew known as '#{newname}'."
    .catch (e) ->
      msg.send e
    msg.finish()
