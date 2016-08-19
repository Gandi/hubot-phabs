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
# Notes:
#   It's advised to protect this endpoint using
#   hubot-restrict-ip https://github.com/Gandi/hubot-restrict-ip
#   or a nginx/apache proxy
#
# Examples:
#   curl -XPOST -H "Content-Type: application/json" -d @test/samples/create_task.json \
#   http://localhost:8080/hubot/phabs/api/test-project/task

module.exports = (robot) ->

  robot.router.post "/#{robot.name}/phabs/api/:project/task", (req, res) ->
    if req.body.title?
      payload = req.body
      payload.project = req.params.project
      robot.emit 'phab.createTask', payload
      res.status(200).end()
    else
      res.status(422).end()
