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
    storageLoaded = =>
      @data = @robot.brain.data.phabricator ||= {
        projects: { },
        aliases: { },
        templates: { },
        blacklist: [ ],
        bot_phid: env.PHABRICATOR_BOT_PHID
      }
      @robot.logger.debug 'Phabricator Data Loaded: ' + JSON.stringify(@data, null, 2)
    @robot.brain.on 'loaded', storageLoaded
    storageLoaded() # just in case storage was loaded before we got here
    @data.templates ?= { }
    @data.blacklist ?= [ ]

  ready: ->
    if not process.env.PHABRICATOR_URL
      @robot.logger.error 'Error: Phabricator url is not specified'
    if not process.env.PHABRICATOR_API_KEY
      @robot.logger.error 'Error: Phabricator api key is not specified'
    unless (process.env.PHABRICATOR_URL? and process.env.PHABRICATOR_API_KEY?)
      return false
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

  isBlacklisted: (id) ->
    @data.blacklist.indexOf(id) > -1

  blacklist: (id) ->
    unless @isBlacklisted(id)
      @data.blacklist.push id

  unblacklist: (id) ->
    if @isBlacklisted(id)
      pos = @data.blacklist.indexOf id
      @data.blacklist.splice(pos, 1)

  withBotPHID: (cb) =>
    if @data.bot_phid?
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


  searchAllTask: (phid, terms, cb) ->
    if @ready() is true
      query = {
        'constraints[fulltext]': terms,
        'constraints[projects][0]': phid,
        'order': 'newest',
        'limit': '3'
      }
      # console.log query
      @phabGet query, 'maniphest.search', (json_body) ->
        cb json_body
   

  createTask: (params, cb) ->
    if @ready() is true
      @withTemplate params.template, (description) =>
        if description?.error_info?
          cb description
        else
          if description?
            if params.description?
              params.description += "\n\n#{description}"
            else
              params.description = description
          @withProject params.project, (projectData) =>
            if projectData.error_info?
              cb projectData
            else
              adapter = @robot.adapterName
              user = @robot.brain.userForName params.user.name
              @withUser user, user, (userPhid) =>
                if userPhid.error_info?
                  cb userPhid
                else
                  @withBotPHID (bot_phid) =>
                    query = {
                      'transactions[0][type]': 'title',
                      'transactions[0][value]': "#{params.title}",
                      'transactions[1][type]': 'comment',
                      'transactions[1][value]': "(created by #{user.name} on #{adapter})",
                      'transactions[2][type]': 'subscribers.add',
                      'transactions[2][value][0]': "#{userPhid}",
                      'transactions[3][type]': 'subscribers.remove',
                      'transactions[3][value][0]': "#{bot_phid}",
                      'transactions[4][type]': 'projects.add',
                      'transactions[4][value][]': "#{projectData.data.phid}"
                    }
                    if params.description?
                      query['transactions[5][type]'] = 'description'
                      query['transactions[5][value]'] = "#{params.description}"
                    @phabGet query, 'maniphest.edit', (json_body) ->
                      if json_body.error_info?
                        cb json_body
                      else
                        id = json_body.result.object.id
                        url = process.env.PHABRICATOR_URL + "/T#{id}"
                        cb { id: id, url: url, user: user }

  createPaste: (user, title, cb) ->
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
              'transactions[1][type]': 'text',
              'transactions[1][value]': "(created by #{user.name} on #{adapter})",
              'transactions[2][type]': 'subscribers.add',
              'transactions[2][value][0]': "#{userPhid}",
              'transactions[3][type]': 'subscribers.remove',
              'transactions[3][value][0]': "#{bot_phid}"
            }
            @phabGet query, 'paste.edit', (json_body) ->
              cb json_body


  recordId: (user, id) ->
    user.lastTask = moment().utc()
    user.lastId = id


  retrieveId: (user, id = null) ->
    if id?
      if id is 'last'
        if user.lastId?
          user.lastId
        else
          null
      else
        id
    else
      expires_at = moment(user.lastTask).add(5, 'minutes')
      if user.lastId? and moment().utc().isBefore(expires_at)
        user.lastTask = moment().utc()
        user.lastId
      else
        null


  addComment: (user, id, comment, cb) ->
    if @ready() is true
      @withBotPHID (bot_phid) =>
        query = {
          'objectIdentifier': id,
          'transactions[0][type]': 'comment',
          'transactions[0][value]': "#{comment} (#{user.name})",
          'transactions[1][type]': 'subscribers.remove',
          'transactions[1][value][0]': "#{bot_phid}"
        }
        @phabGet query, 'maniphest.edit', (json_body) ->
          cb json_body


  updateStatus: (user, id, status, comment, cb) ->
    if @ready() is true
      @withBotPHID (bot_phid) =>
        query = {
          'objectIdentifier': id,
          'transactions[0][type]': 'status',
          'transactions[0][value]': @statuses[status],
          'transactions[1][type]': 'subscribers.remove',
          'transactions[1][value][0]': "#{bot_phid}",
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
      @withBotPHID (bot_phid) =>
        query = {
          'objectIdentifier': id,
          'transactions[0][type]': 'priority',
          'transactions[0][value]': @priorities[priority],
          'transactions[1][type]': 'subscribers.remove',
          'transactions[1][value][0]': "#{bot_phid}",
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
      @withBotPHID (bot_phid) =>
        query = {
          'objectIdentifier': "T#{tid}",
          'transactions[0][type]': 'owner',
          'transactions[0][value]': "#{userphid}",
          'transactions[1][type]': 'subscribers.remove',
          'transactions[1][value][0]': "#{bot_phid}"
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


  nextCheckbox: (user, id, key, cb) ->
    if @ready() is true
      query = {
        task_id: id
      }
      @phabGet query, 'maniphest.info', (json_body) =>
        if json_body.error_info?
          cb json_body
        else
          user = @robot.brain.userForName user.name
          @recordId user, id
          lines = json_body.result.description.split('\n')
          reg = new RegExp("^\\[ \\] #{key or ''}")
          found = null
          for line in lines
            if reg.test line
              found = line
              break
          if found?
            cb { line: found }
          else
            if key?
              cb { error_info: "The task T#{id} has no unchecked checkbox starting with #{key}." }
            else
              cb { error_info: "The task T#{id} has no unchecked checkboxes." }


  prevCheckbox: (user, id, key, cb) ->
    if @ready() is true
      query = {
        task_id: id
      }
      @phabGet query, 'maniphest.info', (json_body) =>
        if json_body.error_info?
          cb json_body
        else
          user = @robot.brain.userForName user.name
          @recordId user, id
          lines = json_body.result.description.split('\n').reverse()
          reg = new RegExp("^\\[x\\] #{key or ''}")
          found = null
          for line in lines
            if reg.test line
              found = line
              break
          if found?
            cb { line: found }
          else
            if key?
              cb { error_info: "The task T#{id} has no checked checkbox starting with #{key}." }
            else
              cb { error_info: "The task T#{id} has no checked checkboxes." }


  checkCheckbox: (user, id, key, cb) ->
    if @ready() is true
      query = {
        task_id: id
      }
      @phabGet query, 'maniphest.info', (json_body) =>
        if json_body.error_info?
          cb json_body
        else
          user = @robot.brain.userForName user.name
          @recordId user, id
          lines = json_body.result.description.split('\n')
          reg = new RegExp("^\\[ \\] #{key or ''}")
          found = null
          updated = [ ]
          for line in lines
            if not found? and reg.test line
              found = line.replace('[ ] ', '[x] ')
              updated.push found
            else
              updated.push line
          if found?
            @withBotPHID (bot_phid) =>
              editquery = {
                'objectIdentifier': "T#{id}",
                'transactions[0][type]': 'description'
                'transactions[0][value]': "#{updated.join('\n')}"
                'transactions[1][type]': 'subscribers.remove',
                'transactions[1][value][0]': "#{bot_phid}",
                'transactions[2][type]': 'comment',
                'transactions[2][value]': "#{user.name} checked:\n#{found}"
              }
              @phabGet editquery, 'maniphest.edit', (json_body) ->
                if json_body.error_info?
                  cb json_body
                else
                  cb { line: found }
          else
            if key?
              cb { error_info: "The task T#{id} has no unchecked checkbox starting with #{key}." }
            else
              cb { error_info: "The task T#{id} has no unchecked checkboxes." }


  uncheckCheckbox: (user, id, key, cb) ->
    if @ready() is true
      query = {
        task_id: id
      }
      @phabGet query, 'maniphest.info', (json_body) =>
        if json_body.error_info?
          cb json_body
        else
          user = @robot.brain.userForName user.name
          @recordId user, id
          lines = json_body.result.description.split('\n').reverse()
          reg = new RegExp("^\\[x\\] #{key or ''}")
          found = null
          updated = [ ]
          for line in lines
            if not found? and reg.test line
              found = line.replace('[x] ', '[ ] ')
              updated.push found
            else
              updated.push line
          if found?
            @withBotPHID (bot_phid) =>
              editquery = {
                'objectIdentifier': "T#{id}",
                'transactions[0][type]': 'description'
                'transactions[0][value]': "#{updated.reverse().join('\n')}"
                'transactions[1][type]': 'subscribers.remove',
                'transactions[1][value][0]': "#{bot_phid}",
                'transactions[2][type]': 'comment',
                'transactions[2][value]': "#{user.name} checked:\n#{found}"
              }
              @phabGet editquery, 'maniphest.edit', (json_body) ->
                if json_body.error_info?
                  cb json_body
                else
                  cb { line: found }
          else
            if key?
              cb { error_info: "The task T#{id} has no checked checkbox starting with #{key}." }
            else
              cb { error_info: "The task T#{id} has no checked checkboxes." }


  # templates ---------------------------------------------------

  withTemplate: (name, cb) =>
    if name?
      if @data.templates[name]?
        query = {
          task_id: @data.templates[name].task
        }
        @phabGet query, 'maniphest.info', (json_body) ->
          if json_body.error_info?
            cb json_body
          else
            cb json_body.result.description
      else
        cb { error_info: "There is no template named '#{name}'." }
    else
      cb null

  addTemplate: (name, taskid, cb) ->
    if @ready() is true
      if @data.templates[name]?
        cb { error_info: "Template '#{name}' already exists." }
      else
        data = @data
        @taskInfo taskid, (body) ->
          if body.error_info?
            cb body
          else
            data.templates[name] = { task: taskid }
            cb { ok: 'Ok' }

  showTemplate: (name, cb) ->
    if @ready() is true
      if @data.templates[name]?
        cb @data.templates[name]
      else
        cb { error_info: "Template '#{name}' was not found." }

  searchTemplate: (term, cb) ->
    if @ready() is true
      res = [ ]
      for name, template of @data.templates
        if new RegExp("#{term}").test name
          res.push { name: name, task: template.task }
      if res.length is 0
        cb { error_info: "No template matches '#{term}'." }
      else
        cb res
        
  removeTemplate: (name, cb) ->
    if @ready() is true
      if @data.templates[name]?
        delete @data.templates[name]
        cb { ok: 'Ok' }
      else
        cb { error_info: "Template '#{name}' was not found." }

  updateTemplate: (name, taskid, cb) ->
    if @ready() is true
      if @data.templates[name]?
        data = @data
        @taskInfo taskid, (body) ->
          if body.error_info?
            cb body
          else
            data.templates[name] = { task: taskid }
            cb { ok: 'Ok' }
      else
        cb { error_info: "Template '#{name}' was not found." }

  renameTemplate: (name, newname, cb) ->
    if @ready() is true
      if @data.templates[name]?
        if @data.templates[newname]?
          cb { error_info: "Template '#{newname}' already exists." }
        else
          @data.templates[newname] = { task: @data.templates[name].task }
          delete @data.templates[name]
          cb { ok: 'Ok' }
      else
        cb { error_info: "Template '#{name}' was not found." }



module.exports = Phabricator
