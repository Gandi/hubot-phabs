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
    storageLoaded = =>
      @data = @robot.brain.data.phabricator ||= {
        projects: { },
        aliases: { },
        bot_phid: env.PHABRICATOR_BOT_PHID
      }
      @robot.logger.debug 'Phabricator Data Loaded: ' + JSON.stringify(@data, null, 2)
    @robot.brain.on 'loaded', storageLoaded
    storageLoaded() # just in case storage was loaded before we got here


  ready: ->
    @robot.logger.error 'Error: Phabricator url is not specified' if not @url
    @robot.logger.error 'Error: Phabricator api key is not specified' if not @apikey
    return false unless (@url and @apikey)
    true


  phabGet: (query, endpoint, cb) =>
    query['api.token'] = process.env.PHABRICATOR_API_KEY
    # console.log query
    body = querystring.stringify(query)
    @robot.http(process.env.PHABRICATOR_URL)
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

  withBotPHID: (cb) =>
    if @data.bot_phid
      cb @data.bot_phid
    else
      @phabGet { }, 'user.whoami', (json_body) =>
        @data.bot_phid = json_body.result.phid
        cb @data.bot_phid

  withFeed: (payload, cb) =>
    # console.log payload.storyData
    if /^PHID-TASK-/.test payload.storyData.objectPHID
      query = {
        'constraints[phids][0]': payload.storyData.objectPHID,
        'attachments[projects]': 1
      }
      data = @data
      @phabGet query, 'maniphest.search', (json_body) ->
        announces = {
          message: payload.storyText
        }
        announces.rooms = []
        if json_body.result.data?
          for phid in json_body.result.data[0].attachments.projects.projectPHIDs
            for name, project of data.projects
              if project.phid? and phid is project.phid
                project.feeds ?= [ ]
                for room in project.feeds
                  if announces.rooms.indexOf(room) is -1
                    announces.rooms.push room
        cb announces
    else
      cb { rooms: [ ] }

  withProject: (project, cb) =>
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
        @phabGet query, 'project.query', (json_body) ->
          if Object.keys(json_body.result.data).length > 0
            projectData.phid = Object.keys(json_body.result.data)[0]
            cb { aliases: aliases, data: projectData }
          else
            cb { error_info: "Sorry, #{project} not found." }
    else
      data = @data
      query = { 'names[0]': project }
      @phabGet query, 'project.query', (json_body) ->
        if json_body.result.data.length > 0 or Object.keys(json_body.result.data).length > 0
          phid = Object.keys(json_body.result.data)[0]
          data.projects[project] = { phid: phid }
          projectData = {
            name: json_body.result.data[phid].name
          }
          cb { aliases: aliases, data: projectData }
        else
          cb { error_info: "Sorry, #{project} not found." }


  withUser: (from, user, cb) =>
    if @ready() is true
      id = user.phid
      if id
        cb(id)
      else
        email = user.email_address or user.pagerdutyEmail
        unless email
          if from.name is user.name
            cb {
              error_info: "Sorry, I can't figure out your email address :( " +
                          'Can you tell me with `.phab me as you@yourdomain.com`?'
              }
          else
            cb {
              error_info: "Sorry, I can't figure #{user.name} email address. " +
                          "Can you help me with .phab #{user.name} = <email>"
              }
        else
          query = { 'emails[0]': email }
          @phabGet query, 'user.query', (json_body) ->
            unless json_body['result']['0']?
              cb {
                error_info: "Sorry, I cannot find #{email} :("
              }
            else
              user.phid = json_body['result']['0']['phid']
              cb user.phid


  withUserByPhid: (phid, cb) =>
    if phid?
      user = null
      for k of @robot.brain.data.users
        thisphid = @robot.brain.data.users[k].phid
        if thisphid? and thisphid is phid
          user = @robot.brain.data.users[k]
          break
      if user?
        cb user
      else
        query = { 'phids[0]': phid }
        @phabGet query, 'user.query', (json_body) ->
          if json_body['result']['0']?
            cb { name: json_body['result']['0']['userName'] }
          else
            cb { name: 'unknown' }
    else
      cb { name: 'nobody' }


  withPermission: (msg, user, group, cb) =>
    user = @robot.brain.userForName user.name
    if group is 'phuser' and process.env.PHABRICATOR_TRUSTED_USERS is 'y'
      isAuthorized = true
    else
      isAuthorized = @robot.auth?.hasRole(user, [group, 'phadmin']) or
                     @robot.auth?.isAdmin(user)
    if @robot.auth? and not isAuthorized
      msg.reply "You don't have permission to do that."
      msg.finish()
    else
      cb()


  taskInfo: (id, cb) ->
    if @ready() is true
      query = { 'task_id': id }
      @phabGet query, 'maniphest.info', (json_body) ->
        cb json_body


  fileInfo: (id, cb) ->
    if @ready() is true
      query = { 'id': id }
      @phabGet query, 'file.info', (json_body) ->
        cb json_body


  pasteInfo: (id, cb) ->
    if @ready() is true
      query = { 'ids[0]': id }
      @phabGet query, 'paste.query', (json_body) ->
        cb json_body


  genericInfo: (name, cb) ->
    if @ready() is true
      query = { 'names[]': name }
      @phabGet query, 'phid.lookup', (json_body) ->
        cb json_body


  searchTask: (phid, terms, cb) ->
    if @ready() is true
      query = {
        'constraints[fulltext]': terms,
        'constraints[statuses][0]': 'open',
        'constraints[projects][0]': phid,
        'order': 'newest',
        'limit': '3'
      }
      # console.log query
      @phabGet query, 'maniphest.search', (json_body) ->
        cb json_body
   

  createTask: (user, phid, title, description, cb) ->
    if @ready() is true
      adapter = @robot.adapterName
      user = @robot.brain.userForName user.name
      @withUser user, user, (userPhid) =>
        if userPhid.error_info?
          cb userPhid
        else
          @withBotPHID (bot_phid) =>
            query = {
              'transactions[0][type]': 'title',
              'transactions[0][value]': "#{title}",
              'transactions[1][type]': 'comment',
              'transactions[1][value]': "(created by #{user.name} on #{adapter})",
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
            @phabGet query, 'maniphest.edit', (json_body) ->
              cb json_body


  createPaste: (user, title, cb) ->
    if @ready() is true
      bot_phid = @robot.brain.data.phabricator.bot_phid
      adapter = @robot.adapterName
      user = @robot.brain.userForName user.name
      @withUser user, user, (userPhid) =>
        if userPhid.error_info?
          cb userPhid
        else
          query = {
            'transactions[0][type]': 'title',
            'transactions[0][value]': "#{title}",
            'transactions[1][type]': 'text',
            'transactions[1][value]': "(created by #{user.name} on #{adapter})",
            'transactions[2][type]': 'subscribers.add',
            'transactions[2][value][0]': "#{userPhid}",
            'transactions[3][type]': 'subscribers.remove',
            'transactions[3][value][0]': "#{bot_phid}"
          }
          @phabGet query, 'paste.edit', (json_body) ->
            cb json_body


  recordPhid: (user, id) ->
    user.lastTask = moment().utc()
    user.lastPhid = id


  retrievePhid: (user) ->
    expires_at = moment(user.lastTask).add(5, 'minutes')
    if user.lastPhid? and moment().utc().isBefore(expires_at)
      user.lastPhid
    else
      null


  addComment: (user, id, comment, cb) ->
    if @ready() is true
      query = {
        'objectIdentifier': id,
        'transactions[0][type]': 'comment',
        'transactions[0][value]': "#{comment} (#{user.name})",
        'transactions[1][type]': 'subscribers.remove',
        'transactions[1][value][0]': "#{@robot.brain.data.phabricator.bot_phid}"
      }
      @phabGet query, 'maniphest.edit', (json_body) ->
        cb json_body


  updateStatus: (user, id, status, comment, cb) ->
    if @ready() is true
      query = {
        'objectIdentifier': id,
        'transactions[0][type]': 'status',
        'transactions[0][value]': @statuses[status],
        'transactions[1][type]': 'subscribers.remove',
        'transactions[1][value][0]': "#{@robot.brain.data.phabricator.bot_phid}",
        'transactions[2][type]': 'owner',
        'transactions[2][value]': user.phid,
        'transactions[3][type]': 'comment'
      }
      if comment?
        query['transactions[3][value]'] = "#{comment} (#{user.name})"
      else
        query['transactions[3][value]'] = "status set to #{status} by #{user.name}"
      @phabGet query, 'maniphest.edit', (json_body) ->
        cb json_body


  updatePriority: (user, id, priority, comment, cb) ->
    if @ready() is true
      query = {
        'objectIdentifier': id,
        'transactions[0][type]': 'priority',
        'transactions[0][value]': @priorities[priority],
        'transactions[1][type]': 'subscribers.remove',
        'transactions[1][value][0]': "#{@robot.brain.data.phabricator.bot_phid}",
        'transactions[2][type]': 'owner',
        'transactions[2][value]': user.phid,
        'transactions[3][type]': 'comment'
      }
      if comment?
        query['transactions[3][value]'] = "#{comment} (#{user.name})"
      else
        query['transactions[3][value]'] = "priority set to #{priority} by #{user.name}"
      @phabGet query, 'maniphest.edit', (json_body) ->
        cb json_body


  assignTask: (tid, userphid, cb) ->
    if @ready() is true
      query = {
        'objectIdentifier': "T#{tid}",
        'transactions[0][type]': 'owner',
        'transactions[0][value]': "#{userphid}",
        'transactions[1][type]': 'subscribers.remove',
        'transactions[1][value][0]': "#{@bot_phid}"
      }
      @phabGet query, 'maniphest.edit', (json_body) ->
        cb json_body


  listTasks: (projphid, cb) ->
    if @ready() is true
      query = {
        'projectPHIDs[0]': "#{projphid}",
        'status': 'status-open'
      }
      @phabGet query, 'maniphest.query', (json_body) ->
        cb json_body



module.exports = Phabricator
