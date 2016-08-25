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

# ---------------------------------------------------------------------------------
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
    room.robot.brain.userForId 'user_with_phid', {
      name: 'user_with_phid',
      phid: 'PHID-USER-123456789'
    }
    room.receive = (userName, message) ->
      new Promise (resolve) =>
        @messages.push [userName, message]
        user = room.robot.brain.userForId userName
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
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
          .get('/api/user.whoami')
          .reply(200, { result: [ { phid: 'PHID-USER-123456789' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab new proj1 a task', 'user_with_phid'
        it 'replies with the object id', ->
          expect(hubotResponse()).to.eql 'Task T42 created = http://example.com/T42'

# ---------------------------------------------------------------------------------
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
    room.receive = (userName, message) ->
      new Promise (resolve) =>
        @messages.push [userName, message]
        user = room.robot.brain.userForId userName
        @robot.receive(new Hubot.TextMessage(user, message), resolve)

  afterEach ->
    delete process.env.PHABRICATOR_URL
    delete process.env.PHABRICATOR_API_KEY
    delete process.env.PHABRICATOR_BOT_PHID

  # ---------------------------------------------------------------------------------
  context 'user wants to know hubot-phabs version', ->

    context 'phab version', ->
      hubot 'phab version'
      it 'should reply version number', ->
        expect(hubotResponse()).to.match /hubot-phabs module is version [0-9]+\.[0-9]+\.[0-9]+/

    context 'ph version', ->
      hubot 'ph version'
      it 'should reply version number', ->
        expect(hubotResponse()).to.match /hubot-phabs module is version [0-9]+\.[0-9]+\.[0-9]+/

  # ---------------------------------------------------------------------------------
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

  # ---------------------------------------------------------------------------------
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

  # ---------------------------------------------------------------------------------
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
          expect(hubotResponse()).to.eql 'T42 has status open, priority Low, owner toto'

      context 'ph T42 # with an ending space', ->
        hubot 'ph T42 '
        it 'gives information about the task Txxx', ->
          expect(hubotResponse()).to.eql 'T42 has status open, priority Low, owner toto'

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
          expect(hubotResponse()).to.eql 'oops T42 No such Maniphest task exists.'


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
          expect(hubotResponse()).to.eql 'T42 has status open, priority Low, owner nobody'

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
          expect(hubotResponse()).to.eql 'T42 has status open, priority Low, owner unknown'

  # ---------------------------------------------------------------------------------
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

  # ---------------------------------------------------------------------------------
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

  # ---------------------------------------------------------------------------------
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

  # ---------------------------------------------------------------------------------
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

  # ---------------------------------------------------------------------------------
  context 'user asks about a user', ->

    context 'phab toto', ->
      hubot 'phab toto'
      it 'warns when that user is unknown', ->
        expect(hubotResponse()).to.eql 'Sorry, I have no idea who toto is. Did you mistype it?'

    context 'phab user', ->
      hubot 'phab user'
      it 'warns when that user has no email', ->
        expect(hubotResponse()).to.eql "Sorry, I can't figure user email address. " +
                                       'Can you help me with .phab user = <email>'

    context 'user has an email', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.query')
          .reply(200, { result: [{ userName: 'user_with_email', phid: 'PHID-USER-999' }] })

      afterEach ->
        nock.cleanAll()

      context 'phab user_with_email', ->
        hubot 'phab user_with_email'
        it 'gets the phid for the user if he has an email', ->
          expect(hubotResponse()).to.eql "Hey I know user_with_email, he's PHID-USER-999"
          expect(room.robot.brain.userForId('user_with_email').phid).to.eql 'PHID-USER-999'

    context 'user has an email, but unknown to phabricator', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.query')
          .reply(200, { result: [] })

      afterEach ->
        nock.cleanAll()

      context 'phab user_with_email', ->
        hubot 'phab user_with_email'
        it 'gets a message complaining about the impossibility to match an email', ->
          expect(hubotResponse()).to.eql 'Sorry, I cannot find user@example.com :('

    context 'phab user_with_phid', ->
      hubot 'phab user_with_phid'
      it 'warns when that user has no email', ->
        expect(hubotResponse()).to.eql "Hey I know user_with_phid, he's PHID-USER-123456789"


  # ---------------------------------------------------------------------------------
  context 'user declares his own email', ->
    context 'phab me as momo@example.com', ->
      hubot 'phab me as momo@example.com'
      it 'says all is going to be fine', ->
        expect(hubotResponse()).to.eql "Okay, I'll remember your email is momo@example.com"
        expect(room.robot.brain.userForId('momo').email_address).to.eql 'momo@example.com'

  # ---------------------------------------------------------------------------------
  context 'user declares email for somebody else', ->
    context 'phab toto = toto@example.com', ->
      hubot 'phab toto = toto@example.com'
      it 'complains if the user is unknown', ->
        expect(hubotResponse()).to.eql 'Sorry I have no idea who toto is. Did you mistype it?'
    context 'phab user = user@example.com', ->
      hubot 'phab user = user@example.com'
      it 'sets the email for the user', ->
        expect(hubotResponse()).to.eql "Okay, I'll remember user email as user@example.com"
        expect(room.robot.brain.userForId('user').email_address).to.eql 'user@example.com'

  # ---------------------------------------------------------------------------------
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
                                         'Can you tell me with `.phab me as you@yourdomain.com`?'
      context 'when user is doing it for the first time and has set an email addresse', ->
        hubot 'phab new proj1 a task', 'user_with_email'
        it 'replies with the object id, and records phid for user', ->
          expect(hubotResponse()).to.eql 'Task T42 created = http://example.com/T42'
          expect(room.robot.brain.userForId('user_with_email').phid).to.eql 'PHID-USER-42'
      context 'when user is known and his phid is in the brain', ->
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
          .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 24 } } })
          .get('/api/maniphest.info')
          .reply(200, { result: {
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
          expect(hubotResponse(1)).to.eql 'Task T24 created = http://example.com/T24'
          expect(hubotResponse(3)).to.eql 'T24 has status open, priority Low, owner user_with_phid'


    context 'phab new proj3 a task', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj2': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.query')
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

  # ---------------------------------------------------------------------------------
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
          .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 24 } } })
          .get('/api/maniphest.info')
          .reply(200, { result: {
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
          expect(hubotResponse(3)).to.eql 'T24 has status open, priority Low, owner user_with_phid'


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
          .get('/api/project.query')
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

  # ---------------------------------------------------------------------------------
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
                                         'Can you tell me with `.phab me as you@yourdomain.com`?'
      context 'ph paste a new paste', ->
        hubot 'ph paste a new paste', 'user_with_phid'
        it 'gives the link to fill up the paste Paste', ->
          expect(hubotResponse()).to.eql 'Paste P24 created = ' +
                                         'edit on http://example.com/paste/edit/24'

  # ---------------------------------------------------------------------------------
  context 'user asks to count tasks in a project or column', ->

    context 'phab count proj1', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
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
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
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
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.query')
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

  # ---------------------------------------------------------------------------------
  context 'user changes status for a task', ->
    context 'when the task is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.edit')
          .reply(200, { error_info: 'No object exists with ID "4456874864".' })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 is open', ->
        hubot 'phab T424242 is open'
        it "warns the user that this Task doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops T424242 No object exists with ID "4456874864".'

    context 'when the task is present', ->

      context 'phab open', ->
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
          .get('/api/user.query')
          .reply(200, { result: [{ userName: 'toto' }] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab is open', ->
          hubot 'phab T42', 'user_with_phid'
          hubot 'phab is open', 'user_with_phid'
          it 'reports the status as open', ->
            expect(hubotResponse(3)).to.eql 'Ok, T42 now has status open.'

        context 'phab open', ->
          hubot 'phab T42', 'user_with_phid'
          hubot 'phab open', 'user_with_phid'
          it 'reports the status as open', ->
            expect(hubotResponse(3)).to.eql 'Ok, T42 now has status open.'

        context 'phab open', ->
          hubot 'phab T42', 'user_with_phid'
          hubot 'phab last open', 'user_with_phid'
          it 'reports the status as open', ->
            expect(hubotResponse(3)).to.eql 'Ok, T42 now has status open.'


      context 'phab T42 is open', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab open', ->
          hubot 'phab open'
          it 'warns the user that there is no active task in memory', ->
            expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

        context 'phab last open', ->
          hubot 'phab last open'
          it 'warns the user that there is no active task in memory', ->
            expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

        context 'phab T42 is open', ->
          hubot 'phab T42 is open'
          it 'reports the status as open', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status open.'

      context 'phab T42 open', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 open', ->
          hubot 'phab T42 open'
          it 'reports the status as open', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status open.'

      context 'phab T42 resolved', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 resolved', ->
          hubot 'phab T42 resolved'
          it 'reports the status as resolved', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status resolved.'

      context 'phab T42 wontfix', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 wontfix', ->
          hubot 'phab T42 wontfix'
          it 'reports the status as wontfix', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status wontfix.'

      context 'phab T42 invalid', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 invalid', ->
          hubot 'phab T42 invalid'
          it 'reports the status as invalid', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status invalid.'

      context 'phab T42 spite', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 spite', ->
          hubot 'phab T42 spite'
          it 'reports the status as spite', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status spite.'

      context 'phab T42 spite = what a crazy idea', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 spite = what a crazy idea', ->
          hubot 'phab T42 spite = what a crazy idea'
          it 'reports the status as spite', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status spite.'

  # ---------------------------------------------------------------------------------
  context 'error: non json', ->
    beforeEach ->
      do nock.disableNetConnect
      nock(process.env.PHABRICATOR_URL)
        .get('/api/maniphest.edit')
        .reply(200, '<body></body>', { 'Content-type': 'text/html' })

    afterEach ->
      nock.cleanAll()

    context 'phab T42 spite', ->
      hubot 'phab T42 spite'
      it 'reports an api error', ->
        expect(hubotResponse()).to.eql 'oops T42 api did not deliver json'

  context 'error: lib error', ->
    beforeEach ->
      do nock.disableNetConnect
      nock(process.env.PHABRICATOR_URL)
        .get('/api/maniphest.edit')
        .replyWithError({ 'message': 'something awful happened', 'code': 'AWFUL_ERROR' })

    afterEach ->
      nock.cleanAll()

    context 'phab T42 spite', ->
      hubot 'phab T42 spite'
      it 'reports a lib error', ->
        expect(hubotResponse()).to.eql 'oops T42 something awful happened'

  context 'error: lib error', ->
    beforeEach ->
      do nock.disableNetConnect
      nock(process.env.PHABRICATOR_URL)
        .get('/api/maniphest.edit')
        .reply(400)

    afterEach ->
      nock.cleanAll()

    context 'phab T42 spite', ->
      hubot 'phab T42 spite'
      it 'reports a http error', ->
        expect(hubotResponse()).to.eql 'oops T42 http error 400'

  # ---------------------------------------------------------------------------------
  context 'user changes priority for a task', ->
    context 'when the task is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.edit')
          .reply(200, { error_info: 'No such Maniphest task exists.' })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 is low', ->
        hubot 'phab T424242 is low'
        it "warns the user that this Task doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops T424242 No such Maniphest task exists.'

    context 'when the task is present', ->
  
      context 'phab T42 is broken', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab broken', ->
          hubot 'phab broken'
          it 'warns the user that there is no active task in memory', ->
            expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

        context 'phab T42 is broken', ->
          hubot 'phab T42 is broken'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority broken'
        context 'phab T42 broken', ->
          hubot 'phab T42 broken'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority broken'
        context 'phab T42 unbreak', ->
          hubot 'phab T42 unbreak'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority unbreak'

  
      context 'phab T42 is none', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 none', ->
          hubot 'phab T42 none'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority none'
        context 'phab T42 unknown', ->
          hubot 'phab T42 unknown'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority unknown'

      context 'phab T42 is none = maintainer left', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 none = maintainer left', ->
          hubot 'phab T42 none = maintainer left'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority none'

      context 'phab T42 is urgent', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 urgent', ->
          hubot 'phab T42 urgent'
          it 'reports the priority to be High', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority urgent'
        context 'phab T42 high', ->
          hubot 'phab T42 high'
          it 'reports the priority to be High', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority high'

      context 'phab T42 is normal', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 normal', ->
          hubot 'phab T42 normal'
          it 'reports the priority to be Normal', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority normal'

      context 'phab T42 is low', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.edit')
            .reply(200, { result: { object: { id: 42 } } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 low', ->
          hubot 'phab T42 low'
          it 'reports the priority to be Low', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority low'

  # ---------------------------------------------------------------------------------
  context 'user assigns someone to a task', ->
    context 'when the user is unknown', ->
      context 'phab assign T424242 to xxx', ->
        hubot 'phab assign T424242 to xxx'
        it 'warns the user that xx is unknown', ->
          expect(hubotResponse()).to.eql "Sorry I don't know who is xxx, " +
                                         'can you .phab xxx = <email>'
      context 'phab assign T424242 to momo', ->
        hubot 'phab assign T424242 to momo'
        it 'warns the user that his email is not known', ->
          expect(hubotResponse()).to.eql "Sorry, I can't figure out your email address :( " +
                                         'Can you tell me with `.phab me as you@yourdomain.com`?'

    context 'task is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.edit')
          .reply(200, { error_info: 'No such Maniphest task exists.' })

      afterEach ->
        nock.cleanAll()

      context 'phab assign T424242 to user_with_phid', ->
        hubot 'phab assign T424242 to user_with_phid'
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

      context 'phab on user_with_phid', ->
        hubot 'phab on user_with_phid'
        it 'warns the user that there is no active task in memory', ->
          expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

      context 'phab assign T42 to user_with_phid', ->
        hubot 'phab assign T42 to user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to.eql 'Ok. T42 is now assigned to user_with_phid'

      context 'phab assign T42 on user_with_phid', ->
        hubot 'phab assign T42 on user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to.eql 'Ok. T42 is now assigned to user_with_phid'

      context 'phab T42 on user_with_phid', ->
        hubot 'phab T42 on user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to.eql 'Ok. T42 is now assigned to user_with_phid'

      context 'phab user_with_phid on T42', ->
        hubot 'phab user_with_phid on T42'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to.eql 'Ok. T42 is now assigned to user_with_phid'

  # ---------------------------------------------------------------------------------
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
        hubot 'phab T424242 + some comment'
        it 'warns the user that the task does not exist', ->
          expect(hubotResponse()).to.eql 'oops T424242 No such Maniphest task exists.'

    context 'task is known', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.edit')
          .reply(200, { result: { id: 42 } })

      afterEach ->
        nock.cleanAll()

      context 'phab + some comment', ->
        hubot 'phab + some comment'
        it 'warns the user that there is no active task in memory', ->
          expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

      context 'phab T24 + some comment', ->
        hubot 'phab T24 + some comment'
        it 'gives a feedback that the comment was added', ->
          expect(hubotResponse()).to.eql 'Ok. Added comment "some comment" to T24.'

  # ---------------------------------------------------------------------------------
  context 'user searches through all tasks', ->

    context 'there is 2 results', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj3': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
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
            .to.eql 'http://example.com/T2490 - Task 1'
          expect(hubotResponse(2))
            .to.eql 'http://example.com/T2080 - Task 2'
          expect(hubotResponseCount()).to.eql 2

    context 'there is more than 3 results', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj3': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
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
            .to.eql 'http://example.com/T2490 - Task 1'
          expect(hubotResponse(2))
            .to.eql 'http://example.com/T2080 - Task 2'
          expect(hubotResponse(3))
            .to.eql 'http://example.com/T2078 - Task 3'
          expect(hubotResponse(4))
            .to.eql '... and there is more.'
          expect(hubotResponseCount()).to.eql 4


    context 'there is no results', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj3': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
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
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.query')
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

  # ---------------------------------------------------------------------------------
  context 'user searches through tasks', ->

    context 'there is 2 results', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj3': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
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
            .to.eql 'http://example.com/T2490 - Task 1'
          expect(hubotResponse(2))
            .to.eql 'http://example.com/T2080 - Task 2'
          expect(hubotResponseCount()).to.eql 2

    context 'there is more than 3 results', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj3': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
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
            .to.eql 'http://example.com/T2490 - Task 1'
          expect(hubotResponse(2))
            .to.eql 'http://example.com/T2080 - Task 2'
          expect(hubotResponse(3))
            .to.eql 'http://example.com/T2078 - Task 3'
          expect(hubotResponse(4))
            .to.eql '... and there is more.'
          expect(hubotResponseCount()).to.eql 4


    context 'there is no results', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj3': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
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

    context 'phab count proj4', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'proj2': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.query')
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
        hubot 'phab proj4 gitlab', 'user_with_phid'
        it 'replies that project is unknown', ->
          expect(hubotResponse()).to.eql 'Sorry, proj4 not found.'

  # ---------------------------------------------------------------------------------
  context 'permissions system', ->
    beforeEach ->
      process.env.HUBOT_AUTH_ADMIN = 'admin_user'
      room.robot.loadFile path.resolve('node_modules/hubot-auth/src'), 'auth.coffee'
      room.robot.brain.userForId 'admin_user', {
        name: 'admin_user',
        phid: 'PHID-USER-123456789'
      }
      room.robot.brain.userForId 'phadmin_user', {
        name: 'phadmin_user',
        phid: 'PHID-USER-123456789',
        roles: [
          'phadmin'
        ]
      }
      room.robot.brain.userForId 'phuser_user', {
        name: 'phuser_user',
        phid: 'PHID-USER-123456789',
        roles: [
          'phuser'
        ]
      }

    context 'user wants to create comment on a task', ->
      beforeEach ->
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
        hubot 'phab T24 + some comment', 'user_with_phid'
        it 'warns the user that he has no permission to use that command', ->
          expect(hubotResponse()).to.eql '@user_with_phid You don\'t have permission to do that.'

      context 'and user is not in phabs groups, but users are trusted', ->
        beforeEach ->
          process.env.PHABRICATOR_TRUSTED_USERS = 'y'
        hubot 'phab T24 + some comment', 'user_with_phid'
        it 'warns the user that he has no permission to use that command', ->
          expect(hubotResponse()).to.eql 'Ok. Added comment "some comment" to T24.'
