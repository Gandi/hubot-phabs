# Description:
#   requests Phabricator Conduit api
#
# Dependencies:
#
# Configuration:
#  PHABRICATOR_URL
#  PHABRICATOR_API_KEY
#  PHABRICATOR_BOT_PHID
#  PHABRICATOR_TRUSTED_USERS
#
# Author:
#   mose

querystring = require 'querystring'
moment = require 'moment'

class Phabricator

  statuses: {
    'open': 'open',
    'opened': 'open',
    'resolved': 'resolved',
    'resolve': 'resolved',
    'closed': 'resolved',
    'close': 'resolved',
    'wontfix': 'wontfix',
    'noway': 'wontfix',
    'invalid': 'invalid',
    'rejected': 'invalid',
    'spite': 'spite',
    'lame': 'spite'
  }

  priorities: {
    'unbreak': 100,
    'broken': 100,
    'need triage': 90,
    'none': 90,
    'unknown': 90,
    'low': 25,
    'normal': 50,
    'high': 80,
    'urgent': 80,
    'wish': 0
  }

  constructor: (@robot, env) ->
    @url = env.PHABRICATOR_URL
    @apikey = env.PHABRICATOR_API_KEY
    @bot_phid = env.PHABRICATOR_BOT_PHID
    storageLoaded = =>
      @data = @robot.brain.data.phabricator ||= {
        projects: { },
        aliases: { }
      }
      @robot.logger.debug 'Phabricator Data Loaded: ' + JSON.stringify(@data, null, 2)
    @robot.brain.on 'loaded', storageLoaded
    storageLoaded() # just in case storage was loaded before we got here


  ready: (msg) ->
    msg.send 'Error: Phabricator url is not specified' if not @url
    msg.send 'Error: Phabricator api key is not specified' if not @apikey
    return false unless (@url and @apikey)
    true


  phabGet: (msg, query, endpoint, cb) ->
    query['api.token'] = process.env.PHABRICATOR_API_KEY
    # console.log query
    body = querystring.stringify(query)
    msg.http(process.env.PHABRICATOR_URL)
      .path("api/#{endpoint}")
      .get(body) (err, res, payload) ->
        json_body = null
        if res?
          switch res.statusCode
            when 200
              if res.headers['content-type'] is 'application/json'
                json_body = JSON.parse(payload)
              else
                json_body = {
                  result: { },
                  error_code: 'ENOTJSON',
                  error_info: 'api did not deliver json'
                }
            else
              json_body = {
                result: { },
                error_code: res.statusCode,
                error_info: "http error #{res.statusCode}"
              }
        else
          json_body = {
            result: { },
            error_code: err.code,
            error_info: err.message
          }
        cb json_body


  withFeed: (robot, payload, cb) ->
    # console.log payload
    if /^PHID-TASK-/.test payload.storyData.objectPHID
      query = {
        'constraints[phids][0]': payload.storyData.objectPHID,
        'attachments[projects]': 1
      }
      data = @data
      @phabGet robot, query, 'maniphest.search', (json_body) ->
        announces = {
          message: payload.storyText
        }
        announces.rooms = []
        for phid in json_body.result.data[0].attachments.projects.projectPHIDs
          for name, project of data.projects
            if project.phid? and phid is project.phid
              project.feeds ?= [ ]
              for room in project.feeds
                if announces.rooms.indexOf(room) is -1
                  announces.rooms.push room
        cb announces
    # else
    #   console.log 'This is not a task.'

  withProject: (msg, project, cb) ->
    if @data.projects[project]?
      projectData = @data.projects[project]
      projectData.name = project
    else
      for a, p of @data.aliases
        if a is project and @data.projects[p]?
          projectData = @data.projects[p]
          projectData.name = p
          break
    aliases = []
    if projectData?
      for a, p of @data.aliases
        if p is projectData.name
          aliases.push a
      if projectData.phid?
        cb { aliases: aliases, data: projectData }
      else
        query = { 'names[0]': projectData.name }
        @phabGet msg, query, 'project.query', (json_body) ->
          if Object.keys(json_body.result.data).length > 0
            projectData.phid = Object.keys(json_body.result.data)[0]
            cb { aliases: aliases, data: projectData }
          else
            msg.send "Sorry, #{project} not found."
    else
      data = @data
      query = { 'names[0]': project }
      @phabGet msg, query, 'project.query', (json_body) ->
        if json_body.result.data.length > 0 or Object.keys(json_body.result.data).length > 0
          phid = Object.keys(json_body.result.data)[0]
          data.projects[project] = { phid: phid }
          projectData = {
            name: json_body.result.data[phid].name
          }
          cb { aliases: aliases, data: projectData }
        else
          msg.send "Project #{project} not found."


  withUser: (msg, user, cb) ->
    if @ready(msg) is true
      id = user.phid
      if id
        cb(id)
      else
        email = user.email_address or user.pagerdutyEmail
        unless email
          if msg.envelope.user.name is user.name
            msg.send "Sorry, I can't figure out your email address :( " +
                     'Can you tell me with `.phab me as you@yourdomain.com`?'
          else
            msg.send "Sorry, I can't figure #{user.name} email address. " +
                     "Can you help me with .phab #{user.name} = <email>"
          return
        query = { 'emails[0]': email }
        @phabGet msg, query, 'user.query', (json_body) ->
          unless json_body['result']['0']?
            msg.send "Sorry, I cannot find #{email} :("
            return
          user.phid = json_body['result']['0']['phid']
          cb user.phid


  withUserByPhid: (robot, phid, cb) ->
    if phid?
      user = null
      for k of robot.brain.data.users
        thisphid = robot.brain.data.users[k].phid
        if thisphid? and thisphid is phid
          user = robot.brain.data.users[k]
          break
      if user?
        cb user
      else
        query = { 'phids[0]': phid }
        @phabGet robot, query, 'user.query', (json_body) ->
          if json_body['result']['0']?
            cb { name: json_body['result']['0']['userName'] }
          else
            cb { name: 'unknown' }
    else
      cb { name: 'nobody' }


  withPermission: (msg, user, group, cb) ->
    if group is 'phuser' and process.env.PHABRICATOR_TRUSTED_USERS is 'y'
      isAuthorized = true
    else
      isAuthorized = msg.robot.auth?.hasRole(user, [group, 'phadmin']) or
                     msg.robot.auth?.isAdmin(user)
    if msg.robot.auth? and not isAuthorized
      msg.reply "You don't have permission to do that."
    else
      cb()


  taskInfo: (msg, id, cb) ->
    if @ready(msg) is true
      query = { 'task_id': id }
      @phabGet msg, query, 'maniphest.info', (json_body) ->
        cb json_body


  fileInfo: (msg, id, cb) ->
    if @ready(msg) is true
      query = { 'id': id }
      @phabGet msg, query, 'file.info', (json_body) ->
        cb json_body


  pasteInfo: (msg, id, cb) ->
    if @ready(msg) is true
      query = { 'ids[0]': id }
      @phabGet msg, query, 'paste.query', (json_body) ->
        cb json_body


  genericInfo: (msg, name, cb) ->
    if @ready(msg) is true
      query = { 'names[]': name }
      @phabGet msg, query, 'phid.lookup', (json_body) ->
        cb json_body


  searchTask: (msg, phid, terms, cb) ->
    if @ready(msg) is true
      query = {
        'constraints[fulltext]': terms,
        'constraints[statuses][0]': 'open',
        'constraints[projects][0]': phid,
        'order': 'newest',
        'limit': '3'
      }
      # console.log query
      @phabGet msg, query, 'maniphest.search', (json_body) ->
        cb json_body
   

  createTask: (msg, phid, title, description, cb) ->
    if @ready(msg) is true
      url = @url
      bot_phid = @bot_phid
      phabGet = @phabGet
      adapter = msg.robot.adapterName
      @withUser msg, msg.envelope.user, (userPhid) ->
        query = {
          'transactions[0][type]': 'title',
          'transactions[0][value]': "#{title}",
          'transactions[1][type]': 'comment',
          'transactions[1][value]': "(created by #{msg.envelope.user.name} on #{adapter})",
          'transactions[2][type]': 'subscribers.add',
          'transactions[2][value][0]': "#{userPhid}",
          'transactions[3][type]': 'subscribers.remove',
          'transactions[3][value][0]': "#{bot_phid}",
          'transactions[4][type]': 'projects.add',
          'transactions[4][value][]': "#{phid}"
        }
        if description?
          query['transactions[5][type]'] = 'description'
          query['transactions[5][value]'] = "#{description}"
        phabGet msg, query, 'maniphest.edit', (json_body) ->
          cb json_body


  createPaste: (msg, title, cb) ->
    if @ready(msg) is true
      url = @url
      bot_phid = @bot_phid
      phabGet = @phabGet
      adapter = msg.robot.adapterName
      @withUser msg, msg.envelope.user, (userPhid) ->
        query = {
          'transactions[0][type]': 'title',
          'transactions[0][value]': "#{title}",
          'transactions[1][type]': 'text',
          'transactions[1][value]': "(created by #{msg.envelope.user.name} on #{adapter})",
          'transactions[2][type]': 'subscribers.add',
          'transactions[2][value][0]': "#{userPhid}",
          'transactions[3][type]': 'subscribers.remove',
          'transactions[3][value][0]': "#{bot_phid}"
        }
        phabGet msg, query, 'paste.edit', (json_body) ->
          cb json_body


  recordPhid: (msg, id) ->
    msg.envelope.user.lastTask = moment().utc()
    msg.envelope.user.lastPhid = id


  retrievePhid: (msg) ->
    expires_at = moment(msg.envelope.user.lastTask).add(5, 'minutes')
    if msg.envelope.user.lastPhid? and moment().utc().isBefore(expires_at)
      msg.envelope.user.lastPhid
    else
      null


  updateStatus: (msg, id, status, cb) ->
    if @ready(msg) is true
      query = {
        'id': id,
        'status': @statuses[status],
        'comments': "status set to #{@statuses[status]} by #{msg.envelope.user.name}"
      }
      @phabGet msg, query, 'maniphest.update', (json_body) ->
        cb json_body


  updatePriority: (msg, id, priority, cb) ->
    if @ready(msg) is true
      query = {
        'id': id,
        'priority': @priorities[priority],
        'comments': "priority set to #{@priorities[priority]} by #{msg.envelope.user.name}"
      }
      @phabGet msg, query, 'maniphest.update', (json_body) ->
        cb json_body


  assignTask: (msg, tid, userphid, cb) ->
    if @ready(msg) is true
      query = {
        'objectIdentifier': "T#{tid}",
        'transactions[0][type]': 'owner',
        'transactions[0][value]': "#{userphid}"
      }
      @phabGet msg, query, 'maniphest.edit', (json_body) ->
        cb json_body


  listTasks: (msg, projphid, cb) ->
    if @ready(msg) is true
      query = {
        'projectPHIDs[0]': "#{projphid}",
        'status': 'status-open'
      }
      @phabGet msg, query, 'maniphest.query', (json_body) ->
        cb json_body



module.exports = Phabricator
