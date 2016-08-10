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
# Examples:
#   curl -XPOST -H "Content-Type: application/json" -d @test/samples/payload2 \
#   http://localhost:8080/Hubot/phabs/feeds

Phabricator = require '../lib/phabricator'
module.exports = (robot) ->

  phab = new Phabricator robot, process.env
  data = robot.brain.data['phabricator']

  robot.router.post "/#{robot.name}/phabs/feeds", (req, res) ->
    ip = req.headers['x-forwarded-for'] or req.connection.remoteAddress
    # undefined gives /(?:)/
    ipre = new RegExp(process.env.HUBOT_AUTHORIZED_IP_REGEXP)
    if ipre.test(ip) and req.body.storyID?
      phab.withFeed req.body, (announce) ->
        for room in announce.rooms
          robot.messageRoom room, announce.message
      res.status(200).end()
    else
      res.status(401).end 'Unauthorized.'
