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
Promise = require 'bluebird'

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
        users: { },
        bot_phid: env.PHABRICATOR_BOT_PHID
      }
      @robot.logger.debug 'Phabricator Data Loaded: ' + JSON.stringify(@data, null, 2)
    @robot.brain.on 'loaded', storageLoaded
    storageLoaded() # just in case storage was loaded before we got here
    @data.templates ?= { }
    @data.blacklist ?= [ ]
    @data.users ?= { }

  ready: ->
    if not process.env.PHABRICATOR_URL
      @robot.logger.error 'Error: Phabricator url is not specified'
    if not process.env.PHABRICATOR_API_KEY
      @robot.logger.error 'Error: Phabricator api key is not specified'
    unless (process.env.PHABRICATOR_URL? and process.env.PHABRICATOR_API_KEY?)
      return false
    true

  # --------------- OLD
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

  # --------------- NEW phabGet
  request: (query, endpoint) =>
    return new Promise (res, err) =>
      query['api.token'] = process.env.PHABRICATOR_API_KEY
      body = querystring.stringify(query)
      @robot.http(process.env.PHABRICATOR_URL)
        .path("api/#{endpoint}")
        .get(body) (error, result, payload) ->
          if result?
            switch result.statusCode
              when 200
                if result.headers['content-type'] is 'application/json'
                  json = JSON.parse(payload)
                  if json.error_info?
                    err json.error_info
                  else
                    res json
                else
                  err 'api did not deliver json'
              else
                err "http error #{result.statusCode}"
          else
            err "#{error.code} #{error.message}"


  isBlacklisted: (id) ->
    @data.blacklist.indexOf(id) > -1

  blacklist: (id) ->
    unless @isBlacklisted(id)
      @data.blacklist.push id

  unblacklist: (id) ->
    if @isBlacklisted(id)
      pos = @data.blacklist.indexOf id
      @data.blacklist.splice(pos, 1)

  # --------------- OLD
  withBotPHID: (cb) =>
    if @data.bot_phid?
      cb @data.bot_phid
    else
      @phabGet { }, 'user.whoami', (json_body) =>
        @data.bot_phid = json_body.result.phid
        cb @data.bot_phid

  # --------------- NEW withBotPHID
  getBotPHID: =>
    return new Promise (res, err) =>
      if @data.bot_phid?
        res @data.bot_phid
      else
        @request({ }, 'user.whoami')
          .then (body) ->
            @data.bot_phid = body.result.phid
            res @data.bot_phid
          .catch (e) ->
            err e

  # --------------- NEW
  getFeed: (payload) =>
    return new Promise (res, err) =>
      if /^PHID-TASK-/.test payload.storyData.objectPHID
        query = {
          'constraints[phids][0]': payload.storyData.objectPHID,
          'attachments[projects]': 1
        }
        data = @data
        @request(query, 'maniphest.search')
          .then (body) ->
            announces = { message: payload.storyText }
            announces.rooms = []
            if body.result.data?
              for phid in body.result.data[0].attachments.projects.projectPHIDs
                for name, project of data.projects
                  if project.phid? and phid is project.phid
                    project.feeds ?= [ ]
                    for room in project.feeds
                      if announces.rooms.indexOf(room) is -1
                        announces.rooms.push room
            res announces
          .catch (e) ->
            err e
      else
        err "no room to announce in"

  # --------------- OLD
  withProject: (project, cb) =>
    project = project.toLowerCase()
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


  # --------------- NEW withProject
  getProject: (project) ->
    return new Promise (res, err) =>
      project = project.toLowerCase()
      if @data.projects[project]?
        projectData = @data.projects[project]
        projectData.name = project
      else
        for a, p of @data.aliases
          p = p.toLowerCase()
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
          res { aliases: aliases, data: projectData }
        else
          @requestProject(projectData.name)
            .then (projectinfo) ->
              projectData.phid = projectinfo.phid
              res { aliases: aliases, data: projectData }
            .catch (e) ->
              err e
      else
        data = @data
        query = { 'names[0]': project }
        @requestProject(project)
          .then (projectinfo) ->
            data.projects[projectinfo.name.toLowerCase()] = projectinfo
            res { aliases: aliases, data: projectinfo }
          .catch (e) ->
            err e

  # --------------- NEW from withProject
  requestProject: (project_name) ->
    return new Promise (res, err) =>
      query = { 'names[0]': project_name }
      @request(query, 'project.query')
        .then (body) ->
          data = body.result.data
          if data.length > 0 or Object.keys(data).length > 0
            phid = Object.keys(data)[0]
            name = data[phid].name
            res { name: name, phid: phid }
          else
            err "Sorry, #{project_name} not found."
        .catch (e) ->
          err e


  # --------------- OLD
  # user can be an object with an id and name fields
  withUser: (from, user, cb) =>
    if @ready() is true
      unless user.id?
        user.id = user.name
      if @data.users[user.id]?.phid?
        cb @data.users[user.id].phid
      else
        @data.users[user.id] ?= {
          name: user.name,
          id: user.id
        }
        if user.phid?
          @data.users[user.id].phid = user.phid
          cb @data.users[user.id].phid
        else
          email = @data.users[user.id].email_address or
                  @robot.brain.userForId(user.id)?.email_address or
                  user.email_address
          unless email
            cb { error_info: @_ask_for_email(from, user) }
          else
            user = @data.users[user.id]
            query = { 'emails[0]': email }
            @phabGet query, 'user.query', (json_body) ->
              unless json_body['result']['0']?
                cb {
                  error_info: "Sorry, I cannot find #{email} :("
                }
              else
                user.phid = json_body['result']['0']['phid']
                cb user.phid

  # --------------- NEW
  getUser: (from, user) =>
    return new Promise (res, err) =>
      unless user.id?
        user.id = user.name
      if @data.users[user.id]?.phid?
        res @data.users[user.id].phid
      else
        @data.users[user.id] ?= {
          name: user.name,
          id: user.id
        }
        if user.phid?
          @data.users[user.id].phid = user.phid
          res @data.users[user.id].phid
        else
          email = @data.users[user.id].email_address or
                  @robot.brain.userForId(user.id)?.email_address or
                  user.email_address
          unless email
            err @_ask_for_email(from, user)
          else
            user = @data.users[user.id]
            query = { 'emails[0]': email }
            @request(query, 'user.query')
              .then (body) ->
                if body.result['0']?
                  user.phid = body['result']['0']['phid']
                  res user.phid
                else
                  err "Sorry, I cannot find #{email} :("


  _ask_for_email: (from, user) ->
    if from.name is user.name
      "Sorry, I can't figure out your email address :( " +
      'Can you tell me with `.phab me as <email>`?'
    else
      if @robot.auth? and (@robot.auth.hasRole(from, ['phadmin']) or
          @robot.auth.isAdmin(from))
        "Sorry, I can't figure #{user.name} email address. " +
        "Can you help me with `.phab user #{user.name} = <email>`?"
      else
        "Sorry, I can't figure #{user.name} email address. " +
        'Can you ask them to `.phab me as <email>`?'

  recordId: (user, id) ->
    @data.users[user.id] ?= {
      name: "#{user.name}",
      id: "#{user.id}"
    }
    @data.users[user.id].lastTask = moment().utc().format()
    @data.users[user.id].lastId = id


  # --------------- OLD
  retrieveId: (user, id = null) ->
    @data.users[user.id] ?= {
      name: "#{user.name}",
      id: "#{user.id}"
    }
    user = @data.users[user.id]
    if id?
      if id is 'last'
        if user? and user.lastId?
          user.lastId
        else
          null
      else
        @recordId user, id
        id
    else
      user.lastTask ?= moment().utc().format()
      expires_at = moment(user.lastTask).add(5, 'minutes')
      if user.lastId? and moment().utc().isBefore(expires_at)
        user.lastTask = moment().utc().format()
        user.lastId
      else
        null

  # --------------- NEW
  getId: (user, id = null) ->
    return new Promise (res, err) =>
      @data.users[user.id] ?= {
        name: "#{user.name}",
        id: "#{user.id}"
      }
      user = @data.users[user.id]
      if id?
        if id is 'last'
          if user? and user.lastId?
            res user.lastId
          else
            err "Sorry, you don't have any task active."
        else
          @recordId user, id
          res id
      else
        user.lastTask ?= moment().utc().format()
        expires_at = moment(user.lastTask).add(10, 'minutes')
        if user.lastId? and moment().utc().isBefore(expires_at)
          user.lastTask = moment().utc().format()
          res user.lastId
        else
          err "Sorry, you don't have any task active right now."


  # --------------- NEW
  getUserByPhid: (phid) ->
    return new Promise (res, err) =>
      if phid?
        query = { 'phids[0]': phid }
        @request(query, 'user.query')
          .then (body) ->
            if body['result']['0']?
              res body['result']['0']['userName']
            else
              res 'unknown'
          .catch (e) ->
            err e
      else
        res 'nobody'


  # --------------- OLD
  withPermission: (msg, user, group, cb) =>
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


  # --------------- NEW
  getPermission: (user, group) =>
    return new Promise (res, err) =>
      if group is 'phuser' and process.env.PHABRICATOR_TRUSTED_USERS is 'y'
        isAuthorized = true
      else
        isAuthorized = @robot.auth?.hasRole(user, [group, 'phadmin']) or
                       @robot.auth?.isAdmin(user)
      if @robot.auth? and not isAuthorized
        err "You don't have permission to do that."
      else
        res()


  # --------------- NEW
  taskInfo: (id, cb) ->
    if @ready() is true
      query = { 'task_id': id }
      @phabGet query, 'maniphest.info', (json_body) ->
        cb json_body

  # --------------- NEW
  getTask: (id) ->
    query = { 'task_id': id }
    @request query, 'maniphest.info'


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
              params.projectphid = projectData.data.phid
              @withBotPHID (bot_phid) =>
                params.bot_phid = bot_phid
                if params.user?
                  if params.user?.name?
                    user = params.user
                  else
                    user = { name: params.user }
                else
                  user = { name: @robot.name, phid: bot_phid }
                  userPhid = bot_phid
                @withUser user, user, (userPhid) =>
                  if userPhid.error_info?
                    cb userPhid
                  else
                    params.userPhid = userPhid
                    params.adapter = @robot.adapterName
                    query = {
                      'transactions[0][type]': 'title',
                      'transactions[0][value]': "#{params.title}",
                      'transactions[1][type]': 'comment',
                      'transactions[1][value]': "(created by #{user.name} on #{params.adapter})",
                      'transactions[2][type]': 'subscribers.add',
                      'transactions[2][value][0]': "#{params.userPhid}",
                      'transactions[3][type]': 'subscribers.remove',
                      'transactions[3][value][0]': "#{params.bot_phid}",
                      'transactions[4][type]': 'projects.add',
                      'transactions[4][value][]': "#{params.projectphid}"
                    }
                    next = 5
                    if params.description?
                      query["transactions[#{next}][type]"] = 'description'
                      query["transactions[#{next}][value]"] = "#{params.description}"
                      next += 1
                    if params.assign? and @data.users[params.assign]?.phid
                      owner = @data.users[params.assign]?.phid
                      query["transactions[#{next}][type]"] = 'owner'
                      query["transactions[#{next}][value]"] = owner
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

  # --------------- NEW addComment
  addComment: (user, id, comment, cb) ->
    @getBotPHID()
      .then (bot_phid) =>
        query = {
          'objectIdentifier': id,
          'transactions[0][type]': 'comment',
          'transactions[0][value]': "#{comment} (#{user.name})",
          'transactions[1][type]': 'subscribers.remove',
          'transactions[1][value][0]': "#{bot_phid}"
        }
        @request(query, 'maniphest.edit')
      .then (body) ->
        id

  changeTags: (user, id, tagin, tagout, cb) ->
    if @ready() is true
      query = { 'task_id': id }
      @phabGet query, 'maniphest.info', (json_body) =>
        if json_body.error_info?
          cb json_body
        else
          projs = json_body.projectPHIDs
        @withUser user, user, (userPhid) =>
          if userPhid.error_info?
            cb userPhid
          else
            @withBotPHID (bot_phid) =>
              query = {
                'objectIdentifier': id,
                'transactions[0][type]': 'subscribers.remove',
                'transactions[0][value][0]': "#{bot_phid}",
                'transactions[1][type]': 'comment',
                'transactions[1][value]': "tags changed by #{user.name}"
              }
              ind = 1
              addTags = [ ]
              removeTags = [ ]
              for tag in tagin
                @withProject tag, (projectData) ->
                  if projectData.error_info?
                    cb projectData
                  else
                    phid = projectData.data.phid
                    if phid in projs
                      cb { message: "T#{id} already has the tag '#{tag}'." }
                    else
                      addTags.push phid
              for tag in tagout
                @withProject tag, (projectData) ->
                  if projectData.error_info?
                    cb projectData
                  else
                    phid = projectData.data.phid
                    if phid not in projs
                      cb { message: "T#{id} is not having the tag '#{tag}'." }
                    else
                      removeTags.push phid
              if addTags.length > 0
                ind += 1
                query["transactions[#{ind}][type]"] = 'projects.add'
                query["transactions[#{ind}][value]"] = addTags
              if removeTags.length > 0
                ind += 1
                query["transactions[#{ind}][type]"] = 'projects.remove'
                query["transactions[#{ind}][value]"] = removeTags
              console.log query
              if ind > 1
                console.log 'doit'
                # @phabGet query, 'maniphest.edit', (json_body) ->
                #   cb json_body


  # --------------- NEW
  updateStatus: (user, id, status, comment) ->
    userPhid = null
    @getUser(user, user)
      .then (userPhid) =>
        @getBotPHID()
      .then (bot_phid) =>
        query = {
          'objectIdentifier': id,
          'transactions[0][type]': 'status',
          'transactions[0][value]': @statuses[status],
          'transactions[1][type]': 'subscribers.remove',
          'transactions[1][value][0]': "#{bot_phid}",
          'transactions[2][type]': 'owner',
          'transactions[2][value]': userPhid,
          'transactions[3][type]': 'comment'
        }
        if comment?
          query['transactions[3][value]'] = "#{comment} (#{user.name})"
        else
          query['transactions[3][value]'] = "status set to #{status} by #{user.name}"
        @request(query, 'maniphest.edit')
      .then (body) ->
        id


  # --------------- NEW
  updatePriority: (user, id, priority, comment) ->
    userPhid = null
    @getUser(user, user)
      .then (userPhid) =>
        @getBotPHID()
      .then (bot_phid) =>
        query = {
          'objectIdentifier': id,
          'transactions[0][type]': 'priority',
          'transactions[0][value]': @priorities[priority],
          'transactions[1][type]': 'subscribers.remove',
          'transactions[1][value][0]': "#{bot_phid}",
          'transactions[2][type]': 'owner',
          'transactions[2][value]': userPhid,
          'transactions[3][type]': 'comment'
        }
        if comment?
          query['transactions[3][value]'] = "#{comment} (#{user.name})"
        else
          query['transactions[3][value]'] = "priority set to #{priority} by #{user.name}"
        @request(query, 'maniphest.edit')
      .then (body) ->
        id


  # --------------- NEW
  assignTask: (id, userphid, cb) ->
    @getBotPHID()
      .then (bot_phid) =>
        query = {
          'objectIdentifier': "T#{id}",
          'transactions[0][type]': 'owner',
          'transactions[0][value]': "#{userphid}",
          'transactions[1][type]': 'subscribers.remove',
          'transactions[1][value][0]': "#{bot_phid}"
        }
        @request(query, 'maniphest.edit')
      .then (body) ->
        body.result.id


  listTasks: (projphid, cb) ->
    if @ready() is true
      query = {
        'projectPHIDs[0]': "#{projphid}",
        'status': 'status-open'
      }
      @phabGet query, 'maniphest.query', (json_body) ->
        cb json_body


  # --------------- NEW
  nextCheckbox: (user, id, key) ->
    return new Promise (res, err) =>
      query = { task_id: id }
      @request(query, 'maniphest.info')
        .then (body) =>
          @recordId user, id
          lines = body.result.description.split('\n')
          reg = new RegExp("^\\[ \\] .*#{key or ''}", 'i')
          found = null
          for line in lines
            if reg.test line
              found = line
              break
          if found?
            res found
          else
            if key?
              err "The task T#{id} has no unchecked checkbox matching #{key}."
            else
              err "The task T#{id} has no unchecked checkboxes."
        .catch (e) ->
          err e


  # --------------- NEW
  prevCheckbox: (user, id, key) ->
    return new Promise (res, err) =>
      query = { task_id: id }
      @request(query, 'maniphest.info')
        .then (body) =>
          @recordId user, id
          lines = body.result.description.split('\n').reverse()
          reg = new RegExp("^\\[x\\] .*#{key or ''}", 'i')
          found = null
          for line in lines
            if reg.test line
              found = line
              break
          if found?
            res found
          else
            if key?
              err "The task T#{id} has no checked checkbox matching #{key}."
            else
              err "The task T#{id} has no checked checkboxes."
        .catch (e) ->
          err e

  # --------------- NEW
  updateTask: (id, description, comment) =>
    @getBotPHID()
      .then (bot_phid) =>
        editquery = {
          'objectIdentifier': "T#{id}",
          'transactions[0][type]': 'description'
          'transactions[0][value]': "#{description}"
          'transactions[1][type]': 'subscribers.remove',
          'transactions[1][value][0]': "#{bot_phid}",
          'transactions[2][type]': 'comment',
          'transactions[2][value]': "#{comment}"
        }
        @request(editquery, 'maniphest.edit')

  # --------------- NEW
  checkCheckbox: (user, id, key, withNext, usercomment) ->
    return new Promise (res, err) =>
      query = { task_id: id }
      @request(query, 'maniphest.info')
        .then (body) =>
          @recordId user, id
          lines = body.result.description.split('\n')
          reg = new RegExp("^\\[ \\] .*#{key or ''}", 'i')
          found = null
          foundNext = null
          updated = [ ]
          extra = if key? then " matching #{key}" else ''
          for line in lines
            if not found? and reg.test line
              line = line.replace('[ ] ', '[x] ')
              found = line
            else if withNext? and found? and not foundNext? and reg.test line
              foundNext = line
            updated.push line
          if found?
            comment = "#{user.name} checked:\n#{found}"
            comment += "\n#{usercomment}" if usercomment?
            description = updated.join('\n')
            @updateTask(id, description, comment)
              .then (body) ->
                if withNext? and not foundNext?
                  foundNext = "there is no more unchecked checkbox#{extra}."
                res [ found, foundNext ]
              .catch (e) ->
                err e
          else
            err "The task T#{id} has no unchecked checkbox#{extra}."
        .catch (e) ->
          err e


  # --------------- NEW
  uncheckCheckbox: (user, id, key, withNext, usercomment) ->
    return new Promise (res, err) =>
      query = { task_id: id }
      @request(query, 'maniphest.info')
        .then (body) =>
          @recordId user, id
          lines = body.result.description.split('\n').reverse()
          reg = new RegExp("^\\[x\\] .*#{key or ''}", 'i')
          found = null
          foundNext = null
          updated = [ ]
          extra = if key? then " matching #{key}" else ''
          for line in lines
            if not found? and reg.test line
              line = line.replace('[x] ', '[ ] ')
              found = line
            else if withNext? and found? and not foundNext? and reg.test line
              foundNext = line
            updated.push line
          if found?
            comment = "#{user.name} unchecked:\n#{found}"
            comment += "\n#{usercomment}" if usercomment?
            description = updated.reverse().join('\n')
            @updateTask(id, description, comment)
              .then (body) ->
                if withNext? and not foundNext?
                  foundNext = "there is no more checked checkbox#{extra}."
                res [ found, foundNext ]
              .catch (e) ->
                err e
          else
            err "The task T#{id} has no checked checkbox#{extra}."
        .catch (e) ->
          err e


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
        if new RegExp(term).test name
          res.push { name: name, task: template.task }
      if res.length is 0
        if term?
          cb { error_info: "No template matches '#{term}'." }
        else
          cb { error_info: 'There is no template defined.' }
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
