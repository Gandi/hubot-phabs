# Description:
#   declare events usable programmaticaly by other commands
#
# Dependencies:
#
# Configuration:
#   PHABRICATOR_URL
#   PHABRICATOR_API_KEY
#
# Commands:
#
# Author:
#   mose

Phabricator = require '../lib/phabricator'

module.exports = (robot) ->

  phab = new Phabricator robot, process.env

  # robot.respond (
  #   /phtest new ([-_a-zA-Z0-9]+)(?::([-_a-zA-Z0-9]+))? ([^=]+)(?: *@([^=]+))?(?: = (.*))?$/
  # ), (msg) ->
  #   phab.withPermission msg, msg.envelope.user, 'phuser', ->
  #     data =
  #       project: msg.match[1]
  #       template: msg.match[2]
  #       title: msg.match[3]
  #       description: msg.match[5]
  #       user: msg.envelope.user
  #       assign: msg.match[4]
  #     robot.emit 'phab.createTask', data

  robot.on 'phab.createTask', (data) ->
    phab.createTask data, (res) ->
      if res.error_info?
        robot.logger.error res.error_info
      else
        robot.logger.info "Task T#{res.id} created = #{res.url}"
