# Description:
#   enable http listener for Phabricator feed_http
#
# Dependencies:
#
# Configuration:
#   PHABRICATOR_URL
#   PHABRICATOR_API_KEY
#   PHABRICATOR_BOT_PHID
#
# Commands:
#
# http endpoints
#   /hubot/phabs/feeds
#
# Author:
#   mose

Phabricator = require '../lib/phabricator'
module.exports = (robot) ->

  phab = new Phabricator robot, process.env
  data = robot.brain.data['phabricator']

  robot.router.post "/#{robot.name}/phabs/feeds", (req, res) ->
    phab.withFeed robot, req.body, (announce) ->
      for room of announce.rooms
        robot.messageRoom room, announce.message
    res.status(200).end()
