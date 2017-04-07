require('es6-promise').polyfill()

Helper = require('hubot-test-helper')
Hubot = require('../node_modules/hubot')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs_commands.coffee')

path   = require 'path'
nock   = require 'nock'
sinon  = require 'sinon'
expect = require('chai').use(require('sinon-chai')).expect

room = null

# --------------------------------------------------------------------------------------------------
describe 'phabs_commands module with no bot_phid', ->

  hubotHear = (message, userName = 'momo', tempo = 40) ->
    beforeEach (done) ->
      room.user.say userName, message
      setTimeout (done), tempo

  hubot = (message, userName = 'momo') ->
    hubotHear "@hubot #{message}", userName

  hubotResponse = (i = 1) ->
    room.messages[i]?[1]

  hubotResponseCount = ->
    room.messages?.length - 1

  beforeEach ->
    process.env.PHABRICATOR_URL = 'http://example.com'
    process.env.PHABRICATOR_API_KEY = 'xxx'
    room = helper.createRoom { httpd: false }
    room.robot.brain.data.phabricator.users['user_with_phid'] = {
      phid: 'PHID-USER-123456789'
    }
    room.receive = (userName, message) ->
      new Promise (resolve) =>
        @messages.push [userName, message]
        user = { name: userName, id: userName }
        @robot.receive(new Hubot.TextMessage(user, message), resolve)

  afterEach ->
    delete process.env.PHABRICATOR_URL
    delete process.env.PHABRICATOR_API_KEY

  context 'user creates a new task, ', ->

    context 'a task without description, ', ->
      beforeEach ->
        delete process.env.PHABRICATOR_BOT_PHID
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.whoami')
          .reply(200, { result: { phid: 'PHID-USER-123456789' } })
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab new proj1 a task', 'user_with_phid'
        it 'replies with the object id', ->
          expect(hubotResponse()).to.eql 'Task T42 created = http://example.com/T42'

    context 'a task without description, with an unknown bot', ->
      beforeEach ->
        delete process.env.PHABRICATOR_BOT_PHID
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.whoami')
          .reply(200, { error_info: 'Unknown user' })
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab new proj1 a task', 'user_with_phid'
        it 'replies with the object id', ->
          expect(hubotResponse()).to.eql 'Unknown user'

# --------------------------------------------------------------------------------------------------
describe 'phabs_commands module', ->

  hubotEmit = (e, data, tempo = 40) ->
    beforeEach (done) ->
      room.robot.emit e, data
      setTimeout (done), tempo
 
  hubotHear = (message, userName = 'momo', tempo = 40) ->
    beforeEach (done) ->
      room.user.say userName, message
      setTimeout (done), tempo

  hubot = (message, userName = 'momo') ->
    hubotHear "@hubot #{message}", userName

  hubotResponse = (i = 1) ->
    room.messages[i]?[1]

  hubotResponseCount = ->
    room.messages?.length - 1

  beforeEach ->
    process.env.PHABRICATOR_URL = 'http://example.com'
    process.env.PHABRICATOR_API_KEY = 'xxx'
    process.env.PHABRICATOR_BOT_PHID = 'PHID-USER-xxx'
    room = helper.createRoom { httpd: false }
    room.robot.brain.userForId 'user', {
      name: 'user'
    }
    room.robot.brain.userForId 'user_with_email', {
      name: 'user_with_email',
      email_address: 'user@example.com'
    }
    room.robot.brain.userForId 'user_with_phid', {
      name: 'user_with_phid',
      phid: 'PHID-USER-123456789'
    }
    room.robot.brain.data.phabricator.users['user_with_phid'] = {
      phid: 'PHID-USER-123456789',
      id: 'user_with_phid',
      name: 'user_with_phid'
    }
    room.robot.brain.data.phabricator.users['user_phab'] = {
      phid: 'PHID-USER-123456789',
      id: 'user_phab',
      name: 'user_phab'
    }
    room.receive = (userName, message) ->
      new Promise (resolve) =>
        @messages.push [userName, message]
        user = { name: userName, id: userName }
        @robot.receive(new Hubot.TextMessage(user, message), resolve)

  afterEach ->
    delete process.env.PHABRICATOR_URL
    delete process.env.PHABRICATOR_API_KEY
    delete process.env.PHABRICATOR_BOT_PHID

# --------------------------------------------------------------------------------------------------
  context 'user wants to know hubot-phabs version', ->

    context 'phab version', ->
      hubot 'phab version'
      it 'should reply version number', ->
        expect(hubotResponse()).to.match /hubot-phabs module is version [0-9]+\.[0-9]+\.[0-9]+/

    context 'ph version', ->
      hubot 'ph version'
      it 'should reply version number', ->
        expect(hubotResponse()).to.match /hubot-phabs module is version [0-9]+\.[0-9]+\.[0-9]+/

# --------------------------------------------------------------------------------------------------
  context 'user blacklists an item', ->
    beforeEach ->
      room.robot.brain.data.phabricator.blacklist = [ ]
      do nock.disableNetConnect
    afterEach ->
      room.robot.brain.data.phabricator.blacklist = [ ]
      nock.cleanAll()

    hubot 'phab bl T42'
    it 'says the item is now blacklisted', ->
      expect(hubotResponse()).to.eql 'Ok. T42 won\'t react anymore to auto-detection.'
    it 'adds the item in brain blacklist', ->
      expect(room.robot.brain.data.phabricator.blacklist).to.contains 'T42'

# --------------------------------------------------------------------------------------------------
  context 'user unblacklists an item', ->
    beforeEach ->
      room.robot.brain.data.phabricator.blacklist = [ 'T42', 'V5' ]
      do nock.disableNetConnect
    afterEach ->
      room.robot.brain.data.phabricator.blacklist = [ ]
      nock.cleanAll()

    hubot 'phab unbl T42'
    it 'says the item is now blacklisted', ->
      expect(hubotResponse()).to.eql 'Ok. T42 now will react to auto-detection.'
    it 'adds the item in brain blacklist', ->
      expect(room.robot.brain.data.phabricator.blacklist).not.to.contains 'T42'

# --------------------------------------------------------------------------------------------------
  context 'user asks for task info', ->

    context 'task id is provided', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': 42,
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            title: 'some task',
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-42'
            } })
          .get('/api/user.query')
          .query({
            'phids[0]': 'PHID-USER-42',
            'api.token': 'xxx'
          })
          .reply(200, { result: [{ userName: 'toto' }] })

      afterEach ->
        nock.cleanAll()

      context 'phab T42', ->
        hubot 'phab T42'
        it 'gives information about the task Txxx', ->
          expect(hubotResponse()).to.eql 'T42 - some task (open, Low, owner toto)'

      context 'ph T42 # with an ending space', ->
        hubot 'ph T42 '
        it 'gives information about the task Txxx', ->
          expect(hubotResponse()).to.eql 'T42 - some task (open, Low, owner toto)'

    context 'task id is provided but doesn not exist', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { error_info: 'No such Maniphest task exists.' })

      afterEach ->
        nock.cleanAll()

      context 'phab T42', ->
        hubot 'phab T42'
        it 'gives information about the task Txxx', ->
          expect(hubotResponse()).to.eql 'No such Maniphest task exists.'


    context 'failed implicit re-use of the object id', ->
      context 'when user is known and his phid is in the brain', ->
        hubot 'ph', 'user_with_phid'
        it 'complains that there is no active object id in memory', ->
          expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

    context 'task id is provided, and owner is null', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': 42,
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            title: 'some task',
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: null
            } })

      afterEach ->
        nock.cleanAll()

      context 'phab T42', ->
        hubot 'phab T42'
        it 'gives information about the task Txxx', ->
          expect(hubotResponse()).to.eql 'T42 - some task (open, Low, owner nobody)'

    context 'task id is provided, and owner is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': 42,
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            title: 'some task',
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-42'
            } })
          .get('/api/user.query')
          .reply(200, { error_info: 'unknown user' })

      afterEach ->
        nock.cleanAll()

      context 'phab T42', ->
        hubot 'phab T42'
        it 'gives information about the task Txxx', ->
          expect(hubotResponse()).to.eql 'unknown user'


    context 'task id is provided, and owner is set, but not in brain', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': 42,
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            title: 'some task',
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-000000'
            } })
          .get('/api/user.query')
          .query({
            'phids[0]': 'PHID-USER-000000',
            'api.token': 'xxx'
          })
          .reply(200, { result: [] })

      afterEach ->
        nock.cleanAll()

      context 'phab T42', ->
        hubot 'phab T42'
        it 'gives information about the task Txxx', ->
          expect(hubotResponse()).to.eql 'T42 - some task (open, Low, owner unknown)'

# --------------------------------------------------------------------------------------------------
  context 'user asks for next checkbox of a task', ->

    context 'task id is provided', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': 42,
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            description: 'description\n[ ] something\n[ ] another',
            ownerPHID: 'PHID-USER-42'
            } })

      afterEach ->
        nock.cleanAll()

      context 'phab T42 next', ->
        hubot 'phab T42 next', 'user_with_phid'
        it 'gives information about the next checkbox', ->
          expect(hubotResponse()).to.eql 'Next on T42 is: [ ] something'


      context 'phab T42 next ano', ->
        hubot 'phab T42 next ano', 'user_with_phid'
        it 'gives information about the next checkbox', ->
          expect(hubotResponse()).to.eql 'Next on T42 is: [ ] another'


      context 'phab T42 next THe', ->
        hubot 'phab T42 next THe', 'user_with_phid'
        it 'gives information about the next checkbox', ->
          expect(hubotResponse()).to.eql 'Next on T42 is: [ ] another'


    context 'task id is provided but there is no checkboxes', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': 42,
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            description: 'description\nand no checkboxes',
            ownerPHID: 'PHID-USER-42'
            } })

      afterEach ->
        nock.cleanAll()

      context 'phab T42 next', ->
        hubot 'phab T42 next', 'user_with_phid'
        it 'gives information about the next checkbox', ->
          expect(hubotResponse()).to.eql 'The task T42 has no unchecked checkboxes.'

      context 'phab T42 next ano', ->
        hubot 'phab T42 next ano', 'user_with_phid'
        it 'gives information about the next checkbox', ->
          expect(hubotResponse()).to.eql 'The task T42 has no unchecked checkbox matching ano.'


    context 'task id is provided but doesn not exist', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { error_info: 'No such Maniphest task exists.' })

      afterEach ->
        nock.cleanAll()

      context 'phab T42 next', ->
        hubot 'phab T42 next'
        it 'tells that the task does not exist', ->
          expect(hubotResponse()).to.eql 'No such Maniphest task exists.'


    context 'failed implicit re-use of the object id', ->
      context 'when user is known and his phid is in the brain', ->
        hubot 'ph next', 'user_with_phid'
        it 'complains that there is no active object id in memory', ->
          expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

# --------------------------------------------------------------------------------------------------
  context 'user asks for previous checkbox of a task', ->

    context 'task id is provided', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            description: 'description\n[x] something\n[x] another\n[x] something2',
            ownerPHID: 'PHID-USER-42'
            } })

      afterEach ->
        nock.cleanAll()

      context 'phab T42 prev', ->
        hubot 'phab T42 prev', 'user_with_phid'
        it 'gives information about the previous checkbox', ->
          expect(hubotResponse()).to.eql 'Previous on T42 is: [x] something2'


      context 'phab T42 prev ano', ->
        hubot 'phab T42 prev ano', 'user_with_phid'
        it 'gives information about the previous checkbox', ->
          expect(hubotResponse()).to.eql 'Previous on T42 is: [x] another'

    context 'task id is provided but there is no checkboxes', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': 42,
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            description: 'description\nand no checkboxes',
            ownerPHID: 'PHID-USER-42'
            } })

      afterEach ->
        nock.cleanAll()

      context 'phab T42 previous', ->
        hubot 'phab T42 previous', 'user_with_phid'
        it 'gives information about the previous checkbox', ->
          expect(hubotResponse()).to.eql 'The task T42 has no checked checkboxes.'

      context 'phab T42 previous ano', ->
        hubot 'phab T42 previous ano', 'user_with_phid'
        it 'gives information about the previous checkbox', ->
          expect(hubotResponse()).to.eql 'The task T42 has no checked checkbox matching ano.'


    context 'task id is provided but doesn not exist', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { error_info: 'No such Maniphest task exists.' })

      afterEach ->
        nock.cleanAll()

      context 'phab T42 previous', ->
        hubot 'phab T42 previous'
        it 'tells that the task does not exist', ->
          expect(hubotResponse()).to.eql 'No such Maniphest task exists.'


    context 'failed implicit re-use of the object id', ->
      context 'when user is known and his phid is in the brain', ->
        hubot 'ph previous', 'user_with_phid'
        it 'complains that there is no active object id in memory', ->
          expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

# --------------------------------------------------------------------------------------------------
  context 'user checks the checkbox of a task', ->

    context 'task id is provided', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': 42,
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            description: 'description\n[ ] something\n[ ] another',
            ownerPHID: 'PHID-USER-42'
            } })
          .get('/api/maniphest.edit')
          .reply(200, { result: { id: 42 } })

      afterEach ->
        nock.cleanAll()

      context 'phab T42 check', ->
        hubot 'phab T42 check', 'user_with_phid'
        it 'gives information about the next checkbox', ->
          expect(hubotResponse()).to.eql 'Checked on T42: [x] something'
          expect(hubotResponse(2)).to.be.undefined

      context 'phab T42 check ano', ->
        hubot 'phab T42 check ano', 'user_with_phid'
        it 'gives information about the next checkbox', ->
          expect(hubotResponse()).to.eql 'Checked on T42: [x] another'
          expect(hubotResponse(2)).to.be.undefined

    context 'task id is provided', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': 42,
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            description: 'description\n[ ] something\n[ ] another\n[ ] something else',
            ownerPHID: 'PHID-USER-42'
            } })
          .get('/api/maniphest.edit')
          .reply(200, { result: { id: 42 } })

      afterEach ->
        nock.cleanAll()

      context 'phab T42 check!', ->
        hubot 'phab T42 check!', 'user_with_phid'
        it 'gives information about the next checkbox', ->
          expect(hubotResponse()).to.eql 'Checked on T42: [x] something'
          expect(hubotResponse(2)).to.eql 'Next on T42: [ ] another'

      context 'phab T42 check! some', ->
        hubot 'phab T42 check! some', 'user_with_phid'
        it 'gives information about the next checkbox', ->
          expect(hubotResponse()).to.eql 'Checked on T42: [x] something'
          expect(hubotResponse(2)).to.eql 'Next on T42: [ ] something else'

      context 'phab T42 check! some + some comment', ->
        hubot 'phab T42 check! some + some comment', 'user_with_phid'
        it 'gives information about the next checkbox', ->
          expect(hubotResponse()).to.eql 'Checked on T42: [x] something'
          expect(hubotResponse(2)).to.eql 'Next on T42: [ ] something else'

      context 'phab T42 check! ano', ->
        hubot 'phab T42 check! ano', 'user_with_phid'
        it 'gives information about the next checkbox', ->
          expect(hubotResponse()).to.eql 'Checked on T42: [x] another'
          expect(hubotResponse(2)).
            to.eql 'Next on T42: there is no more unchecked checkbox matching ano.'

    context 'task id is provided but edit fails', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': 42,
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            description: 'description\n[ ] something\n[ ] another',
            ownerPHID: 'PHID-USER-42'
            } })
          .get('/api/maniphest.edit')
          .reply(200, { error_info: 'no permission to edit' })

      afterEach ->
        nock.cleanAll()

      context 'phab T42 check', ->
        hubot 'phab T42 check', 'user_with_phid'
        it 'gives information about the next checkbox', ->
          expect(hubotResponse()).to.eql 'no permission to edit'


    context 'task id is provided but there is no checkboxes', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': 42,
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            description: 'description\nand no checkboxes',
            ownerPHID: 'PHID-USER-42'
            } })

      afterEach ->
        nock.cleanAll()

      context 'phab T42 check', ->
        hubot 'phab T42 check', 'user_with_phid'
        it 'gives information about the next checkbox', ->
          expect(hubotResponse()).to.eql 'The task T42 has no unchecked checkbox.'

      context 'phab T42 check ano', ->
        hubot 'phab T42 check ano', 'user_with_phid'
        it 'gives information about the next checkbox', ->
          expect(hubotResponse()).to.eql 'The task T42 has no unchecked checkbox matching ano.'


    context 'task id is provided but doesn not exist', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { error_info: 'No such Maniphest task exists.' })

      afterEach ->
        nock.cleanAll()

      context 'phab T42 check', ->
        hubot 'phab T42 check'
        it 'tells that the task does not exist', ->
          expect(hubotResponse()).to.eql 'No such Maniphest task exists.'


    context 'failed implicit re-use of the object id', ->
      context 'when user is known and his phid is in the brain', ->
        hubot 'ph check', 'user_with_phid'
        it 'complains that there is no active object id in memory', ->
          expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

# --------------------------------------------------------------------------------------------------
  context 'user unchecks the checkbox of a task', ->

    context 'task id is provided', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': 42,
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            description: 'description\n[x] another\n[x] something\n[x] another one',
            ownerPHID: 'PHID-USER-42'
            } })
          .get('/api/maniphest.edit')
          .reply(200, { result: { id: 42 } })

      afterEach ->
        nock.cleanAll()

      context 'phab T42 uncheck', ->
        hubot 'phab T42 uncheck', 'user_with_phid'
        it 'gives information about the previous checkbox', ->
          expect(hubotResponse()).to.eql 'Unchecked on T42: [ ] another one'
          expect(hubotResponse(2)).to.be.undefined

      context 'phab T42 uncheck some', ->
        hubot 'phab T42 uncheck some', 'user_with_phid'
        it 'gives information about the previous checkbox', ->
          expect(hubotResponse()).to.eql 'Unchecked on T42: [ ] something'
          expect(hubotResponse(2)).to.be.undefined

      context 'phab T42 uncheck some + some comment', ->
        hubot 'phab T42 uncheck some + some comment', 'user_with_phid'
        it 'gives information about the previous checkbox', ->
          expect(hubotResponse()).to.eql 'Unchecked on T42: [ ] something'
          expect(hubotResponse(2)).to.be.undefined

    context 'task id is provided', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': 42,
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            description: 'description\n[x] another\n[x] something\n[x] another one',
            ownerPHID: 'PHID-USER-42'
            } })
          .get('/api/maniphest.edit')
          .reply(200, { result: { id: 42 } })

      afterEach ->
        nock.cleanAll()

      context 'phab T42 uncheck!', ->
        hubot 'phab T42 uncheck!', 'user_with_phid'
        it 'gives information about the previous checkbox', ->
          expect(hubotResponse()).to.eql 'Unchecked on T42: [ ] another one'
          expect(hubotResponse(2)).to.eql 'Previous on T42: [x] something'

      context 'phab T42 uncheck! ano', ->
        hubot 'phab T42 uncheck! ano', 'user_with_phid'
        it 'gives information about the previous checkbox', ->
          expect(hubotResponse()).to.eql 'Unchecked on T42: [ ] another one'
          expect(hubotResponse(2)).to.eql 'Previous on T42: [x] another'

      context 'phab T42 uncheck! some', ->
        hubot 'phab T42 uncheck! some', 'user_with_phid'
        it 'gives information about the previous checkbox', ->
          expect(hubotResponse()).to.eql 'Unchecked on T42: [ ] something'
          expect(hubotResponse(2)).
            to.eql 'Previous on T42: there is no more checked checkbox matching some.'

    context 'task id is provided but edit fails', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': 42,
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            description: 'description\n[x] something\n[x] another',
            ownerPHID: 'PHID-USER-42'
            } })
          .get('/api/maniphest.edit')
          .reply(200, { error_info: 'no permission to edit' })

      afterEach ->
        nock.cleanAll()

      context 'phab T42 uncheck', ->
        hubot 'phab T42 uncheck', 'user_with_phid'
        it 'gives information about the previous checkbox', ->
          expect(hubotResponse()).to.eql 'no permission to edit'


    context 'task id is provided but there is no checkboxes', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': 42,
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            description: 'description\nand no checkboxes',
            ownerPHID: 'PHID-USER-42'
            } })

      afterEach ->
        nock.cleanAll()

      context 'phab T42 uncheck', ->
        hubot 'phab T42 uncheck', 'user_with_phid'
        it 'gives information about the previous checkbox', ->
          expect(hubotResponse()).to.eql 'The task T42 has no checked checkbox.'

      context 'phab T42 uncheck ano', ->
        hubot 'phab T42 uncheck ano', 'user_with_phid'
        it 'gives information about the previous checkbox', ->
          expect(hubotResponse()).to.eql 'The task T42 has no checked checkbox matching ano.'


    context 'task id is provided but doesn not exist', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { error_info: 'No such Maniphest task exists.' })

      afterEach ->
        nock.cleanAll()

      context 'phab T42 uncheck', ->
        hubot 'phab T42 uncheck'
        it 'tells that the task does not exist', ->
          expect(hubotResponse()).to.eql 'No such Maniphest task exists.'


    context 'failed implicit re-use of the object id', ->
      context 'when user is known and his phid is in the brain', ->
        hubot 'ph uncheck', 'user_with_phid'
        it 'complains that there is no active object id in memory', ->
          expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

# --------------------------------------------------------------------------------------------------
  context 'user asks about a user', ->

    context 'an unknown user', ->
      hubot 'phab user toto'
      it 'warns when that user is unknown', ->
        expect(hubotResponse()).to.eql 'Sorry, I can\'t figure toto email address. ' +
                                       'Can you ask them to `.phab me as <email>`?'

    context 'an unknown user but hubot-auth is loaded', ->
      beforeEach ->
        process.env.HUBOT_AUTH_ADMIN = 'admin_user'
        room.robot.brain.data.phabricator = { users: { } }
        room.robot.loadFile path.resolve('node_modules/hubot-auth/src'), 'auth.coffee'
        room.robot.brain.userForId 'admin_user', {
          id: 'admin_user',
          name: 'admin_user',
          phid: 'PHID-USER-123456789'
        }
        room.robot.brain.userForId 'phadmin_user', {
          id: 'phadmin_user',
          name: 'phadmin_user',
          phid: 'PHID-USER-123456789',
          roles: [
            'phadmin'
          ]
        }
        room.robot.brain.userForId 'phuser_user', {
          id: 'phuser_user',
          name: 'phuser_user',
          phid: 'PHID-USER-123456789',
          roles: [
            'phuser'
          ]
        }
        room.receive = (userName, message) ->
          new Promise (resolve) =>
            @messages.push [userName, message]
            user = @robot.brain.userForName(userName)
            @robot.receive(new Hubot.TextMessage(user, message), resolve)

      context 'and you are admin', ->
        hubot 'phab user toto', 'admin_user'
        it 'warns when that user is unknown', ->
          expect(hubotResponse()).to.eql 'Sorry, I can\'t figure toto email address. ' +
                                         'Can you help me with `.phab user toto = <email>`?'
      context 'and you are phadmin', ->
        hubot 'phab user toto', 'phadmin_user'
        it 'warns when that user is unknown', ->
          expect(hubotResponse()).to.eql 'Sorry, I can\'t figure toto email address. ' +
                                         'Can you help me with `.phab user toto = <email>`?'

      context 'and you are not admin', ->
        hubot 'phab user toto', 'phuser_user'
        it 'warns when that user is unknown', ->
          expect(hubotResponse()).to.eql 'Sorry, I can\'t figure toto email address. ' +
                                         'Can you ask them to `.phab me as <email>`?'

    context 'user has an email', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.query')
          .reply(200, { result: [{ phid: 'PHID-USER-999' }] })

      afterEach ->
        nock.cleanAll()

      context 'phab user user_with_email', ->
        hubot 'phab user user_with_email'
        it 'gets the phid for the user if he has an email', ->
          phid = room.robot.brain.data.phabricator.users['user_with_email'].phid
          expect(hubotResponse()).to.eql "Hey I know user_with_email, he's PHID-USER-999"
          expect(phid).to.eql 'PHID-USER-999'

    context 'user has an email, but unknown to phabricator', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.query')
          .reply(200, { result: [] })

      afterEach ->
        nock.cleanAll()

      context 'phab user user_with_email', ->
        hubot 'phab user user_with_email'
        it 'gets a message complaining about the impossibility to match an email', ->
          expect(hubotResponse()).to.eql 'Sorry, I cannot find user@example.com :('

    context 'phab user user_with_phid', ->
      hubot 'phab user user_with_phid'
      it 'gives the phid', ->
        expect(hubotResponse()).to.eql "Hey I know user_with_phid, he's PHID-USER-123456789"
      it 'records the user data in phabricator brain', ->
        expect(room.robot.brain.data.phabricator.users.user_with_phid.phid).
          to.eql 'PHID-USER-123456789'

# --------------------------------------------------------------------------------------------------
  context 'user declares his own email', ->
    beforeEach ->
      do nock.disableNetConnect
      nock(process.env.PHABRICATOR_URL)
        .get('/api/user.query')
        .reply(200, { result: [{ phid: 'PHID-USER-999' }] })

    afterEach ->
      nock.cleanAll()

    context 'phab me as momo@example.com', ->
      hubot 'phab me as momo@example.com', 'user'
      it 'says all is going to be fine', ->
        phid = room.robot.brain.data.phabricator.users['user'].phid
        expect(hubotResponse()).to.eql 'Now I know you, you are PHID-USER-999'
        expect(phid).to.eql 'PHID-USER-999'

# --------------------------------------------------------------------------------------------------
  context 'user declares email for somebody else', ->
    beforeEach ->
      do nock.disableNetConnect
      nock(process.env.PHABRICATOR_URL)
        .get('/api/user.query')
        .reply(200, { result: [{ phid: 'PHID-USER-999' }] })

    afterEach ->
      nock.cleanAll()

    context 'phab user user = user@example.com', ->
      hubot 'phab user user = user@example.com'
      it 'sets the email for the user', ->
        phid = room.robot.brain.data.phabricator.users['user'].phid
        expect(hubotResponse()).to.eql "Now I know user, he's PHID-USER-999"
        expect(phid).to.eql 'PHID-USER-999'

# --------------------------------------------------------------------------------------------------
  context 'user creates a new task, ', ->

    context 'a task without description, ', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when user is doing it for the first time and has no email recorded', ->
        hubot 'phab new proj1 a task'
        it 'invites the user to set his email address', ->
          expect(hubotResponse()).to.eql "Sorry, I can't figure out your email address :( " +
                                         'Can you tell me with `.phab me as <email>`?'
      context 'when user is doing it for the first time and has set an email addresse', ->
        hubot 'phab new proj1 a task', 'user_with_email'
        it 'replies with the object id, and records phid for user', ->
          phid = room.robot.brain.data.phabricator.users['user_with_email'].phid
          expect(hubotResponse()).to.eql 'Task T42 created = http://example.com/T42'
          expect(phid).to.eql 'PHID-USER-42'
      context 'when user is known and his phid is in the brain (users)', ->
        hubot 'phab new proj1 a task', 'user_with_phid'
        it 'replies with the object id', ->
          expect(hubotResponse()).to.eql 'Task T42 created = http://example.com/T42'


    context 'a task with description, ', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab new proj1 a task = with a description', 'user_with_phid'
        it 'replies with the object id', ->
          expect(hubotResponse()).to.eql 'Task T42 created = http://example.com/T42'


    context 'phab new proj1 a task', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { error_info: 'Something went wrong' })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when something goes wrong on phabricator side', ->
        hubot 'phab new proj1 a task', 'user_with_phid'
        it 'informs that something went wrong', ->
          expect(hubotResponse()).to.eql 'Something went wrong'


    context 'phab new proj2 a task', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj2': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 24 } } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab new proj2 a task', 'user_with_phid'
        it 'replies with the object id', ->
          expect(hubotResponse()).to.eql 'Task T24 created = http://example.com/T24'


    context 'implicit re-use of the object id', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj2': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42', userName: 'user_with_phid' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 24 } } })
          .get('/api/maniphest.info')
          .reply(200, { result: {
            title: 'some task',
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-123456789'
            } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab new proj2 a task', 'user_with_phid'
        hubot 'ph', 'user_with_phid'
        it 'replies with the object id', ->
          # console.log room.robot.brain.data.phabricator.users.user_with_phid
          expect(hubotResponse(1)).to.eql 'Task T24 created = http://example.com/T24'
          expect(hubotResponse(3)).to.eql 'T24 - some task (open, Low, owner user_with_phid)'


    context 'phab new proj2 a task', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = { }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.search')
          .query({
            'names[0]': 'proj2',
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            'data': [
              {
                'id': '1402',
                'phid': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                'fields': {
                  'name': 'proj2',
                }
              }
            ]
          } })
          .get('/api/maniphest.query')
          .query({
            'projectPHIDs[0]': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            'status': 'status-any',
            'order': 'order-modified'
          })
          .reply(200, { result: {
            'PHID-TASK-llyghhtxzgc25wbsn7lk': {
              'id': '12',
              'phid': 'PHID-TASK-llyghhtxzgc25wbsn7lk'
            },
            'PHID-TASK-lnpaaqlyvkuar5yf7qk6': {
              'id': '13',
              'phid': 'PHID-TASK-lnpaaqlyvkuar5yf7qk6'
            }
          } })
          .get('/api/maniphest.gettasktransactions')
          .query({
            'ids[]': [ 12, 13 ]
          })
          .reply(200, { result: {
            '12': [
              {
                'taskID': '12',
                'transactionType': 'status',
                'oldValue': 'open',
                'newValue': 'resolved'
              },
              {
                'taskID': '12',
                'transactionType': 'core:columns',
                'oldValue': null,
                'newValue': [
                  {
                    'boardPHID': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                    'columnPHID': 'PHID-PCOL-ikeu5quydkkw55cqlbmx'
                  }
                ]
              }
            ],
            '13': [
              {
                'taskID': '13',
                'transactionType': 'status',
                'oldValue': 'open',
                'newValue': 'resolved'
              },
              {
                'taskID': '13',
                'transactionType': 'core:columns',
                'oldValue': null,
                'newValue': [
                  {
                    'boardPHID': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                    'columnPHID': 'PHID-PCOL-ikeu5quydkkw55cqlb00'
                  }
                ]
              }
            ]
          } })
          .get('/api/phid.lookup')
          .query({
            'names[]': [
              'PHID-PCOL-ikeu5quydkkw55cqlbmx',
              'PHID-PCOL-ikeu5quydkkw55cqlb00'
            ]
          })
          .reply(200, { result: {
            'PHID-PCOL-ikeu5quydkkw55cqlbmx': {
              'phid': 'PHID-PCOL-ikeu5quydkkw55cqlbmx',
              'name': 'Back Log'
            },
            'PHID-PCOL-ikeu5quydkkw55cqlb00': {
              'phid': 'PHID-PCOL-ikeu5quydkkw55cqlb00',
              'name': 'Done'
            }
          } })
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42', userName: 'user_with_phid' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 24 } } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when project is unknown', ->
        hubot 'phab new proj2 a task', 'user_with_phid'
        it 'replies that project is unknown', ->
          expect(hubotResponse()).to.eql 'Task T24 created = http://example.com/T24'
          expect(room.robot.brain.data.phabricator.projects['proj2'].phid)
            .to.eql 'PHID-PROJ-qhmexneudkt62wc7o3z4'

    context 'phab new proj2 a task', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = { }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.search')
          .query({
            'names[0]': 'proj2',
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            'data': [ ],
            'slugMap': [ ],
            'cursor': {
              'limit': 100,
              'after': null,
              'before': null
            }
          } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when project is unknown', ->
        hubot 'phab new proj2 a task', 'user_with_phid'
        it 'replies that project is unknown', ->
          expect(hubotResponse()).to.eql 'Sorry, proj2 not found.'


    context 'phab new proj3 a task', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj2': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.search')
          .query({
            'names[0]': 'project1',
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            'data': [ ],
            'slugMap': [ ],
            'cursor': {
              'limit': 100,
              'after': null,
              'before': null
            }
          } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when project is unknown', ->
        hubot 'phab new proj3 a task', 'user_with_phid'
        it 'replies that project is unknown', ->
          expect(hubotResponse()).to.eql 'Sorry, proj3 not found.'

# --------------------------------------------------------------------------------------------------
  context 'user creates a new task with a template, ', ->
    beforeEach ->
      room.robot.brain.data.phabricator.templates = {
        template1: {
          task: '123'
        }
      }

    context 'a task without description, ', ->
      context 'with a known template', ->
        context 'but not found on phabricator', ->
          beforeEach ->
            room.robot.brain.data.phabricator.projects = {
              'proj1': {
                phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
              }
            }
            do nock.disableNetConnect
            nock(process.env.PHABRICATOR_URL)
              .get('/api/maniphest.info')
              .reply(200, { error_info: 'No such Maniphest task exists.' })

          afterEach ->
            room.robot.brain.data.phabricator = { }
            nock.cleanAll()

          context 'when user is known and his phid is in the brain', ->
            hubot 'phab new proj1:template1 a task', 'user_with_phid'
            it 'replies that the template task is not found', ->
              expect(hubotResponse()).to.eql 'No such Maniphest task exists.'

        context 'and found on phabricator', ->
          beforeEach ->
            room.robot.brain.data.phabricator.projects = {
              'proj1': {
                phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
              }
            }
            do nock.disableNetConnect
            nock(process.env.PHABRICATOR_URL)
              .get('/api/maniphest.info')
              .reply(200, { result: { description: 'some templated description' } })
              .get('/api/user.query')
              .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
              .get('/api/maniphest.edit')
              .reply(200, { result: { object: { id: 42 } } })

          afterEach ->
            room.robot.brain.data.phabricator = { }
            nock.cleanAll()

          context 'when user is known and his phid is in the brain', ->
            hubot 'phab new proj1:template1 a task', 'user_with_phid'
            it 'replies with the object id', ->
              expect(hubotResponse()).to.eql 'Task T42 created = http://example.com/T42'

          context 'when user is known and his phid is in the brain', ->
            hubot 'phab new proj1:template1 a task = description', 'user_with_phid'
            it 'replies with the object id', ->
              expect(hubotResponse()).to.eql 'Task T42 created = http://example.com/T42'


      context 'with a template not found', ->
        beforeEach ->
          room.robot.brain.data.phabricator.projects = {
            'proj1': {
              phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
            }
          }
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.info')
            .reply(200, { result: { description: 'some templated description' } })

        afterEach ->
          room.robot.brain.data.phabricator = { }
          nock.cleanAll()

        context 'when user is known and his phid is in the brain', ->
          hubot 'phab new proj1:template2 a task', 'user_with_phid'
          it 'replies that template does not exist', ->
            expect(hubotResponse()).to.eql 'There is no template named \'template2\'.'

    context 'a task with description, ', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: { description: 'some templated description' } })
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab new proj1:template1 a task = with a description', 'user_with_phid'
        it 'replies with the object id', ->
          expect(hubotResponse()).to.eql 'Task T42 created = http://example.com/T42'


    context 'phab new proj1:template1 a task', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: { description: 'some templated description' } })
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { error_info: 'Something went wrong' })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when something goes wrong on phabricator side', ->
        hubot 'phab new proj1:template1 a task', 'user_with_phid'
        it 'informs that something went wrong', ->
          expect(hubotResponse()).to.eql 'Something went wrong'


    context 'phab new proj2:template1 a task', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj2': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: { description: 'some templated description' } })
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 24 } } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab new proj2:template1 a task', 'user_with_phid'
        it 'replies with the object id', ->
          expect(hubotResponse()).to.eql 'Task T24 created = http://example.com/T24'


    context 'implicit re-use of the object id', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj2': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: { description: 'some templated description' } })
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42', userName: 'user_with_phid' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 24 } } })
          .get('/api/maniphest.info')
          .reply(200, { result: {
            title: 'some task',
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-123456789'
            } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab new proj2:template1 a task', 'user_with_phid'
        hubot 'ph', 'user_with_phid'
        it 'replies with the object id', ->
          expect(hubotResponse(1)).to.eql 'Task T24 created = http://example.com/T24'
          expect(hubotResponse(3)).to.eql 'T24 - some task (open, Low, owner user_with_phid)'

    context 'implicit re-use of the object id with no memorization', ->
      beforeEach ->
        process.env.PHABRICATOR_LAST_TASK_LIFETIME = "0"
        room.robot.brain.data.phabricator.projects = {
          'proj2': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: { description: 'some templated description' } })
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42', userName: 'user_with_phid' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 24 } } })
          .get('/api/maniphest.info')
          .reply(200, { result: {
            title: 'some task',
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-123456789'
            } })

      afterEach ->
        delete process.env.PHABRICATOR_LAST_TASK_LIFETIME
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab new proj2:template1 a task', 'user_with_phid'
        hubot 'ph', 'user_with_phid'
        it 'replies with the object id', ->
          expect(hubotResponse(1)).to.eql 'Task T24 created = http://example.com/T24'
          expect(hubotResponse(3)).to.eql 'Sorry, you don\'t have any task active right now.'

    context 'implicit re-use of the object id with no expiration', ->
      beforeEach ->
        process.env.PHABRICATOR_LAST_TASK_LIFETIME = "-"
        room.robot.brain.data.phabricator.projects = {
          'proj2': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: { description: 'some templated description' } })
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42', userName: 'user_with_phid' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 24 } } })
          .get('/api/maniphest.info')
          .reply(200, { result: {
            title: 'some task',
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-123456789'
            } })

      afterEach ->
        delete process.env.PHABRICATOR_LAST_TASK_LIFETIME
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab new proj2:template1 a task', 'user_with_phid'
        hubot 'ph', 'user_with_phid'
        it 'replies with the object id', ->
          expect(hubotResponse(1)).to.eql 'Task T24 created = http://example.com/T24'
          expect(hubotResponse(3)).to.eql 'T24 - some task (open, Low, owner user_with_phid)'


    context 'phab new proj3:template1 a task', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj2': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: { description: 'some templated description' } })
          .get('/api/project.search')
          .query({
            'names[0]': 'project1',
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            'data': [ ],
            'slugMap': [ ],
            'cursor': {
              'limit': 100,
              'after': null,
              'before': null
            }
          } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when project is unknown', ->
        hubot 'phab new proj3:template1 a task', 'user_with_phid'
        it 'replies that project is unknown', ->
          expect(hubotResponse()).to.eql 'Sorry, proj3 not found.'

# --------------------------------------------------------------------------------------------------
  context 'someone creates a new paste', ->
    context 'something goes wrong', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/paste.edit')
          .reply(200, { error_info: 'Something went wrong' })

      afterEach ->
        nock.cleanAll()

      context 'when something goes wrong on phabricator side', ->
        hubot 'ph paste a new paste', 'user_with_phid'
        it 'informs that something went wrong', ->
          expect(hubotResponse()).to.eql 'Something went wrong'

    context 'nothing goes wrong', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/paste.edit')
          .query({
            title: 'a new paste'
            })
          .reply(200, { result: { object: { id: 24 } } })

      afterEach ->
        nock.cleanAll()

      context 'when user is doing it for the first time and has no email recorded', ->
        hubot 'ph paste a new paste'
        it 'invites the user to set his email address', ->
          expect(hubotResponse()).to.eql "Sorry, I can't figure out your email address :( " +
                                         'Can you tell me with `.phab me as <email>`?'
      context 'ph paste a new paste', ->
        hubot 'ph paste a new paste', 'user_with_phid'
        it 'gives the link to fill up the paste Paste', ->
          expect(hubotResponse()).to.eql 'Paste P24 created = ' +
                                         'edit on http://example.com/paste/edit/24'

# --------------------------------------------------------------------------------------------------
  context 'user asks to count tasks in a project or column', ->

    context 'phab count proj1', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'proj1'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.query')
          .reply(200, { result: {
            'PHID-TASK-42': { id: 42 },
            'PHID-TASK-43': { id: 43 },
            'PHID-TASK-44': { id: 44 },
            } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab count proj1', 'user_with_phid'
        it 'replies with the unmber of tasks in the project', ->
          expect(hubotResponse()).to.eql 'proj1 has 3 tasks.'


    context 'phab count proj1', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'proj1'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.query')
          .reply(200, { result: { } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab count proj1', 'user_with_phid'
        it 'replies with the unmber of tasks in the project', ->
          expect(hubotResponse()).to.eql 'proj1 has no tasks.'

    context 'phab count proj3', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj2': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'proj2'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.search')
          .query({
            'names[0]': 'project1',
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            'data': [ ],
            'slugMap': [ ],
            'cursor': {
              'limit': 100,
              'after': null,
              'before': null
            }
          } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when project is unknown', ->
        hubot 'phab count proj3', 'user_with_phid'
        it 'replies that project is unknown', ->
          expect(hubotResponse()).to.eql 'Sorry, proj3 not found.'

# --------------------------------------------------------------------------------------------------
  context 'user changes tags for a task', ->
    context 'when the task is unknown', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { error_info: 'No object exists with ID "424242".' })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 in proj1', ->
        hubot 'ph T424242 in proj1', 'user_with_phid'
        it "warns the user that this Task doesn't exist", ->
          expect(hubotResponse()).to.eql 'No object exists with ID "424242".'

    context 'when the task is known, and already tagged', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            'id': '424242',
            'projectPHIDs': [
              'PHID-PROJ-qhmexneudkt62wc7o3z4'
            ]
          } })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 in proj1', ->
        hubot 'ph T424242 in proj1', 'user_with_phid'
        it 'tells the user that this task is already in this tag', ->
          expect(hubotResponse()).to.eql 'T424242 is already in proj1'

    context 'when the task is known, and not yet tagged', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            'id': '424242',
            'projectPHIDs': [
              'PHID-PROJ-xxx'
            ]
          } })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 424242 } } })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 in proj1', ->
        hubot 'ph T424242 in proj1', 'user_with_phid'
        it 'tells the user that the task is now in the proper tag', ->
          expect(hubotResponse()).to.eql 'Ok, T424242 now has been added to proj1.'

    context 'when the task is known, and already tagged', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            'id': '424242',
            'projectPHIDs': [
              'PHID-PROJ-qhmexneudkt62wc7o3z4'
            ]
          } })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 not in proj1', ->
        hubot 'ph T424242 not in proj1', 'user_with_phid'
        it 'tells user that task has been removed from tag', ->
          expect(hubotResponse()).to.eql 'Ok, T424242 now has been removed from proj1.'

    context 'when the task is known, and not yet tagged', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            'id': '424242',
            'projectPHIDs': [
              'PHID-PROJ-xxx'
            ]
          } })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 not in proj1', ->
        hubot 'ph T424242 not in proj1', 'user_with_phid'
        it 'tells user that that task is actually not in this tag so, whatever', ->
          expect(hubotResponse()).to.eql 'T424242 is already not in proj1'

# --------------------------------------------------------------------------------------------------
  context 'user changes subscribers for a task', ->
    beforeEach ->
      room.robot.brain.data.phabricator.users.toto = {
        name: 'toto',
        id: 'toto',
        phid: 'PHID-USER-123456789'
      }
      afterEach ->
        room.robot.brain.data.phabricator.users = { }

    context 'when the task is unknown', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { error_info: 'No object exists with ID "424242".' })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 sub toto', ->
        hubot 'ph T424242 sub toto', 'user_with_phid'
        it "warns the user that this Task doesn't exist", ->
          expect(hubotResponse()).to.eql 'No object exists with ID "424242".'

    context 'when the task is known, and already subscribed', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            'id': '424242',
            'ccPHIDs': [
              'PHID-USER-123456789'
            ]
            ''
          } })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 sub toto', ->
        hubot 'ph T424242 sub toto', 'user_with_phid'
        it 'tells the user that this task is already subscribed', ->
          expect(hubotResponse()).to.eql 'toto already subscribed to T424242'

    context 'when the task is known, and not yet subscribed', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            'id': '424242',
            'ccPHIDs': [
              'PHID-USER-xxx'
            ]
          } })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 424242 } } })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 sub toto', ->
        hubot 'ph T424242 sub toto', 'user_with_phid'
        it 'tells the user that the task is now in the subscribed', ->
          expect(hubotResponse()).to.eql 'Ok, T424242 now has subscribed toto.'

      context 'phab T424242 sub me', ->
        hubot 'ph T424242 sub me', 'user_with_phid'
        it 'tells the user that the task is now in the subscribed', ->
          expect(hubotResponse()).to.eql 'Ok, T424242 now has subscribed user_with_phid.'

    context 'when the task is known, and already subscribed', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            'id': '424242',
            'ccPHIDs': [
              'PHID-USER-123456789'
            ]
          } })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 unsub toto', ->
        hubot 'ph T424242 unsub toto', 'user_with_phid'
        it 'tells user that task has been unsubscribed', ->
          expect(hubotResponse()).to.eql 'Ok, T424242 now has unsubscribed toto.'

    context 'when the task is known, and not yet subscribed', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            'id': '424242',
            'ccPHIDs': [
              'PHID-USER-xxx'
            ]
          } })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 unsub toto', ->
        hubot 'ph T424242 unsub toto', 'user_with_phid'
        it 'tells user that that task is actually not subscribed so, whatever', ->
          expect(hubotResponse()).to.eql 'toto is not subscribed to T424242'

    context 'when the task is known, and not yet subscribed', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.query')
          .reply(200, { result: [ ] })
          .get('/api/maniphest.info')
          .reply(200, { result: {
            'id': '424242',
            'ccPHIDs': [
              'PHID-USER-xxx'
            ]
          } })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 unsub nobody', ->
        hubot 'ph T424242 unsub nobody', 'user_with_phid'
        it 'tells user that that task is actually not subscribed so, whatever', ->
          expect(hubotResponse())
          .to.eql 'Sorry, I can\'t figure nobody email address. ' +
                  'Can you ask them to `.phab me as <email>`?'

      context 'phab T424242 sub nobody', ->
        hubot 'ph T424242 sub nobody', 'user_with_phid'
        it 'tells user that that task is actually not subscribed so, whatever', ->
          expect(hubotResponse())
          .to.eql 'Sorry, I can\'t figure nobody email address. ' +
                  'Can you ask them to `.phab me as <email>`?'

# --------------------------------------------------------------------------------------------------
  context 'user changes column for a task', ->
    beforeEach ->
      room.robot.brain.data.phabricator.projects = {
        'proj1': {
          name: 'proj1',
          phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
          columns: {
            in_progress: 'PHID-PCOL-123',
            backlog: 'PHID-PCOL-000'
          }
        }
      }

    context 'when task is in unknown project', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            id: '424242',
            projectPHIDs: [
              'PHID-PROJ-qhmexneudkt62wc7o3z4'
            ]
          } })
          .get('/api/project.search')
          .query({
            'names[0]': 'noproject',
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            'data': [ ],
            'slugMap': [ ],
            'cursor': {
              'limit': 100,
              'after': null,
              'before': null
            }
          } })

      context 'phab T424242 to pouet', ->
        hubot 'ph T424242 to pouet', 'user_with_phid'
        it 'warns the user that this task has no tag', ->
          expect(hubotResponse()).to.eql 'T424242 cannot be moved to pouet'

    context 'when task is not in any project yet', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            projectPHIDs: [ ]
          } })

      context 'phab T424242 to pouet', ->
        hubot 'ph T424242 to pouet', 'user_with_phid'
        it 'warns the user that this task has no tag', ->
          expect(hubotResponse()).to.eql 'This item has no tag/project yet.'

    context 'when task is some project', ->
      context 'with an unknown columns', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.info')
            .reply(200, { result: {
              id: '424242',
              projectPHIDs: [
                'PHID-PROJ-qhmexneudkt62wc7o3z4'
              ]
            } })

        context 'phab T424242 to pouet', ->
          hubot 'ph T424242 to pouet', 'user_with_phid'
          it 'warns the user that this column was not found', ->
            expect(hubotResponse()).to.eql 'T424242 cannot be moved to pouet'

      context 'with a column that is unknown', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.info')
            .reply(200, { result: {
              id: '424242',
              projectPHIDs: [
                'PHID-PROJ-qhmexneudkt62wc7o3z4'
              ]
            } })

        context 'phab T424242 to nocolumns', ->
          hubot 'ph T424242 to nocolumns', 'user_with_phid'
          it 'tells the user what the error was', ->
            expect(hubotResponse()).to.eql 'T424242 cannot be moved to nocolumns'

      context 'with a column that is known', ->
        context 'but an error occured', ->
          beforeEach ->
            do nock.disableNetConnect
            nock(process.env.PHABRICATOR_URL)
              .get('/api/maniphest.info')
              .reply(200, { result: {
                id: '424242',
                projectPHIDs: [
                  'PHID-PROJ-qhmexneudkt62wc7o3z4'
                ]
              } })
              .get('/api/maniphest.edit')
              .reply(200, { error_info: 'No object exists with ID "424242".' })

          context 'phab T424242 to backlog', ->
            hubot 'ph T424242 to backlog', 'user_with_phid'
            it 'tells the user what the error was', ->
              expect(hubotResponse()).to.eql 'No object exists with ID "424242".'


        context 'and everything went fine', ->
          beforeEach ->
            do nock.disableNetConnect
            nock(process.env.PHABRICATOR_URL)
              .get('/api/maniphest.info')
              .reply(200, { result: {
                id: '424242',
                projectPHIDs: [
                  'PHID-PROJ-qhmexneudkt62wc7o3z4'
                ]
              } })
              .get('/api/maniphest.edit')
              .reply(200, {
                id: 42
              })

          context 'phab T424242 to backlog', ->
            hubot 'ph T424242 to backlog', 'user_with_phid'
            it 'tells the user that everything went fine', ->
              expect(hubotResponse()).to.eql 'Ok, T424242 now has column changed to backlog.'

        context 'and we specify a comment', ->
          beforeEach ->
            do nock.disableNetConnect
            nock(process.env.PHABRICATOR_URL)
              .get('/api/maniphest.info')
              .reply(200, { result: {
                id: '424242',
                projectPHIDs: [
                  'PHID-PROJ-qhmexneudkt62wc7o3z4'
                ]
              } })
              .get('/api/maniphest.edit')
              .reply(200, {
                id: 42
              })

          context 'phab T424242 to backlog + some comment', ->
            hubot 'ph T424242 to backlog + some comment', 'user_with_phid'
            it 'tells the user that everything went fine', ->
              expect(hubotResponse()).to.eql 'Ok, T424242 now has column changed to backlog.'

# --------------------------------------------------------------------------------------------------
  context 'user changes status for a task', ->
    context 'when the task is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { error_info: 'No such Maniphest task exists.' })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 is open', ->
        hubot 'ph T424242 is open', 'user_with_phid'
        it "warns the user that this Task doesn't exist", ->
          expect(hubotResponse()).to.eql 'No such Maniphest task exists.'

    context 'when the task is present', ->

      context 'phab is open', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-42'
            } })
          .get('/api/maniphest.info')
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-42'
            } })
          .get('/api/user.query')
          .reply(200, { result: [{ userName: 'toto' }] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab is open', ->
          hubot 'phab T42', 'user_with_phid'
          hubot 'ph is open', 'user_with_phid'
          it 'reports the status as open', ->
            expect(hubotResponse(3)).to.eql 'Ok, T42 now has status set to open.'

        context 'phab last is open', ->
          hubot 'phab T42', 'user_with_phid'
          hubot 'ph last is open', 'user_with_phid'
          it 'reports the status as open', ->
            expect(hubotResponse(3)).to.eql 'Ok, T42 now has status set to open.'


      context 'phab T42 is open', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.info')
            .reply(200, { result: {
              status: 'open',
              priority: 'Low',
              name: 'Test task',
              ownerPHID: 'PHID-USER-42'
              } })
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab is open', ->
          hubot 'ph is open', 'user_with_phid'
          it 'warns the user that there is no active task in memory', ->
            expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

        context 'phab last is open', ->
          hubot 'ph last is open', 'user_with_phid'
          it 'warns the user that there is no active task in memory', ->
            expect(hubotResponse()).to.eql "Sorry, you don't have any task active."

        context 'phab T42 is open', ->
          hubot 'ph T42 is open', 'user_with_phid'
          it 'reports the status as open', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status set to open.'

        context 'phab T42 open', ->
          hubot 'ph T42 open', 'user_with_phid'
          it 'reports the status as open', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status set to open.'

      context 'phab T42 is resolved', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.info')
            .reply(200, { result: {
              status: 'open',
              priority: 'Low',
              name: 'Test task',
              ownerPHID: 'PHID-USER-42'
              } })
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 is resolved', ->
          hubot 'ph T42 is resolved', 'user_with_phid'
          it 'reports the status as resolved', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status set to resolved.'

      context 'phab T42 is wontfix', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.info')
            .reply(200, { result: {
              status: 'open',
              priority: 'Low',
              name: 'Test task',
              ownerPHID: 'PHID-USER-42'
              } })
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 is wontfix', ->
          hubot 'ph T42 is wontfix', 'user_with_phid'
          it 'reports the status as wontfix', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status set to wontfix.'

      context 'phab T42 is invalid', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.info')
            .reply(200, { result: {
              status: 'open',
              priority: 'Low',
              name: 'Test task',
              ownerPHID: 'PHID-USER-42'
              } })
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 is invalid', ->
          hubot 'ph T42 is invalid', 'user_with_phid'
          it 'reports the status as invalid', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status set to invalid.'

      context 'phab T42 is spite', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.info')
            .reply(200, { result: {
              status: 'open',
              priority: 'Low',
              name: 'Test task',
              ownerPHID: 'PHID-USER-42'
              } })
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 is spite', ->
          hubot 'ph T42 is spite', 'user_with_phid'
          it 'reports the status as spite', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status set to spite.'

      context 'phab T42 is spite = what a crazy idea', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.info')
            .reply(200, { result: {
              status: 'open',
              priority: 'Low',
              name: 'Test task',
              ownerPHID: 'PHID-USER-42'
              } })
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 is spite = what a crazy idea', ->
          hubot 'ph T42 is spite = what a crazy idea', 'user_with_phid'
          it 'reports the status as spite', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status set to spite.'

# --------------------------------------------------------------------------------------------------
  context 'user changes priority for a task', ->
    context 'when the task is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { error_info: 'No such Maniphest task exists.' })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 is low', ->
        hubot 'ph T424242 is low', 'user_with_phid'
        it "warns the user that this Task doesn't exist", ->
          expect(hubotResponse()).to.eql 'No such Maniphest task exists.'


    context 'when the task is present', ->
  
      context 'phab T42 is broken', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.info')
            .reply(200, { result: {
              status: 'open',
              priority: 'Low',
              name: 'Test task',
              ownerPHID: 'PHID-USER-42'
              } })
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab is broken', ->
          hubot 'ph is broken'
          it 'warns the user that there is no active task in memory', ->
            expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

        context 'phab T42 is broken', ->
          hubot 'ph T42 is broken', 'user_with_phid'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority set to broken.'
        context 'phab T42 is unbreak', ->
          hubot 'ph T42 is unbreak', 'user_with_phid'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority set to unbreak.'

  
      context 'phab T42 is none', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.info')
            .reply(200, { result: {
              status: 'open',
              priority: 'Low',
              name: 'Test task',
              ownerPHID: 'PHID-USER-42'
              } })
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 is none', ->
          hubot 'ph T42 is none', 'user_with_phid'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority set to none.'
        context 'phab T42 is unknown', ->
          hubot 'ph T42 is unknown', 'user_with_phid'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority set to unknown.'

      context 'phab T42 is none = maintainer left', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.info')
            .reply(200, { result: {
              status: 'open',
              priority: 'Low',
              name: 'Test task',
              ownerPHID: 'PHID-USER-42'
              } })
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 is none = maintainer left', ->
          hubot 'ph T42 is none = maintainer left', 'user_with_phid'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority set to none.'

      context 'phab T42 is none + maintainer left', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.info')
            .reply(200, { result: {
              status: 'open',
              priority: 'Low',
              name: 'Test task',
              ownerPHID: 'PHID-USER-42'
              } })
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 is none + maintainer left', ->
          hubot 'ph T42 is none + maintainer left', 'user_with_phid'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority set to none.'

      context 'phab T42 is urgent', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.info')
            .reply(200, { result: {
              status: 'open',
              priority: 'Low',
              name: 'Test task',
              ownerPHID: 'PHID-USER-42'
              } })
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 is urgent', ->
          hubot 'ph T42 is urgent', 'user_with_phid'
          it 'reports the priority to be High', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority set to urgent.'
        context 'phab T42 is high', ->
          hubot 'ph T42 is high', 'user_with_phid'
          it 'reports the priority to be High', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority set to high.'

      context 'phab T42 is normal', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.info')
            .reply(200, { result: {
              status: 'open',
              priority: 'Low',
              name: 'Test task',
              ownerPHID: 'PHID-USER-42'
              } })
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 is normal', ->
          hubot 'ph T42 is normal', 'user_with_phid'
          it 'reports the priority to be Normal', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority set to normal.'

      context 'phab T42 is low', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.info')
            .reply(200, { result: {
              status: 'open',
              priority: 'Low',
              name: 'Test task',
              ownerPHID: 'PHID-USER-42'
              } })
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 is low', ->
          hubot 'ph T42 is low', 'user_with_phid'
          it 'reports the priority to be Low', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority set to low.'

# --------------------------------------------------------------------------------------------------
  context 'user assigns someone to a task', ->
    context 'when the user is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-42'
            } })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 on xxx', ->
        hubot 'ph T424242 on xxx', 'user_with_phid'
        it 'warns the user that xx is unknown', ->
          expect(hubotResponse()).to.eql "Sorry, I can't figure xxx email address." +
                                         ' Can you ask them to `.phab me as <email>`?'
      context 'phab T424242 on momo', ->
        hubot 'ph T424242 on momo'
        it 'warns the user that his email is not known', ->
          expect(hubotResponse()).to.eql "Sorry, I can't figure out your email address :( " +
                                         'Can you tell me with `.phab me as <email>`?'

    context 'task is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-42'
            } })
          .get('/api/maniphest.edit')
          .reply(200, { error_info: 'No such Maniphest task exists.' })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 on user_with_phid', ->
        hubot 'ph T424242 on user_with_phid', 'user_with_phid'
        it 'warns the user that the task does not exist', ->
          expect(hubotResponse()).to.eql 'No such Maniphest task exists.'

    context 'task is known', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-42'
            } })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

      afterEach ->
        nock.cleanAll()

      context 'phab on user_with_phid', ->
        hubot 'ph on user_with_phid', 'user_with_phid'
        it 'warns the user that there is no active task in memory', ->
          expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

      context 'phab T42 on user_with_phid', ->
        hubot 'ph T42 on user_with_phid', 'user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to.eql 'Ok, T42 now has owner set to user_with_phid.'

      context 'phab T42 on user_with_phid', ->
        hubot 'ph T42 on user_with_phid', 'user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to.eql 'Ok, T42 now has owner set to user_with_phid.'

      context 'phab T42 on user_with_phid', ->
        hubot 'ph T42 on user_with_phid', 'user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to.eql 'Ok, T42 now has owner set to user_with_phid.'

      context 'phab T42 for user_with_phid', ->
        hubot 'ph T42 for user_with_phid', 'user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to.eql 'Ok, T42 now has owner set to user_with_phid.'

      context 'phab T42 for me', ->
        hubot 'ph T42 for me', 'user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to.eql 'Ok, T42 now has owner set to user_with_phid.'

# --------------------------------------------------------------------------------------------------
  context 'user issues various commands to a task', ->
    beforeEach ->
      room.robot.brain.data.phabricator.projects = {
        'proj1': {
          name: 'proj1',
          phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
          columns: {
            in_progress: 'PHID-PCOL-123',
            backlog: 'PHID-PCOL-000'
          }
        },
        'proj2': {
          name: 'proj2',
          phid: 'PHID-PROJ-qhmexneudkt62wc7o3z0',
          columns: {
            in_progress: 'PHID-PCOL-456',
            backlog: 'PHID-PCOL-789'
          }
        }
      }
      room.robot.brain.data.phabricator.users.toto = {
        name: 'toto',
        id: 'toto',
        phid: 'PHID-USER-123456789'
      }

    afterEach ->
      room.robot.brain.data.phabricator = { }

    context 'when the user is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-42'
            } })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 is closed on xxx', ->
        hubot 'ph T424242 is closed on xxx', 'user_with_phid'
        it 'warns the user that xx is unknown', ->
          expect(hubotResponse()).to.eql 'Ok, T424242 now has status set to closed.'
          expect(hubotResponse(2)).to.eql "Sorry, I can't figure xxx email address." +
                                         ' Can you ask them to `.phab me as <email>`?'
      context 'phab T424242 is closed on momo', ->
        hubot 'ph T424242 is closed on momo'
        it 'warns the user that his email is not known', ->
          expect(hubotResponse()).to.eql 'Ok, T424242 now has status set to closed.'
          expect(hubotResponse(2)).to.eql "Sorry, I can't figure out your email address :( " +
                                         'Can you tell me with `.phab me as <email>`?'

    context 'task is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { error_info: 'No such Maniphest task exists.' })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 is low to what', ->
        hubot 'ph T424242 is low to what', 'user_with_phid'
        it 'warns the user that the task does not exist', ->
          expect(hubotResponse()).to.eql 'No such Maniphest task exists.'

    context 'task is known', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            id: '42',
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-42',
            projectPHIDs: [
              'PHID-PROJ-qhmexneudkt62wc7o3z4'
            ],
            ccPHIDs: [
              'PHID-USER-qhmexneudkt62wc7o3z4'
            ]
          } })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

      afterEach ->
        nock.cleanAll()

      context 'phab is open on user_with_phid', ->
        hubot 'ph is open on user_with_phid', 'user_with_phid'
        it 'warns the user that there is no active task in memory', ->
          expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

      context 'phab T42 in proj2 not in proj1 on user_with_phid', ->
        hubot 'ph T42 in proj2 not in proj1 on user_with_phid', 'user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to
          .eql 'Ok, T42 now has been added to proj2, been removed from proj1, ' +
               'owner set to user_with_phid.'

      context 'phab T42 to backlog is open', ->
        hubot 'ph T42 to backlog is open', 'user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to
          .eql 'Ok, T42 now has column changed to backlog, status set to open.'

      context 'phab T42 on user_with_phid to backlog is open', ->
        hubot 'ph T42 on user_with_phid to backlog is open', 'user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to
          .eql 'Ok, T42 now has owner set to user_with_phid, column changed to backlog, ' +
               'status set to open.'

      context 'phab T42 on user_with_phid to backlog is open sub toto', ->
        hubot 'ph T42 on user_with_phid to backlog is open sub toto', 'user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to
          .eql 'Ok, T42 now has owner set to user_with_phid, column changed to backlog, ' +
               'status set to open, subscribed toto.'

      context 'phab T42 for user_with_phid to backlog is open sub toto', ->
        hubot 'ph T42 for user_with_phid to backlog is open sub toto', 'user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to
          .eql 'Ok, T42 now has owner set to user_with_phid, column changed to backlog, ' +
               'status set to open, subscribed toto.'

      context 'phab T42 sub user_with_phid to backlog is closed unsub toto', ->
        hubot 'ph T42 sub user_with_phid to backlog is closed unsub toto', 'user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to
          .eql 'Ok, T42 now has subscribed user_with_phid, column changed to backlog, ' +
               'status set to closed.'

      context 'phab T42 sub user_with_phid unsub toto to backlog is closed', ->
        hubot 'ph T42 sub user_with_phid unsub toto to backlog is closed', 'user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to
          .eql 'Ok, T42 now has subscribed user_with_phid, ' +
               'column changed to backlog, status set to closed.'
          expect(hubotResponse(2)).to
          .eql 'toto is not subscribed to T42'

      context 'phab T42 sub user_with_phid unsub toto to backlog in noproject', ->
        beforeEach ->
          nock(process.env.PHABRICATOR_URL)
            .get('/api/project.search')
            .query({
              'names[0]': 'noproject',
              'api.token': 'xxx'
            })
            .reply(200, { result: {
              'data': [ ],
              'slugMap': [ ],
              'cursor': {
                'limit': 100,
                'after': null,
                'before': null
              }
            } })

        hubot 'ph T42 sub user_with_phid unsub toto to backlog in noproject', 'user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to
          .eql 'Ok, T42 now has subscribed user_with_phid, ' +
               'column changed to backlog.'
          expect(hubotResponse(2)).to
          .eql 'toto is not subscribed to T42'
          expect(hubotResponse(3)).to
          .eql 'Sorry, noproject not found.'

      context 'phab T42 sub user_with_phid unsub toto to backlog not in noproject', ->
        beforeEach ->
          nock(process.env.PHABRICATOR_URL)
            .get('/api/project.search')
            .query({
              'names[0]': 'noproject',
              'api.token': 'xxx'
            })
            .reply(200, { result: {
              'data': [ ],
              'slugMap': [ ],
              'cursor': {
                'limit': 100,
                'after': null,
                'before': null
              }
            } })

        hubot 'ph T42 sub user_with_phid unsub toto to backlog not in noproject', 'user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to
          .eql 'Ok, T42 now has subscribed user_with_phid, ' +
               'column changed to backlog.'
          expect(hubotResponse(2)).to
          .eql 'toto is not subscribed to T42'
          expect(hubotResponse(3)).to
          .eql 'Sorry, noproject not found.'

# --------------------------------------------------------------------------------------------------
  context 'user adds a comment on a task', ->

    context 'task is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.edit')
          .reply(200, { error_info: 'No such Maniphest task exists.' })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 + some comment', ->
        hubot 'phab T424242 + some comment', 'user_with_phid'
        it 'warns the user that the task does not exist', ->
          expect(hubotResponse()).to.eql 'No such Maniphest task exists.'

    context 'task is known', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.edit')
          .reply(200, { result: { id: 42 } })

      afterEach ->
        nock.cleanAll()

      context 'phab + some comment', ->
        hubot 'phab + some comment', 'user_with_phid'
        it 'warns the user that there is no active task in memory', ->
          expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

      context 'phab T24 + some comment', ->
        hubot 'phab T24 + some comment', 'user_with_phid'
        it 'gives a feedback that the comment was added', ->
          expect(hubotResponse()).to.eql 'Ok. Added comment "some comment" to T24.'

# --------------------------------------------------------------------------------------------------
  context 'user request info about a phid', ->

    context 'when there is an error on a phid', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.query')
          .reply(404, { })

      context 'phid PHID-PROJ-qhmexneudkt62wc7o3z4', ->
        hubot 'phid PHID-PROJ-qhmexneudkt62wc7o3z4'
        it 'states that an error happened', ->
          expect(hubotResponse()).to.eql 'http error 404'

    context 'when there is an error on a item', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(404, { })

      context 'phid T42', ->
        hubot 'phid T42'
        it 'states that an error happened', ->
          expect(hubotResponse()).to.eql 'http error 404'

    context 'when there is no matching phid', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.query')
          .reply(200, { result: { } })

      context 'phid PHID-PROJ-qhmexneudkt62wc7o3z4', ->
        hubot 'phid PHID-PROJ-qhmexneudkt62wc7o3z4'
        it 'warns the user that this phid was not found', ->
          expect(hubotResponse()).to.eql 'PHID not found.'

    context 'when there is no matching item', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: { } })

      context 'phid T42', ->
        hubot 'phid T42'
        it 'warns the user that this item was not found', ->
          expect(hubotResponse()).to.eql 'T42 not found.'


    context 'when the phid exists', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.query')
          .reply(200, { result: {
            'PHID-PROJ-qhmexneudkt62wc7o3z4': {
              'uri': 'http://example.com/p/something',
              'name': 'something',
              'status': 'closed'
            }
          } })

      context 'phid PHID-PROJ-qhmexneudkt62wc7o3z4', ->
        hubot 'phid PHID-PROJ-qhmexneudkt62wc7o3z4'
        it 'gives back information about the object', ->
          expect(hubotResponse()).to.eql 'PHID-PROJ-qhmexneudkt62wc7o3z4 is something - ' +
                                         'http://example.com/p/something (closed)'

    context 'when the item exists', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: {
            'T42': {
              'phid': 'PHID-TASK-aofqt76nikbssugfkwhi',
              'uri': 'http://example.com/T42',
              'name': 'T42',
              'status': 'closed'
            }
          } })

      context 'phid T42', ->
        hubot 'phid T42'
        it 'gives back information about the object', ->
          expect(hubotResponse()).to.eql 'T42 is PHID-TASK-aofqt76nikbssugfkwhi'

# --------------------------------------------------------------------------------------------------
  context 'user searches through projects tasks, whatever the status', ->

    context 'there is 2 results', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj3': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'proj3'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.search')
          .reply(200, { result: {
            'data': [
              {
                'id': 2490,
                'type': 'TASK',
                'phid': 'PHID-TASK-p5tbi3vbcffx3mpbxhwr',
                'fields': {
                  'name': 'Task 1',
                  'authorPHID': 'PHID-USER-7p4d4k6v4csqx7gcxcbw',
                  'ownerPHID': null,
                  'status': {
                    'value': 'resolved',
                    'name': 'Resolved',
                    'color': null
                  },
                  'priority': {
                    'value': 90,
                    'subpriority': 0,
                    'name': 'Needs Triage',
                    'color': 'violet'
                  },
                  'points': null,
                  'spacePHID': null,
                  'dateCreated': 1468339539,
                  'dateModified': 1469535704,
                  'policy': {
                    'view': 'users',
                    'edit': 'users'
                  }
                },
                'attachments': { }
              },
              {
                'id': 2080,
                'type': 'TASK',
                'phid': 'PHID-TASK-ext-55d324653c69b5351ff64d0a',
                'fields': {
                  'name': 'Task 2',
                  'authorPHID': 'PHID-USER-hqnae6h2h7fyhln3kqkd',
                  'ownerPHID': null,
                  'status': {
                    'value': 'open',
                    'name': 'Open',
                    'color': null
                  },
                  'priority': {
                    'value': 90,
                    'subpriority': 0,
                    'name': 'Needs Triage',
                    'color': 'violet'
                  },
                  'points': null,
                  'spacePHID': null,
                  'dateCreated': 1439900773,
                  'dateModified': 1467045532,
                  'policy': {
                    'view': 'users',
                    'edit': 'users'
                  }
                },
                'attachments': { }
              }
            ],
            'maps': { },
            'query': {
              'queryKey': 'rwQ6luYqjZF0'
            },
            'cursor': {
              'limit': 3,
              'after': null,
              'before': null,
              'order': 'newest'
            }
          } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phab all proj3 gitlab', ->
        hubot 'phab all proj3 gitlab'
        it 'gives a list of results', ->
          expect(hubotResponse())
            .to.eql 'http://example.com/T2490 - Task 1 (Resolved)'
          expect(hubotResponse(2))
            .to.eql 'http://example.com/T2080 - Task 2 (Open)'
          expect(hubotResponseCount()).to.eql 2

    context 'there is more than 3 results', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj3': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'proj3'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.search')
          .reply(200, { result: {
            'data': [
              {
                'id': 2490,
                'type': 'TASK',
                'phid': 'PHID-TASK-p5tbi3vbcffx3mpbxhwr',
                'fields': {
                  'name': 'Task 1',
                  'authorPHID': 'PHID-USER-7p4d4k6v4csqx7gcxcbw',
                  'ownerPHID': null,
                  'status': {
                    'value': 'open',
                    'name': 'Open',
                    'color': null
                  },
                  'priority': {
                    'value': 90,
                    'subpriority': 0,
                    'name': 'Needs Triage',
                    'color': 'violet'
                  },
                  'points': null,
                  'spacePHID': null,
                  'dateCreated': 1468339539,
                  'dateModified': 1469535704,
                  'policy': {
                    'view': 'users',
                    'edit': 'users'
                  }
                },
                'attachments': { }
              },
              {
                'id': 2080,
                'type': 'TASK',
                'phid': 'PHID-TASK-ext-55d324653c69b5351ff64d0a',
                'fields': {
                  'name': 'Task 2',
                  'authorPHID': 'PHID-USER-hqnae6h2h7fyhln3kqkd',
                  'ownerPHID': null,
                  'status': {
                    'value': 'open',
                    'name': 'Open',
                    'color': null
                  },
                  'priority': {
                    'value': 90,
                    'subpriority': 0,
                    'name': 'Needs Triage',
                    'color': 'violet'
                  },
                  'points': null,
                  'spacePHID': null,
                  'dateCreated': 1439900773,
                  'dateModified': 1467045532,
                  'policy': {
                    'view': 'users',
                    'edit': 'users'
                  }
                },
                'attachments': { }
              },
              {
                'id': 2078,
                'type': 'TASK',
                'phid': 'PHID-TASK-ext-55e53abba4d0c58648fdfab6',
                'fields': {
                  'name': 'Task 3',
                  'authorPHID': 'PHID-USER-syykf4ieymsc73z6tie7',
                  'ownerPHID': null,
                  'status': {
                    'value': 'open',
                    'name': 'Open',
                    'color': null
                  },
                  'priority': {
                    'value': 90,
                    'subpriority': 0,
                    'name': 'Needs Triage',
                    'color': 'violet'
                  },
                  'points': null,
                  'spacePHID': null,
                  'dateCreated': 1441086139,
                  'dateModified': 1468252093,
                  'policy': {
                    'view': 'users',
                    'edit': 'users'
                  }
                },
                'attachments': { }
              }
            ],
            'maps': { },
            'query': {
              'queryKey': 'rwQ6luYqjZF0'
            },
            'cursor': {
              'limit': 3,
              'after': '2078',
              'before': null,
              'order': 'newest'
            }
          } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phab all proj3 gitlab', ->
        hubot 'phab all proj3 gitlab'
        it 'gives a list of results', ->
          expect(hubotResponse())
            .to.eql 'http://example.com/T2490 - Task 1 (Open)'
          expect(hubotResponse(2))
            .to.eql 'http://example.com/T2080 - Task 2 (Open)'
          expect(hubotResponse(3))
            .to.eql 'http://example.com/T2078 - Task 3 (Open)'
          expect(hubotResponse(4))
            .to.eql '... and there is more.'
          expect(hubotResponseCount()).to.eql 4


    context 'there is no results', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj3': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'proj3'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.search')
          .reply(200, { result: {
            'data': [ ],
            'maps': { },
            'query': {
              'queryKey': 'rwQ6luYqjZF0'
            },
            'cursor': {
              'limit': 3,
              'after': null,
              'before': null,
              'order': 'newest'
            }
          } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phab all proj3 gitlab', ->
        hubot 'phab all proj3 gitlab'
        it 'gives a message that there is no result', ->
          expect(hubotResponse()).to.eql "There is no task matching 'gitlab' in project 'proj3'."
          expect(hubotResponseCount()).to.eql 1

    context 'phab count proj4', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj2': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'proj2'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.search')
          .query({
            'names[0]': 'project1',
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            'data': [ ],
            'slugMap': [ ],
            'cursor': {
              'limit': 100,
              'after': null,
              'before': null
            }
          } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when project is unknown', ->
        hubot 'phab all proj4 gitlab', 'user_with_phid'
        it 'replies that project is unknown', ->
          expect(hubotResponse()).to.eql 'Sorry, proj4 not found.'


# --------------------------------------------------------------------------------------------------
  context 'user searches through all tasks', ->

    context 'there is 2 results', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.search')
          .reply(200, { result: {
            'data': [
              {
                'id': 2490,
                'type': 'TASK',
                'phid': 'PHID-TASK-p5tbi3vbcffx3mpbxhwr',
                'fields': {
                  'name': 'Task 1',
                  'authorPHID': 'PHID-USER-7p4d4k6v4csqx7gcxcbw',
                  'ownerPHID': null,
                  'status': {
                    'value': 'open',
                    'name': 'Open',
                    'color': null
                  },
                  'priority': {
                    'value': 90,
                    'subpriority': 0,
                    'name': 'Needs Triage',
                    'color': 'violet'
                  },
                  'points': null,
                  'spacePHID': null,
                  'dateCreated': 1468339539,
                  'dateModified': 1469535704,
                  'policy': {
                    'view': 'users',
                    'edit': 'users'
                  }
                },
                'attachments': { }
              },
              {
                'id': 2080,
                'type': 'TASK',
                'phid': 'PHID-TASK-ext-55d324653c69b5351ff64d0a',
                'fields': {
                  'name': 'Task 2',
                  'authorPHID': 'PHID-USER-hqnae6h2h7fyhln3kqkd',
                  'ownerPHID': null,
                  'status': {
                    'value': 'open',
                    'name': 'Open',
                    'color': null
                  },
                  'priority': {
                    'value': 90,
                    'subpriority': 0,
                    'name': 'Needs Triage',
                    'color': 'violet'
                  },
                  'points': null,
                  'spacePHID': null,
                  'dateCreated': 1439900773,
                  'dateModified': 1467045532,
                  'policy': {
                    'view': 'users',
                    'edit': 'users'
                  }
                },
                'attachments': { }
              }
            ],
            'maps': { },
            'query': {
              'queryKey': 'rwQ6luYqjZF0'
            },
            'cursor': {
              'limit': 3,
              'after': null,
              'before': null,
              'order': 'newest'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'phab search gitlab', ->
        hubot 'phab search gitlab'
        it 'gives a list of results', ->
          expect(hubotResponse())
            .to.eql 'http://example.com/T2490 - Task 1 (Open)'
          expect(hubotResponse(2))
            .to.eql 'http://example.com/T2080 - Task 2 (Open)'
          expect(hubotResponseCount()).to.eql 2

    context 'there is more than 3 results', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.search')
          .reply(200, { result: {
            'data': [
              {
                'id': 2490,
                'type': 'TASK',
                'phid': 'PHID-TASK-p5tbi3vbcffx3mpbxhwr',
                'fields': {
                  'name': 'Task 1',
                  'authorPHID': 'PHID-USER-7p4d4k6v4csqx7gcxcbw',
                  'ownerPHID': null,
                  'status': {
                    'value': 'open',
                    'name': 'Open',
                    'color': null
                  },
                  'priority': {
                    'value': 90,
                    'subpriority': 0,
                    'name': 'Needs Triage',
                    'color': 'violet'
                  },
                  'points': null,
                  'spacePHID': null,
                  'dateCreated': 1468339539,
                  'dateModified': 1469535704,
                  'policy': {
                    'view': 'users',
                    'edit': 'users'
                  }
                },
                'attachments': { }
              },
              {
                'id': 2080,
                'type': 'TASK',
                'phid': 'PHID-TASK-ext-55d324653c69b5351ff64d0a',
                'fields': {
                  'name': 'Task 2',
                  'authorPHID': 'PHID-USER-hqnae6h2h7fyhln3kqkd',
                  'ownerPHID': null,
                  'status': {
                    'value': 'open',
                    'name': 'Open',
                    'color': null
                  },
                  'priority': {
                    'value': 90,
                    'subpriority': 0,
                    'name': 'Needs Triage',
                    'color': 'violet'
                  },
                  'points': null,
                  'spacePHID': null,
                  'dateCreated': 1439900773,
                  'dateModified': 1467045532,
                  'policy': {
                    'view': 'users',
                    'edit': 'users'
                  }
                },
                'attachments': { }
              },
              {
                'id': 2078,
                'type': 'TASK',
                'phid': 'PHID-TASK-ext-55e53abba4d0c58648fdfab6',
                'fields': {
                  'name': 'Task 3',
                  'authorPHID': 'PHID-USER-syykf4ieymsc73z6tie7',
                  'ownerPHID': null,
                  'status': {
                    'value': 'open',
                    'name': 'Open',
                    'color': null
                  },
                  'priority': {
                    'value': 90,
                    'subpriority': 0,
                    'name': 'Needs Triage',
                    'color': 'violet'
                  },
                  'points': null,
                  'spacePHID': null,
                  'dateCreated': 1441086139,
                  'dateModified': 1468252093,
                  'policy': {
                    'view': 'users',
                    'edit': 'users'
                  }
                },
                'attachments': { }
              }
            ],
            'maps': { },
            'query': {
              'queryKey': 'rwQ6luYqjZF0'
            },
            'cursor': {
              'limit': 3,
              'after': '2078',
              'before': null,
              'order': 'newest'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'phab search gitlab', ->
        hubot 'phab search gitlab'
        it 'gives a list of results', ->
          expect(hubotResponse())
            .to.eql 'http://example.com/T2490 - Task 1 (Open)'
          expect(hubotResponse(2))
            .to.eql 'http://example.com/T2080 - Task 2 (Open)'
          expect(hubotResponse(3))
            .to.eql 'http://example.com/T2078 - Task 3 (Open)'
          expect(hubotResponse(4))
            .to.eql '... and there is more.'
          expect(hubotResponseCount()).to.eql 4


      context 'phab search all gitlab', ->
        hubot 'phab search all gitlab'
        it 'gives a list of results', ->
          expect(hubotResponse())
            .to.eql 'http://example.com/T2490 - Task 1 (Open)'
          expect(hubotResponse(2))
            .to.eql 'http://example.com/T2080 - Task 2 (Open)'
          expect(hubotResponse(3))
            .to.eql 'http://example.com/T2078 - Task 3 (Open)'
          expect(hubotResponse(4))
            .to.eql '... and there is more.'
          expect(hubotResponseCount()).to.eql 4


    context 'there is no results', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.search')
          .reply(200, { result: {
            'data': [ ],
            'maps': { },
            'query': {
              'queryKey': 'rwQ6luYqjZF0'
            },
            'cursor': {
              'limit': 3,
              'after': null,
              'before': null,
              'order': 'newest'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'phab search gitlab', ->
        hubot 'phab search gitlab'
        it 'gives a message that there is no result', ->
          expect(hubotResponse()).to.eql "There is no task matching 'gitlab'."
          expect(hubotResponseCount()).to.eql 1

    context 'there is an error', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.search')
          .reply(500, { result: { message: 'oops' } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phab search gitlab', ->
        hubot 'phab search gitlab'
        it 'gives a message that there is an error', ->
          expect(hubotResponse()).to.eql 'http error 500'
          expect(hubotResponseCount()).to.eql 1

# --------------------------------------------------------------------------------------------------
  context 'user searches through project tasks', ->

    context 'there is 2 results', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj3': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'proj3'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.search')
          .reply(200, { result: {
            'data': [
              {
                'id': 2490,
                'type': 'TASK',
                'phid': 'PHID-TASK-p5tbi3vbcffx3mpbxhwr',
                'fields': {
                  'name': 'Task 1',
                  'authorPHID': 'PHID-USER-7p4d4k6v4csqx7gcxcbw',
                  'ownerPHID': null,
                  'status': {
                    'value': 'open',
                    'name': 'Open',
                    'color': null
                  },
                  'priority': {
                    'value': 90,
                    'subpriority': 0,
                    'name': 'Needs Triage',
                    'color': 'violet'
                  },
                  'points': null,
                  'spacePHID': null,
                  'dateCreated': 1468339539,
                  'dateModified': 1469535704,
                  'policy': {
                    'view': 'users',
                    'edit': 'users'
                  }
                },
                'attachments': { }
              },
              {
                'id': 2080,
                'type': 'TASK',
                'phid': 'PHID-TASK-ext-55d324653c69b5351ff64d0a',
                'fields': {
                  'name': 'Task 2',
                  'authorPHID': 'PHID-USER-hqnae6h2h7fyhln3kqkd',
                  'ownerPHID': null,
                  'status': {
                    'value': 'open',
                    'name': 'Open',
                    'color': null
                  },
                  'priority': {
                    'value': 90,
                    'subpriority': 0,
                    'name': 'Needs Triage',
                    'color': 'violet'
                  },
                  'points': null,
                  'spacePHID': null,
                  'dateCreated': 1439900773,
                  'dateModified': 1467045532,
                  'policy': {
                    'view': 'users',
                    'edit': 'users'
                  }
                },
                'attachments': { }
              }
            ],
            'maps': { },
            'query': {
              'queryKey': 'rwQ6luYqjZF0'
            },
            'cursor': {
              'limit': 3,
              'after': null,
              'before': null,
              'order': 'newest'
            }
          } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phab proj3 gitlab', ->
        hubot 'phab proj3 gitlab'
        it 'gives a list of results', ->
          expect(hubotResponse())
            .to.eql 'http://example.com/T2490 - Task 1 (Open)'
          expect(hubotResponse(2))
            .to.eql 'http://example.com/T2080 - Task 2 (Open)'
          expect(hubotResponseCount()).to.eql 2

    context 'there is more than 3 results', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj3': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'proj3'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.search')
          .reply(200, { result: {
            'data': [
              {
                'id': 2490,
                'type': 'TASK',
                'phid': 'PHID-TASK-p5tbi3vbcffx3mpbxhwr',
                'fields': {
                  'name': 'Task 1',
                  'authorPHID': 'PHID-USER-7p4d4k6v4csqx7gcxcbw',
                  'ownerPHID': null,
                  'status': {
                    'value': 'open',
                    'name': 'Open',
                    'color': null
                  },
                  'priority': {
                    'value': 90,
                    'subpriority': 0,
                    'name': 'Needs Triage',
                    'color': 'violet'
                  },
                  'points': null,
                  'spacePHID': null,
                  'dateCreated': 1468339539,
                  'dateModified': 1469535704,
                  'policy': {
                    'view': 'users',
                    'edit': 'users'
                  }
                },
                'attachments': { }
              },
              {
                'id': 2080,
                'type': 'TASK',
                'phid': 'PHID-TASK-ext-55d324653c69b5351ff64d0a',
                'fields': {
                  'name': 'Task 2',
                  'authorPHID': 'PHID-USER-hqnae6h2h7fyhln3kqkd',
                  'ownerPHID': null,
                  'status': {
                    'value': 'open',
                    'name': 'Open',
                    'color': null
                  },
                  'priority': {
                    'value': 90,
                    'subpriority': 0,
                    'name': 'Needs Triage',
                    'color': 'violet'
                  },
                  'points': null,
                  'spacePHID': null,
                  'dateCreated': 1439900773,
                  'dateModified': 1467045532,
                  'policy': {
                    'view': 'users',
                    'edit': 'users'
                  }
                },
                'attachments': { }
              },
              {
                'id': 2078,
                'type': 'TASK',
                'phid': 'PHID-TASK-ext-55e53abba4d0c58648fdfab6',
                'fields': {
                  'name': 'Task 3',
                  'authorPHID': 'PHID-USER-syykf4ieymsc73z6tie7',
                  'ownerPHID': null,
                  'status': {
                    'value': 'open',
                    'name': 'Open',
                    'color': null
                  },
                  'priority': {
                    'value': 90,
                    'subpriority': 0,
                    'name': 'Needs Triage',
                    'color': 'violet'
                  },
                  'points': null,
                  'spacePHID': null,
                  'dateCreated': 1441086139,
                  'dateModified': 1468252093,
                  'policy': {
                    'view': 'users',
                    'edit': 'users'
                  }
                },
                'attachments': { }
              }
            ],
            'maps': { },
            'query': {
              'queryKey': 'rwQ6luYqjZF0'
            },
            'cursor': {
              'limit': 3,
              'after': '2078',
              'before': null,
              'order': 'newest'
            }
          } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phab proj3 gitlab', ->
        hubot 'phab proj3 gitlab'
        it 'gives a list of results', ->
          expect(hubotResponse())
            .to.eql 'http://example.com/T2490 - Task 1 (Open)'
          expect(hubotResponse(2))
            .to.eql 'http://example.com/T2080 - Task 2 (Open)'
          expect(hubotResponse(3))
            .to.eql 'http://example.com/T2078 - Task 3 (Open)'
          expect(hubotResponse(4))
            .to.eql '... and there is more.'
          expect(hubotResponseCount()).to.eql 4


    context 'there is no results', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj3': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'proj3'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.search')
          .reply(200, { result: {
            'data': [ ],
            'maps': { },
            'query': {
              'queryKey': 'rwQ6luYqjZF0'
            },
            'cursor': {
              'limit': 3,
              'after': null,
              'before': null,
              'order': 'newest'
            }
          } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phab proj3 gitlab', ->
        hubot 'phab proj3 gitlab'
        it 'gives a message that there is no result', ->
          expect(hubotResponse()).to.eql "There is no task matching 'gitlab' in project 'proj3'."
          expect(hubotResponseCount()).to.eql 1

    context 'there is an error', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj3': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'proj3'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.search')
          .reply(500, { result: { message: 'oops' } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phab proj3 gitlab', ->
        hubot 'phab proj3 gitlab'
        it 'gives a message that there is an error', ->
          expect(hubotResponse()).to.eql 'http error 500'
          expect(hubotResponseCount()).to.eql 1

# --------------------------------------------------------------------------------------------------
  context 'error: non json', ->
    beforeEach ->
      do nock.disableNetConnect
      nock(process.env.PHABRICATOR_URL)
        .get('/api/maniphest.info')
        .reply(200, { result: {
          status: 'open',
          priority: 'Low',
          name: 'Test task',
          ownerPHID: 'PHID-USER-42'
          } })
        .get('/api/maniphest.edit')
        .reply(200, '<body></body>', { 'Content-type': 'text/html' })

    afterEach ->
      nock.cleanAll()

    context 'phab T42 is spite', ->
      hubot 'ph T42 is spite', 'user_with_phid'
      it 'reports an api error', ->
        expect(hubotResponse()).to.eql 'api did not deliver json'

  context 'error: lib error', ->
    beforeEach ->
      do nock.disableNetConnect
      nock(process.env.PHABRICATOR_URL)
        .get('/api/maniphest.info')
        .reply(200, { result: {
          status: 'open',
          priority: 'Low',
          name: 'Test task',
          ownerPHID: 'PHID-USER-42'
          } })
        .get('/api/maniphest.edit')
        .replyWithError({ 'message': 'something awful happened', 'code': 'AWFUL_ERROR' })

    afterEach ->
      nock.cleanAll()

    context 'phab T42 is spite', ->
      hubot 'ph T42 is spite', 'user_with_phid'
      it 'reports a lib error', ->
        expect(hubotResponse()).to.eql 'AWFUL_ERROR something awful happened'

  context 'error: lib error', ->
    beforeEach ->
      do nock.disableNetConnect
      nock(process.env.PHABRICATOR_URL)
        .get('/api/maniphest.info')
        .reply(200, { result: {
          status: 'open',
          priority: 'Low',
          name: 'Test task',
          ownerPHID: 'PHID-USER-42'
          } })
        .get('/api/maniphest.edit')
        .reply(400)

    afterEach ->
      nock.cleanAll()

    context 'phab T42 is spite', ->
      hubot 'ph T42 is spite', 'user_with_phid'
      it 'reports a http error', ->
        expect(hubotResponse()).to.eql 'http error 400'

# --------------------------------------------------------------------------------------------------
  context 'permissions system', ->
    beforeEach ->
      process.env.HUBOT_AUTH_ADMIN = 'admin_user'
      room.robot.brain.data.phabricator = { users: { } }
      room.robot.loadFile path.resolve('node_modules/hubot-auth/src'), 'auth.coffee'
      room.robot.brain.userForId 'admin_user', {
        id: 'admin_user',
        name: 'admin_user',
        phid: 'PHID-USER-123456789'
      }
      room.robot.brain.data.phabricator.users.admin_user = {
        name: 'admin_user',
        id: 'admin_user',
        phid: 'PHID-USER-123456789'
      }
      room.robot.brain.userForId 'phadmin_user', {
        id: 'phadmin_user',
        name: 'phadmin_user',
        phid: 'PHID-USER-123456789',
        roles: [
          'phadmin'
        ]
      }
      room.robot.brain.data.phabricator.users.phadmin_user = {
        name: 'phadmin_user',
        id: 'phadmin_user',
        phid: 'PHID-USER-123456789'
      }
      room.robot.brain.userForId 'phuser_user', {
        id: 'phuser_user',
        name: 'phuser_user',
        phid: 'PHID-USER-123456789',
        roles: [
          'phuser'
        ]
      }
      room.robot.brain.data.phabricator.users.phuser_user = {
        name: 'phuser_user',
        id: 'phuser_user',
        phid: 'PHID-USER-123456789'
      }

    context 'user wants to create comment on a task', ->
      beforeEach ->
        room.receive = (userName, message) ->
          new Promise (resolve) =>
            @messages.push [userName, message]
            user = @robot.brain.userForName(userName)
            @robot.receive(new Hubot.TextMessage(user, message), resolve)

        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.edit')
          .reply(200, { result: { id: 42 } })

      afterEach ->
        nock.cleanAll()

      context 'and user is admin', ->
        hubot 'phab T24 + some comment', 'admin_user'
        it 'gives a feedback that the comment was added', ->
          expect(hubotResponse()).to.eql 'Ok. Added comment "some comment" to T24.'

      context 'and user is phuser', ->
        hubot 'phab T24 + some comment', 'phuser_user'
        it 'gives a feedback that the comment was added', ->
          expect(hubotResponse()).to.eql 'Ok. Added comment "some comment" to T24.'

      context 'and user is not in phabs groups', ->
        hubot 'phab bl V2', 'user_with_phid'
        it 'warns the user that he has no permission to use that command', ->
          expect(hubotResponse()).to.eql 'You don\'t have permission to do that.'

      context 'and user is not in phabs groups', ->
        hubot 'phab unbl V2', 'user_with_phid'
        it 'warns the user that he has no permission to use that command', ->
          expect(hubotResponse()).to.eql 'You don\'t have permission to do that.'

      context 'and user is not in phabs groups', ->
        hubot 'phab me as mo@example.com', 'user_with_phid'
        it 'warns the user that he has no permission to use that command', ->
          expect(hubotResponse()).to.eql 'You don\'t have permission to do that.'

      context 'and user is not in phabs groups', ->
        hubot 'phab user momo = mo@example.com', 'user_with_phid'
        it 'warns the user that he has no permission to use that command', ->
          expect(hubotResponse()).to.eql 'You don\'t have permission to do that.'

      context 'and user is not in phabs groups, but users are trusted', ->
        beforeEach ->
          process.env.PHABRICATOR_TRUSTED_USERS = 'y'
        hubot 'phab T24 + some comment', 'user_with_phid'
        it 'warns the user that he has no permission to use that command', ->
          expect(hubotResponse()).to.eql 'Ok. Added comment "some comment" to T24.'

# --------------------------------------------------------------------------------------------------
