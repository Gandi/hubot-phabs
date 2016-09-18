# Description:
#   enable communication with Phabricator via Conduit api
#
# Dependencies:
#
# Configuration:
#   PHABRICATOR_URL
#   PHABRICATOR_API_KEY
#
# Commands:
#   hubot phad projects
#   hubot phad delete <project>
#   hubot phad info <project>
#   hubot phad alias <project> as <alias>
#   hubot phad forget <alias>
#   hubot phad feed <project> to <room>
#   hubot phad remove <project> from <room>
#
# Author:
#   mose

Phabricator = require '../lib/phabricator'
moment = require 'moment'
path = require 'path'

module.exports = (robot) ->

  phab = new Phabricator robot, process.env
  data = robot.brain.data.phabricator

  #   hubot phad projects
  robot.respond /phad (?:projects|list) *$/, (msg) ->
    if Object.keys(data.projects).length > 0
      msg.send "Known Projects: #{Object.keys(data.projects).join(', ')}"
    else
      msg.send 'There is no project.'

  #   hubot phad delete <project>
  robot.respond /phad del(?:ete)? (.+) *$/, (msg) ->
    project = msg.match[1].toLowerCase()
    phab.getPermission(msg.envelope.user, 'phadmin')
    .then ->
      if data.projects[project]?
        delete data.projects[project]
        msg.send "#{project} erased from memory."
      else
        msg.send "#{project} not found in memory."
    .catch (e) ->
      msg.send e

  #   hubot phad info <project>
  robot.respond /phad (?:info|show) (.+) *$/, (msg) ->
    project = msg.match[1].toLowerCase()
    phab.getProject(project)
    .then (proj) ->
      response = "'#{project}' is '#{proj.data.name}'"
      if proj.aliases? and proj.aliases.length > 0
        response += " (aka #{proj.aliases.join(', ')})"
      else
        response += ', with no alias'
      if proj.data.feeds? and proj.data.feeds.length > 0
        response += ", announced on #{proj.data.feeds.join(', ')}"
      else
        response += ', with no feed.'
      msg.send response
    .catch (e) ->
      msg.send e

  #   hubot phad alias <project> as <alias>
  robot.respond /phad alias (.+) as (.+)$/, (msg) ->
    project = msg.match[1].toLowerCase()
    alias = msg.match[2]
    phab.getPermission(msg.envelope.user, 'phadmin')
    .then ->
      phab.getProject(project)
    .then (proj) ->
      if data.aliases[alias]?
        msg.send "The alias '#{alias}' already exists for project '#{data.aliases[alias]}'."
      else
        data.aliases[alias] = proj.data.name.toLowerCase()
        msg.send "Ok, '#{proj.data.name}' will be known as '#{alias}'."
    .catch (e) ->
      msg.send e

  #   hubot phad forget <alias>
  robot.respond /phad forget (.+)$/, (msg) ->
    alias = msg.match[1]
    phab.getPermission(msg.envelope.user, 'phadmin')
    .then ->
      if data.aliases[alias]
        delete data.aliases[alias]
        msg.send "Ok, the alias '#{alias}' is forgotten."
      else
        msg.send "Sorry, I don't know the alias '#{alias}'."
    .catch (e) ->
      msg.send e

  #   hubot phad feed <project> to <room>
  robot.respond /phad feeds? (.+) to (.+)$/, (msg) ->
    project = msg.match[1].toLowerCase()
    room = msg.match[2]
    phab.getPermission(msg.envelope.user, 'phadmin')
    .then ->
      phab.getProject(project)
    .then (proj) ->
      proj.data.feeds ?= [ ]
      if room in proj.data.feeds
        msg.send "The feed from '#{proj.data.name}' to '#{room}' already exist."
      else
        data.projects[proj.data.name].feeds ?= [ ]
        data.projects[proj.data.name].feeds.push room
        msg.send "Ok, '#{proj.data.name}' is now feeding '#{room}'."
    .catch (e) ->
      msg.send e

  #   hubot phad remove <project> from <room>
  robot.respond /phad remove (.+) from (.+)$/, (msg) ->
    project = msg.match[1].toLowerCase()
    room = msg.match[2]
    phab.getPermission(msg.envelope.user, 'phadmin')
    .then ->
      phab.getProject(project)
    .then (proj) ->
      proj.data.feeds ?= [ ]
      if room in proj.data.feeds
        idx = data.projects[proj.data.name].feeds.indexOf room
        data.projects[proj.data.name].feeds.splice(idx, 1)
        msg.send "Ok, The feed from '#{proj.data.name}' to '#{room}' was removed."
      else
        msg.send "Sorry, '#{proj.data.name}' is not feeding '#{room}'."
    .catch (e) ->
      msg.send e
