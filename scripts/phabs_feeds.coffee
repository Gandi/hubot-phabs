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
moment = require 'moment'

module.exports = (robot) ->

  phab = new Phabricator robot, process.env
  data = robot.brain.data['phabricator']
