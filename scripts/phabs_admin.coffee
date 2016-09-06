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
  robot.respond (/phad (?:projects|list) *$/), (msg) ->
    if Object.keys(data.projects).length > 0
      msg.send "Known Projects: #{Object.keys(data.projects).join(', ')}"
    else
      msg.send 'There is no project.'

  #   hubot phad delete <project>
  robot.respond (/phad del(?:ete)? (.+) *$/), (msg) ->
    phab.withPermission msg, msg.envelope.user, 'phadmin', ->
      project = msg.match[1]
      if data.projects[project]?
        delete data.projects[project]
        msg.send "#{project} erased from memory."
      else
        msg.send "#{project} not found in memory."

  #   hubot phad info <project>
  robot.respond (/phad (?:info|show) (.+) *$/), (msg) ->
    project = msg.match[1]
    phab.withProject project, (projectData) ->
      if projectData.error_info?
        msg.send projectData.error_info
      else
        response = "'#{project}' is '#{projectData.data.name}'"
        if projectData.aliases? and projectData.aliases.length > 0
          response += " (aka #{projectData.aliases.join(', ')})"
        else
          response += ', with no alias'
        if projectData.data.feeds? and projectData.data.feeds.length > 0
          response += ", announced on #{projectData.data.feeds.join(', ')}"
        else
          response += ', with no feed.'
        msg.send response

  #   hubot phad alias <project> as <alias>
  robot.respond (/phad alias (.+) as (.+)$/), (msg) ->
    phab.withPermission msg, msg.envelope.user, 'phadmin', ->
      project = msg.match[1]
      alias = msg.match[2]
      phab.withProject project, (projectData) ->
        if projectData.error_info?
          msg.send projectData.error_info
        else
          if data.aliases[alias]?
            msg.send "The alias '#{alias}' already exists for project '#{data.aliases[alias]}'."
          else
            data.aliases[alias] = projectData.data.name
            msg.send "Ok, '#{projectData.data.name}' will be known as '#{alias}'."

  #   hubot phad forget <alias>
  robot.respond (/phad forget (.+)$/), (msg) ->
    phab.withPermission msg, msg.envelope.user, 'phadmin', ->
      alias = msg.match[1]
      if data.aliases[alias]
        delete data.aliases[alias]
        msg.send "Ok, the alias '#{alias}' is forgotten."
      else
        msg.send "Sorry, I don't know the alias '#{alias}'."

  #   hubot phad feed <project> to <room>
  robot.respond (/phad feeds? (.+) to (.+)$/), (msg) ->
    phab.withPermission msg, msg.envelope.user, 'phadmin', ->
      project = msg.match[1]
      room = msg.match[2]
      phab.withProject project, (projectData) ->
        if projectData.error_info?
          msg.send projectData.error_info
        else
          projectData.data.feeds ?= [ ]
          if room in projectData.data.feeds
            msg.send "The feed from '#{projectData.data.name}' to '#{room}' already exist."
          else
            data.projects[projectData.data.name].feeds ?= [ ]
            data.projects[projectData.data.name].feeds.push room
            msg.send "Ok, '#{projectData.data.name}' is now feeding '#{room}'."

  #   hubot phad remove <project> from <room>
  robot.respond (/phad remove (.+) from (.+)$/), (msg) ->
    phab.withPermission msg, msg.envelope.user, 'phadmin', ->
      project = msg.match[1]
      room = msg.match[2]
      phab.withProject project, (projectData) ->
        if projectData.error_info?
          msg.send projectData.error_info
        else
          projectData.data.feeds ?= [ ]
          if room in projectData.data.feeds
            idx = data.projects[projectData.data.name].feeds.indexOf room
            data.projects[projectData.data.name].feeds.splice(idx, 1)
            msg.send "Ok, The feed from '#{projectData.data.name}' to '#{room}' was removed."
          else
            msg.send "Sorry, '#{projectData.data.name}' is not feeding '#{room}'."
