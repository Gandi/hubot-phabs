require('es6-promise').polyfill()

Helper = require('hubot-test-helper')
Hubot = require('../node_modules/hubot-test-helper/node_modules/hubot')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs.coffee')

nock = require('nock')
sinon = require('sinon')
expect = require('chai').use(require('sinon-chai')).expect

room = null

describe 'hubot-phabs module', ->

  hubotHear = (message) ->
    beforeEach (done) ->
      room.messages = []
      room.user.say "momo", message
      room.messages.shift()
      setTimeout (done), 50

  setEmail = () ->
    beforeEach ->
      room.receive = (userName, message) ->
        new Promise (resolve) =>
          @messages.push [userName, message]
          user = new Hubot.User(userName, { room: @name, email_address: 'momo@example.com' })
          @robot.receive(new Hubot.TextMessage(user, message), resolve)

  setPhid = () ->
    beforeEach ->
      room.receive = (userName, message) ->
        new Promise (resolve) =>
          @messages.push [userName, message]
          user = new Hubot.User(userName, { room: @name, phid: '40' })
          @robot.receive(new Hubot.TextMessage(user, message), resolve)

  hubot = (message) ->
    hubotHear "@hubot #{message}"

  hubotResponse = () ->
    room.messages[0][1]

  hubotResponseCount = () ->
    room.messages.length

  beforeEach ->
    process.env.PHABRICATOR_URL = "http://example.com"
    process.env.PHABRICATOR_API_KEY = "xxx"
    process.env.PHABRICATOR_BOT_PHID = "PHID-USER-xxx"
    process.env.PHABRICATOR_PROJECTS = "PHID-PROJ-xxx:proj1,PHID-PROJ-yyy:proj2"
    room = helper.createRoom(httpd: false)

  afterEach ->
    delete process.env.PHABRICATOR_URL
    delete process.env.PHABRICATOR_API_KEY
    delete process.env.PHABRICATOR_BOT_PHID
    delete process.env.PHABRICATOR_PROJECTS

  context 'user wants to know hubot-phabs version', ->

    context 'phab version', ->
      hubot 'phab version'
      it 'should reply version number', ->
        expect(hubotResponse()).to.match /hubot-phabs module is version [0-9]+\.[0-9]+\.[0-9]+/

    context 'ph version', ->
      hubot 'ph version'
      it 'should reply version number', ->
        expect(hubotResponse()).to.match /hubot-phabs module is version [0-9]+\.[0-9]+\.[0-9]+/

  context 'user requests the list of known projects', ->

    context 'phab list projects', ->
      hubot 'phab list projects'
      it 'should reply the list of known projects according to PHABRICATOR_PROJECTS', ->
        expect(hubotResponseCount()).to.eql 1
        expect(hubotResponse()).to.eql 'Known Projects: proj1, proj2'

  context 'user asks for task info', ->
    beforeEach ->
      do nock.disableNetConnect
      nock(process.env.PHABRICATOR_URL)
        .get('/api/maniphest.info')
        .reply( 200, { result: { status: 'open', priority: 'Low', name: 'Test task', ownerPHID: 'PHID-USER-42' }})
        .get('/api/user.query')
        .reply( 200, { result: [{ userName: 'toto' }]})

    afterEach ->
      nock.cleanAll()

    context 'phab T42', ->
      hubot 'phab T42'
      it "gives information about the task Txxx", ->
        expect(hubotResponse()).to.eql 'T42 has status open, priority Low, owner toto'

    context 'ph T42 # with an ending space', ->
      hubot 'ph T42 '
      it "gives information about the task Txxx", ->
        expect(hubotResponse()).to.eql 'T42 has status open, priority Low, owner toto'


  context 'user creates a new task', ->
    beforeEach ->
      do nock.disableNetConnect
      nock(process.env.PHABRICATOR_URL)
        .get('/api/user.query')
        .reply( 200, { result: [{ phid: 'PHID-USER-42' }]})
        .get('/api/maniphest.edit')
        .reply( 200, { result: { object: { id: 42 }}})

    afterEach ->
      nock.cleanAll()

    context 'phab new something blah blah', ->
      hubot 'phab new something blah blah'
      it "fails to comply if the project is not registered by PHABRICATOR_PROJECTS", ->
        expect(hubotResponse()).to.eql 'Command incomplete.'

    context 'phab new proj1 a task', ->
      context 'when user is doing it for the first time and has no email recorded', ->
        hubot 'phab new proj1 a task'
        it "invites the user to set his email address", ->
          expect(hubotResponse()).to.eql 'Sorry, I can\'t figure out your email address :( Can you tell me with `.phab me as you@yourdomain.com`?'
      context 'when user is doing it for the first time and has set an email addresse', ->
        setEmail()
        hubot 'phab new proj1 a task'
        it "invites the user to set his email address", ->
          expect(hubotResponse()).to.eql 'Task T42 created = http://example.com/T42'
      context 'when user is known and his phid is in the brain', ->
        setPhid()
        hubot 'phab new proj1 a task'
        it "invites the user to set his email address", ->
          expect(hubotResponse()).to.eql 'Task T42 created = http://example.com/T42'


  context 'user changes status for a task', ->
    context 'when the task is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.update')
          .reply( 200, { result: { error_info: 'not found.' }})

      afterEach ->
        nock.cleanAll()

      context '', ->
        hubot 'phab T424242 is open'
        it "invites the user to set his email address", ->
          expect(hubotResponse()).to.eql 'oops T424242 not found.'

    context 'when the task is present', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.update')
          .reply( 200, { result: { phid: 'PHID-TASK-42' }})

      afterEach ->
        nock.cleanAll()

      context 'phab T42 is open', ->
        hubot 'phab T42 is open'
        it 'reports the status as open', ->
          expect(hubotResponse()).to.eql 'Ok, T42 now has status open.'
      context 'phab T42 open', ->
        hubot 'phab T42 open'
        it 'reports the status as open', ->
          expect(hubotResponse()).to.eql 'Ok, T42 now has status open.'
      context 'phab T42 resolved', ->
        hubot 'phab T42 resolved'
        it 'reports the status as resolved', ->
          expect(hubotResponse()).to.eql 'Ok, T42 now has status resolved.'
      context 'phab T42 wontfix', ->
        hubot 'phab T42 wontfix'
        it 'reports the status as wontfix', ->
          expect(hubotResponse()).to.eql 'Ok, T42 now has status wontfix.'
      context 'phab T42 invalid', ->
        hubot 'phab T42 invalid'
        it 'reports the status as invalid', ->
          expect(hubotResponse()).to.eql 'Ok, T42 now has status invalid.'
      context 'phab T42 spite', ->
        hubot 'phab T42 spite'
        it 'reports the status as spite', ->
          expect(hubotResponse()).to.eql 'Ok, T42 now has status spite.'
