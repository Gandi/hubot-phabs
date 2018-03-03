# Description:
#   requests Phabricator Conduit api
#
# Dependencies:
#
# Configuration:
#  PHABRICATOR_URL
#  PHABRICATOR_VERSION
#  PHABRICATOR_API_KEY
#  PHABRICATOR_BOT_PHID
#  PHABRICATOR_TRUSTED_USERS
#  PHABRICATOR_ENABLED_ITEMS
#  PHABRICATOR_LAST_TASK_LIFETIME
#  PHABRICATOR_FEED_EVERYTHING
#
# Author:
#   mose

querystring = require 'querystring'
moment = require 'moment'
Promise = require 'bluebird'

class Phabricator

  statuses: {
    'open': 'open',
    'stalled' : 'stalled',
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

  itemTypes: [
    'T', # tasks
    'F', # files
    'P', # paste
    'M', # pholio
    'B', # builds
    'Q', # ponder
    'L', # legalpad
    'V', # polls
    'D'  # diffs
  ]

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
      @data.templates ?= { }
      @data.blacklist ?= [ ]
      @data.users ?= { }
      @data.alerts ?= { }
      @data.projects['*'] ?= { }
      @robot.logger.debug '---- Phabricator Data Loaded.'
      @priorities = if env.PHABRICATOR_VERSION? and env.PHABRICATOR_VERSION > 2017.24
        {
          'unbreak': 'unbreak',
          'broken': 'unbreak',
          'triage': 'triage',
          'none': 'triage',
          'unknown': 'triage',
          'low': 'low',
          'normal': 'normal',
          'high': 'high',
          'important': 'high',
          'urgent': 'high',
          'wish': 'wish'
        }
      else
        {
          'unbreak': 100,
          'broken': 100,
          'triage': 90,
          'none': 90,
          'unknown': 90,
          'low': 25,
          'normal': 50,
          'high': 80,
          'important': 80,
          'urgent': 80,
          'wish': 0
        }
    @robot.brain.on 'loaded', storageLoaded
    storageLoaded() # just in case storage was loaded before we got here

  ready: ->
    if not process.env.PHABRICATOR_URL
      @robot.logger.error 'Error: Phabricator url is not specified'
    if not process.env.PHABRICATOR_API_KEY
      @robot.logger.error 'Error: Phabricator api key is not specified'
    unless (process.env.PHABRICATOR_URL? and process.env.PHABRICATOR_API_KEY?)
      return false
    true

  enabledItemsRegex: ->
    if process.env.PHABRICATOR_ENABLED_ITEMS?
      r = ''
      i = []
      for item in process.env.PHABRICATOR_ENABLED_ITEMS.split(',')
        if item is 'r'
          r = '|(r[A-Z]+[a-f0-9]{10,})'
        else if item in @itemTypes
          i.push item
      if i.length > 0
        '(?:(' + i.join('|') + ')([0-9]+)' + r + ')'
      else
        false
    else
      '(?:(' + @itemTypes.join('|') + ')([0-9]+)|(r[A-Z]+[a-f0-9]{10,}))'

  request: (query, endpoint) =>
    return new Promise (res, err) =>
      query['api.token'] = process.env.PHABRICATOR_API_KEY
      body = querystring.stringify(query)
      # console.log body
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

  getBotPHID: =>
    return new Promise (res, err) =>
      if @data.bot_phid?
        res @data.bot_phid
      else
        @request({ }, 'user.whoami')
        .then (body) =>
          @data.bot_phid = body.result.phid
          res @data.bot_phid
        .catch (e) ->
          err e

  getPHID: (phid) =>
    return new Promise (res, err) =>
      query = {
        'phids[0]': phid
      }
      @request(query, 'phid.query')
      .then (body) ->
        if body.result[phid]?
          res body.result[phid]
        else
          err 'PHID not found.'
      .catch (e) ->
        err e

  getFeed: (payload) =>
    return new Promise (res, err) =>
      data = @data
      if process.env.PHABRICATOR_FEED_EVERYTHING? and
         process.env.PHABRICATOR_FEED_EVERYTHING isnt '0' and
         data.projects['*']?
        announces = { message: payload.storyText }
        announces.rooms = []
        for room in data.projects['*'].feeds
          if announces.rooms.indexOf(room) is -1
            announces.rooms.push room
        res announces
      else if /^PHID-TASK-/.test payload.storyData.objectPHID
        query = {
          'constraints[phids][0]': payload.storyData.objectPHID,
          'attachments[projects]': 1,
          'attachments[subscribers]': 1
        }
        @request(query, 'maniphest.search')
        .then (body) ->
          announces = { message: payload.storyText }
          announces.rooms = []
          announces.users = []
          if body.result.data?
            for phid in body.result.data[0].attachments.projects.projectPHIDs
              for name, project of data.projects
                if name is '*' or
                    (project.phid? and phid is project.phid)
                  morefeeds = [ ]
                  project.feeds ?= [ ]
                  if project.parent?
                    data.projects[project.parent].feeds ?= [ ]
                    morefeeds = project.feeds.concat(data.projects[project.parent].feeds)
                  for room in project.feeds.concat(morefeeds)
                    if announces.rooms.indexOf(room) is -1
                      announces.rooms.push room
            for username, userphid of data.alerts
              if body.result.data[0].fields.ownerPHID is userphid
                if announces.users.indexOf(username) is -1
                  announces.users.push username
              for phid in body.result.data[0].attachments.subscribers.subscriberPHIDs
                if userphid is phid
                  if announces.users.indexOf(username) is -1
                    announces.users.push username
          res announces
        .catch (e) ->
          err e
      else
        err 'no room to announce in'

  getProject: (project, refresh = false) ->
    if /^PHID-PROJ-/.test project
      @getProjectByPhid project, refresh
    else
      @getProjectByName project, refresh
 
  getProjectByPhid: (project, refresh) ->
    for name, data of @data.projects
      if data.phid is project
        projectData = data
        break
    if projectData? and not refresh
      return new Promise (res, err) =>
        res { aliases: @projectAliases(projectData.name), data: projectData }
    else
      @getProjectData project
 
  getProjectByName: (project, refresh) ->
    if @data.projects[project]?
      projectData = @data.projects[project]
    else
      for a, p of @data.aliases
        if a is project and @data.projects[p]?
          projectData = @data.projects[p]
          project = projectData.name
          break
    if projectData? and not refresh
      return new Promise (res, err) =>
        projectname = projectData.name
        if projectData.parent?
          projectname = projectData.parent + '/' + projectname
        res { aliases: @projectAliases(projectname), data: projectData }
    else
      @getProjectData project

  getProjectData: (project) ->
    data = @data
    projectname = null
    @searchProject(project)
    .then (projectinfo) =>
      projectname = projectinfo.name
      if projectinfo.parent?
        projectname = projectinfo.parent + '/' + projectname
      data.projects[projectname] = projectinfo
      if @aliasize(projectname) isnt projectname
        data.aliases[@aliasize(projectname)] = projectname
      @getColumns(projectinfo.phid)
    .then (columns) =>
      data.projects[projectname].columns = columns
      { aliases: @projectAliases(projectname), data: data.projects[projectname] }

  projectAliases: (project) ->
    aliases = []
    for a, p of @data.aliases
      if p is project
        aliases.push a
    aliases

  aliasize: (str) ->
    str.trim().toLowerCase().replace(/[^-_a-z0-9]/g, '_')

  searchProject: (project) ->
    return new Promise (res, err) =>
      if /^PHID-PROJ-/.test project
        query = { 'constraints[phids][0]': project }
      else
        if /\//.test project
          [ parent, project ] = project.split(/\s*\/\s*/)
          parent_phid = undefined
          if @data.projects[parent]?
            parent_phid = @data.projects[parent].phid
          else
            for a, p of @data.aliases
              if a is parent and @data.projects[p]?
                parent_phid = @data.projects[p].phid
                break
          if parent_phid?
            query = {
              'constraints[name]': project,
              'constraints[parents][0]': parent_phid
            }
          else
            err "Parent project #{parent} not found. Please .phad info #{parent}"
        else
          query = { 'constraints[name]': project }
      @request(query, 'project.search')
      .then (body) =>
        data = body.result.data
        if data.length > 0
          found = null
          for proj in data
            if /^PHID-PROJ-/.test(project) and proj.phid is project or
               @aliasize(proj.fields.name) is @aliasize(project)
              found = proj
              break
          if found?
            phid = found.phid
            name = found.fields.name.trim()
            if found.fields.parent?
              parent = found.fields.parent.name.trim()
            else
              parent = null
            res { name: name, phid: phid, parent: parent }
          else
            err "Sorry, tag '#{project}' not found."
        else
          err "Sorry, tag '#{project}' not found."
      .catch (e) ->
        err e

  getColumns: (phid) ->
    query = {
      'projectPHIDs[0]': "#{phid}",
      'status': 'status-any',
      'order': 'order-modified'
    }
    @request(query, 'maniphest.query')
    .then (body) =>
      query = { 'ids[]': [ ] }
      for k, i of body.result
        query['ids[]'].push i.id
      if query['ids[]'].length is 0
        @robot.logger.warning "Sorry, we can't find columns for #{phid} " +
                              'until there are tasks created.'
        { result: { } }
      else
        @request(query, 'maniphest.gettasktransactions')
    .then (body) =>
      columns = [ ]
      for id, o of body.result
        ts = o.filter (trans) ->
          trans.transactionType is 'core:columns' and
          trans.newValue[0].boardPHID is phid
        boardIds = (t.newValue[0].columnPHID for t in ts)
        columns = columns.concat boardIds
      columns = columns.filter (value, index, self) ->
        self.indexOf(value) is index
      if columns.length is 0
        @robot.logger.warning 'Sorry, the tasks in project ' + phid +
                              ' have to be moved around' +
                              ' before we can get the columns.'
        { result: { } }
      else
        query = { 'names[]': columns }
        @request(query, 'phid.lookup')
    .then (body) =>
      back = { }
      for p, v of body.result
        name = @aliasize(v.name)
        back[name] = p
      back
      
  getUser: (from, user) =>
    return new Promise (res, err) =>
      if user.name is 'me'
        user = from
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
          email = user.email_address or
                  @data.users[user.id].email_address or
                  @robot.brain.userForId(user.id)?.email_address
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
        if user.lastId? and process.env.PHABRICATOR_LAST_TASK_LIFETIME is '-'
          res user.lastId
        else
          user.lastTask ?= moment().utc().format()
          lifetime = process.env.PHABRICATOR_LAST_TASK_LIFETIME or 60
          expires_at = moment(user.lastTask).add(lifetime, 'minutes')
          if user.lastId? and moment().utc().isBefore(expires_at)
            user.lastTask = moment().utc().format()
            res user.lastId
          else
            err "Sorry, you don't have any task active right now."

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


  setAlerts: (username, userPhid) ->
    return new Promise (res, err) =>
      if @data.alerts[username]?
        err 'This alert is already set.'
      else
        @data.alerts[username] = userPhid
        res()

  unsetAlerts: (username) ->
    return new Promise (res, err) =>
      if @data.alerts[username]?
        delete @data.alerts[username]
        res()
      else
        err 'This alert is not set yet.'

  taskInfo: (id) ->
    query = { 'task_id': id }
    @request query, 'maniphest.info'

  getTask: (id) ->
    query = { 'task_id': id }
    @request query, 'maniphest.info'

  fileInfo: (id) ->
    query = { 'id': id }
    @request query, 'file.info'

  pasteInfo: (id) ->
    query = { 'ids[0]': id }
    @request query, 'paste.query'

  genericInfo: (name) ->
    query = { 'names[]': name }
    @request query, 'phid.lookup'

  searchTask: (phid, terms, status = undefined, limit = 3) ->
    query = {
      'constraints[query]': terms.replace(' ', '+'),
      'constraints[projects][0]': phid,
      'order': 'newest',
      'limit': limit
    }
    if status?
      query['constraints[statuses][0]'] = status
    @request query, 'maniphest.search'

  searchAllTask: (terms, status = undefined, limit = 3) ->
    query = {
      'constraints[query]': terms.replace(' ', '+'),
      'order': 'newest',
      'limit': limit
    }
    if status?
      query['constraints[statuses][0]'] = status
    @request query, 'maniphest.search'

  createTask: (params) ->
    params.adapter = @robot.adapterName or 'test'
    @getBotPHID()
    .then (bot_phid) =>
      params.bot_phid = bot_phid
      if params.user?
        if not params.user?.name?
          params.user = { name: params.user }
      else
        params.user = { name: @robot.name, phid: params.bot_phid }
      @getTemplate(params.template)
    .then (description) =>
      if description?
        if params.description?
          params.description += "\n\n#{description}"
        else
          params.description = description
      @getProject(params.project)
    .then (projectparams) =>
      params.projectphid = projectparams.data.phid
      @getUser(params.user, params.user)
    .then (userPHID) =>
      query = {
        'transactions[0][type]': 'title',
        'transactions[0][value]': "#{params.title}",
        'transactions[1][type]': 'comment',
        'transactions[1][value]': "(created by #{params.user.name} on #{params.adapter})",
        'transactions[2][type]': 'subscribers.add',
        'transactions[2][value][0]': "#{userPHID}",
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
      if params.assign? and @data.users?[params.assign]?.phid
        owner = @data.users[params.assign]?.phid
        query["transactions[#{next}][type]"] = 'owner'
        query["transactions[#{next}][value]"] = owner
      @request(query, 'maniphest.edit')
    .then (body) ->
      id = body.result.object.id
      url = process.env.PHABRICATOR_URL + "/T#{id}"
      { id: id, url: url, user: params.user }

  createPaste: (user, title) ->
    adapter = @robot.adapterName
    bot_phid = null
    @getBotPHID()
    .bind(bot_phid)
    .then (bot_phid) =>
      @getUser(user, user)
    .then (userPhid) =>
      query = {
        'transactions[0][type]': 'title',
        'transactions[0][value]': "#{title}",
        'transactions[1][type]': 'text',
        'transactions[1][value]': "(created by #{user.name} on #{adapter})",
        'transactions[2][type]': 'subscribers.add',
        'transactions[2][value][0]': "#{userPhid}",
        'transactions[3][type]': 'subscribers.remove',
        'transactions[3][value][0]': "#{@bot_phid}"
      }
      @request(query, 'paste.edit')
    .then (body) ->
      body.result.object.id

  addComment: (user, id, comment) ->
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

  doActions: (user, id, commandString, comment) ->
    @getBotPHID()
    .bind({ bot_phid: null })
    .then (bot_phid) =>
      @bot_phid = bot_phid
      @taskInfo id
    .then (body) =>
      @parseAction user, body.result, commandString
    .then (results) =>
      if results.data.length > 0
        query = {
          'objectIdentifier': "T#{id}",
          'transactions[0][type]': 'subscribers.remove',
          'transactions[0][value][0]': "#{@bot_phid}"
        }
        project_add = []
        project_remove = []
        subscriber_add = []
        subscriber_remove = []
        i = 0
        for action in results.data
          if action.type is 'projects.add'
            project_add.push action.value
          else if action.type is 'projects.remove'
            project_remove.push action.value
          else if action.type is 'subscribers.add'
            subscriber_add.push action.value
          else if action.type is 'subscribers.remove'
            subscriber_remove.push action.value
          else
            i = i + 1
            query['transactions[' + i + '][type]'] = action.type
            query['transactions[' + i + '][value]'] = action.value

        if project_add.length > 0
          i = i + 1
          query['transactions[' + i + '][type]'] = 'projects.add'
          for phid, j in project_add
            query['transactions[' + i + '][value][' + j + ']'] = phid

        if project_remove.length > 0
          i = i + 1
          query['transactions[' + i + '][type]'] = 'projects.remove'
          for phid, j in project_remove
            query['transactions[' + i + '][value][' + j + ']'] = phid

        if subscriber_add.length > 0
          i = i + 1
          query['transactions[' + i + '][type]'] = 'subscribers.add'
          for phid, j in subscriber_add
            query['transactions[' + i + '][value][' + j + ']'] = phid

        if subscriber_remove.length > 0
          i = i + 1
          query['transactions[' + i + '][type]'] = 'subscribers.remove'
          for phid, j in subscriber_remove
            query['transactions[' + i + '][value][' + j + ']'] = phid

        i = i + 1
        query['transactions[' + i + '][type]'] = 'comment'
        if comment?
          query['transactions[' + i + '][value]'] = "#{comment} (#{user.name})"
        else
          query['transactions[' + i + '][value]'] =
            "#{results.messages.join(', ')} (by #{user.name})"
        @request(query, 'maniphest.edit')
        .then (body) ->
          { id: id, message: results.messages.join(', '), notices: results.notices }
      else
        { id: id, message: results.messages.join(', '), notices: results.notices }
    .catch (e) ->
      { id: id, message: null, notices: [ e ] }

  parseAction: (user, item, str, payload = { data: [], messages: [], notices: [] }) ->
    return new Promise (res, err) =>
      p = new RegExp('^(in|not in|on|for|is|to|sub|unsub) ([^ ]*)')
      r = str.trim().match p
      switch r[1]
        when 'in'
          @getProject(r[2])
          .then (projectData) =>
            phid = projectData.data.phid
            if phid not in item.projectPHIDs
              payload.data.push({ type: 'projects.add', value: [phid] })
              payload.messages.push("been added to #{r[2]}")
            else
              payload.notices.push("T#{item.id} is already in #{r[2]}")
            next = str.trim().replace(p, '')
            if next.trim() isnt ''
              res @parseAction(user, item, next, payload)
            else
              res payload
          .catch (e) ->
            payload.notices.push(e)
            res payload
        when 'not in'
          @getProject(r[2])
          .then (projectData) =>
            phid = projectData.data.phid
            if phid in item.projectPHIDs
              payload.data.push({ type: 'projects.remove', value: [phid] })
              payload.messages.push("been removed from #{r[2]}")
            else
              payload.notices.push("T#{item.id} is already not in #{r[2]}")
            next = str.trim().replace(p, '')
            if next.trim() isnt ''
              res @parseAction(user, item, next, payload)
            else
              res payload
          .catch (e) ->
            payload.notices.push(e)
            res payload
        when 'on', 'for'
          @getUser(user, { name: r[2] })
          .then (userphid) =>
            if r[2] is 'me'
              r[2] = user.name
            payload.data.push({ type: 'owner', value: userphid })
            payload.messages.push("owner set to #{r[2]}")
            next = str.trim().replace(p, '')
            if next.trim() isnt ''
              res @parseAction(user, item, next, payload)
            else
              res payload
          .catch (e) ->
            payload.notices.push(e)
            res payload
        when 'sub'
          @getUser(user, { name: r[2] })
          .then (userphid) =>
            if r[2] is 'me'
              r[2] = user.name
            if userphid not in item.ccPHIDs
              payload.data.push({ type: 'subscribers.add', value: [userphid] })
              payload.messages.push("subscribed #{r[2]}")
            else
              payload.notices.push("#{r[2]} already subscribed to T#{item.id}")
            next = str.trim().replace(p, '')
            if next.trim() isnt ''
              res @parseAction(user, item, next, payload)
            else
              res payload
          .catch (e) ->
            payload.notices.push(e)
            res payload
        when 'unsub'
          @getUser(user, { name: r[2] })
          .then (userphid) =>
            if r[2] is 'me'
              r[2] = user.name
            if userphid in item.ccPHIDs
              payload.data.push({ type: 'subscribers.remove', value: [userphid] })
              payload.messages.push("unsubscribed #{r[2]}")
            else
              payload.notices.push("#{r[2]} is not subscribed to T#{item.id}")
            next = str.trim().replace(p, '')
            if next.trim() isnt ''
              res @parseAction(user, item, next, payload)
            else
              res payload
          .catch (e) ->
            payload.notices.push(e)
            res payload
        when 'to'
          if not item.projectPHIDs? or item.projectPHIDs.length is 0
            err 'This item has no tag/project yet.'
          else
            cols = Promise.map item.projectPHIDs, (phid) =>
              @getProject(phid)
              .then (projectData) ->
                for i in Object.keys(projectData.data.columns)
                  if (new RegExp(r[2])).test i
                    return { colname: i, colphid: projectData.data.columns[i] }
            Promise.all(cols)
            .then (cols) =>
              cols = cols.filter (c) ->
                c?
              if cols.length > 0
                payload.data.push({ type: 'column', value: cols[0].colphid })
                payload.messages.push("column changed to #{cols[0].colname}")
              else
                payload.notices.push("T#{item.id} cannot be moved to #{r[2]}")
              next = str.trim().replace(p, '')
              if next.trim() isnt ''
                res @parseAction(user, item, next, payload)
              else
                res payload
            .catch (e) ->
              payload.notices.push(e)
              res payload
        when 'is'
          if @statuses[r[2]]?
            payload.data.push({ type: 'status', value: @statuses[r[2]] })
            payload.messages.push("status set to #{r[2]}")
          else if @priorities[r[2]]?
            payload.data.push({ type: 'priority', value: @priorities[r[2]] })
            payload.messages.push("priority set to #{r[2]}")
          else
            err "Unknown status or priority '#{r[2]}', please choose in " +
                Object.keys(@statuses).join(', ') + ', ' +
                Object.keys(@priorities).join(', ')
          next = str.trim().replace(p, '')
          if next.trim() isnt ''
            res @parseAction(user, item, next, payload)
          else
            res payload

  listTasks: (projphid) ->
    query = {
      'projectPHIDs[0]': "#{projphid}",
      'status': 'status-open'
    }
    @request query, 'maniphest.query'

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

  getTemplate: (name) =>
    return new Promise (res, err) =>
      if name?
        if @data.templates[name]?
          query = {
            task_id: @data.templates[name].task
          }
          @request(query, 'maniphest.info')
          .then (body) ->
            res body.result.description
          .catch (e) ->
            err e
        else
          err "There is no template named '#{name}'."
      else
        res null

  addTemplate: (name, taskid) ->
    return new Promise (res, err) =>
      if @data.templates[name]?
        err "Template '#{name}' already exists."
      else
        data = @data
        @taskInfo(taskid)
        .then (body) ->
          data.templates[name] = { task: taskid }
          res 'Ok'
        .catch (e) ->
          err e

  showTemplate: (name) ->
    return new Promise (res, err) =>
      if @data.templates[name]?
        res @data.templates[name]
      else
        err "Template '#{name}' was not found."

  searchTemplate: (term) ->
    return new Promise (res, err) =>
      back = [ ]
      for name, template of @data.templates
        if new RegExp(term).test name
          back.push { name: name, task: template.task }
      if back.length is 0
        if term?
          err "No template matches '#{term}'."
        else
          err 'There is no template defined.'
      else
        res back
        
  removeTemplate: (name) ->
    return new Promise (res, err) =>
      if @data.templates[name]?
        delete @data.templates[name]
        res 'Ok'
      else
        err "Template '#{name}' was not found."

  updateTemplate: (name, taskid) ->
    return new Promise (res, err) =>
      if @data.templates[name]?
        data = @data
        @taskInfo(taskid)
        .then (body) ->
          data.templates[name] = { task: taskid }
          res 'Ok'
        .catch (e) ->
          err e
      else
        err "Template '#{name}' was not found."

  renameTemplate: (name, newname) ->
    return new Promise (res, err) =>
      if @data.templates[name]?
        if @data.templates[newname]?
          err "Template '#{newname}' already exists."
        else
          @data.templates[newname] = { task: @data.templates[name].task }
          delete @data.templates[name]
          res 'Ok'
      else
        err "Template '#{name}' was not found."



module.exports = Phabricator
