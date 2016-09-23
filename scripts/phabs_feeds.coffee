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

  robot.router.post "/#{robot.name}/phabs/feeds", (req, res) ->
    if req.body.storyID?
      phab.getFeed(req.body)
      .then (announce) ->
        for room in announce.rooms
          robot.messageRoom room, announce.message
        robot.logger.debug "#{req.ip} - ok - #{res.statusCode}"
      .catch (e) ->
        robot.logger.debug "#{req.ip} - no - #{res.statusCode} - #{e}"
      res.status(200).end()
    else
      robot.logger.debug "#{req.ip} - no - #{res.statusCode} - no story"
      res.status(422).end()
