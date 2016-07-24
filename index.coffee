path = require 'path'

module.exports = (robot) ->
  robot.loadFile(path.resolve(__dirname, 'scripts'), 'phabs.coffee')
  robot.loadFile(path.resolve(__dirname, 'scripts'), 'phabs_hear.coffee')
  robot.loadFile(path.resolve(__dirname, 'scripts'), 'phabs_admin.coffee')
