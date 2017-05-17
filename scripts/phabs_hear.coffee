# Description:
#   enable communication with Phabricator via Conduit api
#   listens to conversations and supplement with phabricator metadata
#   when an object is cited.
#
# Dependencies:
#
# Configuration:
#   PHABRICATOR_URL
#   PHABRICATOR_API_KEY
#
# Commands:
#   anything Txxx - complements with the title of the cited object
#
# Author:
#   mose

moment = require 'moment'

Phabricator = require '../lib/phabricator'

humanFileSize = (size) ->
  i = Math.floor( Math.log(size) / Math.log(1024) )
  return ( size / Math.pow(1024, i) ).toFixed(2) * 1 + ' ' + ['B', 'kB', 'MB', 'GB', 'TB'][i]

module.exports = (robot) ->

  robot.phab ?= new Phabricator robot, process.env
  phab = robot.phab

  #   anything Txxx - complements with the title of the cited object
  if phab.enabledItemsRegex()?
    robot.hear new RegExp(
      "(?:.+|^)(?:(#{process.env.PHABRICATOR_URL})/?| |^)" +
      phab.enabledItemsRegex()
    ), (msg) ->
      url = msg.match[1]
      type = msg.match[2] ? msg.match[4]
      id = msg.match[3]
      unless phab.isBlacklisted "#{type}#{id}"
        switch
          
          when 'T' is type
            phab.taskInfo(id)
            .then (body) ->
              if body.result.status is 'open'
                ago = moment(body.result.dateCreated, 'X').fromNow()
              else
                ago = moment(body.result.dateModified, 'X').fromNow()
              if url?
                msg.send "#{type}#{id} - #{body.result.title} " +
                         "(#{body.result.priority}, #{body.result.status} #{ago})"
              else
                msg.send "#{body.result.uri} - #{body.result.title} " +
                         "(#{body.result.priority}, #{body.result.status} #{ago})"
              phab.recordId msg.envelope.user, id
            .catch (e) ->
              msg.send "oops #{type}#{id} #{e}"
          
          when 'F' is type
            phab.fileInfo(id)
            .then (body) ->
              size = humanFileSize(body.result.byteSize)
              if url?
                msg.send "#{type}#{id} - #{body.result.name} " +
                         "(#{body.result.mimeType} #{size})"
              else
                msg.send "#{body.result.uri} - #{body.result.name} "+
                         "(#{body.result.mimeType} #{size})"
            .catch (e) ->
              msg.send "oops #{type}#{id} #{e}"

          when 'P' is type
            phab.pasteInfo(id)
            .then (body) ->
              if Object.keys(body.result).length < 1
                msg.send "oops #{type}#{id} was not found."
              else
                lang = ''
                key = Object.keys(body.result)[0]
                if body.result[key]['language']? and body.result[key]['language'] isnt ''
                  lang = "#{body.result[key].language}, "
                ago = moment(body.result[key].dateCreated, 'X').fromNow()
                if url?
                  msg.send "#{type}#{id} - #{body.result[key].title} (#{lang}created #{ago})"
                else
                  msg.send "#{body.result[key].uri} - #{body.result[key].title} (#{lang}created #{ago})"
            .catch (e) ->
              msg.send "oops #{type}#{id} #{e}"

          when /^(D|M|B|Q|L|V)$/.test type
            phab.genericInfo("#{type}#{id}")
            .then (body) ->
              if Object.keys(body.result).length < 1
                msg.send "oops #{type}#{id} was not found."
              else
                v = body.result["#{type}#{id}"]
                status = ''
                if v.status is 'closed'
                  status = " (#{v.status})"
                if url?
                  msg.send "#{v.fullName}#{status}"
                else
                  fullname = v.fullName.replace("#{type}#{id}: ", '').replace("#{type}#{id} ", '')
                  msg.send "#{v.uri} - #{fullname}#{status}"
            .catch (e) ->
              msg.send "oops #{type}#{id} #{e}"

          when /^r[A-Z]+[a-f0-9]{10,}$/.test type
            phab.genericInfo(type)
            .then (body) ->
              if Object.keys(body.result).length < 1
                msg.send "oops #{type} was not found."
              else
                v = body.result[type]
                status = ''
                if v['status'] is 'closed'
                  status = " (#{v.status})"
                if url?
                  msg.send "#{v.fullName}#{status}"
                else
                  fullname = v.fullName.replace "#{type}: ", ''
                  msg.send "#{v.uri} - #{fullname}#{status}"
            .catch (e) ->
              msg.send "oops #{type} #{e}"
