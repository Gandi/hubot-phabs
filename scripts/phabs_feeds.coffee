# Description:
#   enable http listener for Phabricator feed_http
#
# Configuration:
#   PHABRICATOR_URL
#   PHABRICATOR_API_KEY
#
# Urls:
#   /hubot/phabs/feeds
#
# Author:
#   mose
#
# Notes:
#   It's advised to protect this endpoint using
#   hubot-restrict-ip https://github.com/Gandi/hubot-restrict-ip
#   or a nginx/apache proxy
#
# Examples:
#   curl -XPOST -H "Content-Type: application/json" -d @test/samples/payload2 \
#   http://localhost:8080/Hubot/phabs/feeds

Phabricator = require '../lib/phabricator'
module.exports = (robot) ->

  robot.phab ?= new Phabricator robot, process.env
  phab = robot.phab

  #   hubot phab <user> set alerts - private messages sent to user on task subscribed or owned
  #   hubot phab me set alerts - private messages sent to user on task subscribed or owned
  robot.respond /ph(?:ab)? ([^ ]*) set alerts *$/, (msg) ->
    assigned = msg.match[1]
    if assigned is 'me'
      perm = 'phuser'
      assigned = msg.envelope.user.name
    else
      perm = 'phadmin'
    phab.getPermission(msg.envelope.user, perm)
    .then ->
      phab.getUser(msg.envelope.user, { name: assigned })
    .then (userPhid) ->
      phab.setAlerts(assigned, userPhid)
    .then ->
      if assigned is msg.envelope.user.name
        msg.send 'Ok, you will now receive private messages when your owned' +
                 ' or subscribed items are modified.'
      else
        msg.send "Ok, #{assigned} will now receive private messages when their owned" +
                 ' or subscribed items are modified.'
    .catch (e) ->
      msg.send e
    msg.finish()

  #   hubot phab <user> unset alerts - remove an alert flag for user
  #   hubot phab me set unalerts - remove an alert flag for caller
  robot.respond /ph(?:ab)? ([^ ]*) unset alerts *$/, (msg) ->
    assigned = msg.match[1]
    if assigned is 'me'
      perm = 'phuser'
      assigned = msg.envelope.user.name
    else
      perm = 'phadmin'
    phab.getPermission(msg.envelope.user, perm)
    .then ->
      phab.unsetAlerts(assigned)
    .then ->
      if assigned is msg.envelope.user.name
        msg.send 'Ok, you will stop receiving private messages when your owned' +
                 ' or subscribed items are modified.'
      else
        msg.send "Ok, #{assigned} will stop receiving private messages when their owned" +
                 ' or subscribed items are modified.'
    .catch (e) ->
      msg.send e
    msg.finish()

  robot.router.post "/#{robot.name}/phabs/feeds", (req, res) ->
    console.log req.body
    if req.body.storyID?
      phab.getFeed(req.body)
      .then (announce) ->
        console.log announce
        for room in announce.rooms
          robot.messageRoom room, announce.message
        for user in announce.users
          robot.messageRoom user, announce.message
        robot.logger.debug "#{req.ip} - ok - #{res.statusCode}"
      .catch (e) ->
        robot.logger.debug "#{req.ip} - no - #{res.statusCode} - #{e}"
      res.status(200).end()
    else
      robot.logger.debug "#{req.ip} - no - #{res.statusCode} - no story"
      res.status(422).end()
