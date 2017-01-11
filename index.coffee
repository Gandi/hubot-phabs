path = require 'path'

phabs_available_features = [
  'events',
  'api',
  'commands',
  'templates',
  'admin',
  'feeds',
  'hear'
]

phabs_features = if process.env.PHABS_ENABLED_FEATURES?
  enabled = process.env.PHABS_ENABLED_FEATURES.split(',')
  phabs_available_features.reduce (a, f) ->
    a.push f if f in enabled
    a
  , [ ]
else if process.env.PHABS_DISABLED_FEATURES?
  disabled = process.env.PHABS_DISABLED_FEATURES.split(',')
  phabs_available_features.reduce (a, f) ->
    a.push f if f not in disabled
    a
  , [ ]
else
  phabs_available_features

module.exports = (robot) ->
  for feature in phabs_features
    robot.logger.debug "Loading phabs_#{feature}"
    robot.loadFile(path.resolve(__dirname, 'scripts'), "phabs_#{feature}.coffee")
