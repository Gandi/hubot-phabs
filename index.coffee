path = require 'path'

module.exports = (robot) ->
  robot.loadFile(path.resolve(__dirname, 'scripts'), 'phabs_events.coffee')
  unless process.env.PHABS_NO_API?
    robot.loadFile(path.resolve(__dirname, 'scripts'), 'phabs_api.coffee')
  robot.loadFile(path.resolve(__dirname, 'scripts'), 'phabs_commands.coffee')
  robot.loadFile(path.resolve(__dirname, 'scripts'), 'phabs_templates.coffee')
  robot.loadFile(path.resolve(__dirname, 'scripts'), 'phabs_admin.coffee')
  robot.loadFile(path.resolve(__dirname, 'scripts'), 'phabs_feeds.coffee')
  robot.loadFile(path.resolve(__dirname, 'scripts'), 'phabs_hear.coffee')
