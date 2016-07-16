require('es6-promise').polyfill()

Helper = require('hubot-test-helper')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs.coffee')

nock = require('nock')
sinon = require("sinon")
expect = require('chai').use(require('sinon-chai')).expect

room = null

describe 'hubot-phabs module', ->

  hubotHear = (message) ->
    beforeEach (done) ->
      room.messages = []
      room.user.say "momo", message
      room.messages.shift()
      setTimeout (done), 50

  hubot = (message) ->
    hubotHear "@hubot #{message}"

  hubotResponse = () ->
    room.messages[0][1]

  hubotResponseCount = () ->
    room.messages.length

  context 'without calling Phabricator class', ->
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

    context 'phab version', ->
      hubot 'phab version'
      it 'should reply version number', ->
        expect(hubotResponse()).to.match /hubot-phabs module is version [0-9]+\.[0-9]+\.[0-9]+/

    context 'ph version', ->
      hubot 'ph version'
      it 'should reply version number', ->
        expect(hubotResponse()).to.match /hubot-phabs module is version [0-9]+\.[0-9]+\.[0-9]+/

    context 'phab list projects', ->
      hubot 'phab list projects'
      it 'should reply the list of known projects according to PHABRICATOR_PROJECTS', ->
        expect(hubotResponseCount()).to.eql 1
        expect(hubotResponse()).to.eql 'Known Projects: proj1, proj2'

  context 'with calling Phabricator class', ->
    beforeEach ->
      process.env.PHABRICATOR_URL = "http://example.com"
      process.env.PHABRICATOR_API_KEY = "xxx"
      process.env.PHABRICATOR_BOT_PHID = "PHID-USER-xxx"
      process.env.PHABRICATOR_PROJECTS = "PHID-PROJ-xxx:proj1,PHID-PROJ-yyy:proj2"

    afterEach ->
      delete process.env.PHABRICATOR_URL
      delete process.env.PHABRICATOR_API_KEY
      delete process.env.PHABRICATOR_BOT_PHID
      delete process.env.PHABRICATOR_PROJECTS

    context 'user asks for task info', ->
      beforeEach ->
        room = helper.createRoom(httpd: false)
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
