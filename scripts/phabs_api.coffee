# Description:
#   kinda proxies the Conduit API with proper REST syntax calls
#
# Configuration:
#   PHABRICATOR_URL
#   PHABRICATOR_API_KEY
#
# Urls:
#   POST /hubot/phabs/api/:project/task
#
# Author:
#   mose
#
# Examples:
#   curl -XPOST -H "Content-Type: application/json" -d @test/samples/create_task.json \
#   http://localhost:8080/hubot/phabs/api/test-project/task

module.exports = (robot) ->

  robot.router.post "/#{robot.name}/phabs/api/:project/task", (req, res) ->
    ip = req.headers['x-forwarded-for'] or req.connection.remoteAddress
    # undefined gives /(?:)/
    ipre = new RegExp(process.env.HUBOT_AUTHORIZED_IP_REGEXP)
    if ipre.test(ip) and req.body.storyID?
      payload = req.body
      payload.project = req.params.project
      robot.emit 'phab.createTask', payload
