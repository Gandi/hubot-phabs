require('es6-promise').polyfill()

Helper = require('hubot-test-helper')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs.coffee')

nock = require('nock')
sinon = require("sinon")
expect = require('chai').use(require('sinon-chai')).expect

describe 'hubot-phabs', ->
  room = null

  context 'without calling Phabricator class', ->
    beforeEach ->
      process.env.PHABRICATOR_URL = "http://example.com"
      process.env.PHABRICATOR_API_KEY = "xxx"
      process.env.PHABRICATOR_BOT_PHID = "PHID-USER-xxx"
      process.env.PHABRICATOR_PROJECTS = "PHID-PROJ-xxx:proj1,PHID-PROJ-yyy:proj2"
      Phabricator = require '../lib/phabricator'

      room = helper.createRoom(httpd: false)

    afterEach ->
      delete process.env.PHABRICATOR_URL
      delete process.env.PHABRICATOR_API_KEY
      delete process.env.PHABRICATOR_BOT_PHID
      delete process.env.PHABRICATOR_PROJECTS

    context 'phab version', ->
      beforeEach ->
        room.user.say 'momo', '@hubot phab version'
      it 'should reply version number', ->
        expect(room.messages.length).to.eql 2
        expect(room.messages[0]).to.eql ['momo', '@hubot phab version']
        expect(room.messages[1][1]).to.match /hubot-phabs module is version [0-9]+\.[0-9]+\.[0-9]+/

    context 'ph version', ->
      beforeEach ->
        room.user.say 'momo', '@hubot ph version'
      it 'should reply version number', ->
        expect(room.messages.length).to.eql 2
        expect(room.messages[1][1]).to.match /hubot-phabs module is version [0-9]+\.[0-9]+\.[0-9]+/

    context 'phab list projects', ->
      beforeEach ->
        room.user.say 'momo', '@hubot phab list projects'
      it 'should reply the list of known projects according to PHABRICATOR_PROJECTS', ->
        expect(room.messages.length).to.eql 2
        expect(room.messages[1][1]).to.eql 'Known Projects: proj1, proj2'

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
        beforeEach (done) ->
          room.user.say 'momo', '@hubot phab T42'
          setTimeout done, 100

        it "gives information about the task Txxx", ->
          expect(room.messages).to.eql [
            ['momo', '@hubot phab T42']
            ['hubot', 'T42 has status open, priority Low, owner toto']
          ]

      context 'ph T42 # with an ending space', ->
        beforeEach (done) ->
          room.user.say 'momo', '@hubot ph T42 '
          setTimeout done, 100

        it "gives information about the task Txxx", ->
          expect(room.messages).to.eql [
            ['momo', '@hubot ph T42 ']
            ['hubot', 'T42 has status open, priority Low, owner toto']
          ]
