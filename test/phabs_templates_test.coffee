require('es6-promise').polyfill()

Helper = require('hubot-test-helper')
Hubot = require('../node_modules/hubot')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs_templates.coffee')

path   = require 'path'
nock   = require 'nock'
sinon  = require 'sinon'
expect = require('chai').use(require('sinon-chai')).expect

room = null

describe 'phabs_templates module', ->

  hubotHear = (message, userName = 'momo', tempo = 40) ->
    beforeEach (done) ->
      room.user.say userName, message
      setTimeout (done), tempo

  hubot = (message, userName = 'momo') ->
    hubotHear "@hubot #{message}", userName

  hubotResponse = (i = 1) ->
    room.messages[i]?[1]

  hubotResponseCount = ->
    room.messages.length

  beforeEach ->
    process.env.PHABRICATOR_URL = 'http://example.com'
    process.env.PHABRICATOR_API_KEY = 'xxx'
    process.env.PHABRICATOR_BOT_PHID = 'PHID-USER-xxx'
    room = helper.createRoom { httpd: false }

  afterEach ->
    delete process.env.PHABRICATOR_URL
    delete process.env.PHABRICATOR_API_KEY
    delete process.env.PHABRICATOR_BOT_PHID

  # ---------------------------------------------------------------------------------
  context 'user creates a new template', ->

    context 'and this template already exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.templates = {
          template1: { task: '123' }
        }

      afterEach ->
        room.robot.brain.data.phabricator = { }

      context 'pht new template1 T333', ->
        hubot 'pht new template1 T333'
        it 'should reply that this template already exists', ->
          expect(hubotResponse()).to.eql 'Template \'template1\' already exists.'

    context 'and this template does not exist yet', ->
      beforeEach ->
        room.robot.brain.data.phabricator.templates = {
          template1: { task: '123' }
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': '333',
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-42'
            } })


      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'pht new template2 T333', ->
        hubot 'pht new template2 T333'
        it 'should reply that the template was created', ->
          expect(hubotResponse()).to.eql 'Ok. Template \'template2\' will use T333.'

  # ---------------------------------------------------------------------------------
  context 'user wants info about a template', ->

    context 'and this template already exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.templates = {
          template1: { task: '123' }
        }

      afterEach ->
        room.robot.brain.data.phabricator = { }

      context 'pht show template1', ->
        hubot 'pht show template1'
        it 'should reply what task is associated with that template', ->
          expect(hubotResponse()).to.eql 'Template \'template1\' uses T123.'

    context 'and this template does not exist yet', ->
      beforeEach ->
        room.robot.brain.data.phabricator.templates = {
          template1: { task: '123' }
        }

      afterEach ->
        room.robot.brain.data.phabricator = { }

      context 'pht show template2', ->
        hubot 'pht show template2'
        it 'should reply that the template does not exist', ->
          expect(hubotResponse()).to.eql 'Template \'template2\' was not found.'

  # ---------------------------------------------------------------------------------
  context 'user searches a template', ->

    context 'and there is no matching template', ->
      beforeEach ->
        room.robot.brain.data.phabricator.templates = {
          template1: { task: '123' }
        }

      afterEach ->
        room.robot.brain.data.phabricator = { }

      context 'pht search something', ->
        hubot 'pht search something'
        it 'should reply that there is no match', ->
          expect(hubotResponse()).to.eql 'No template matches \'something\'.'

    context 'and there are some matching templates', ->
      beforeEach ->
        room.robot.brain.data.phabricator.templates = {
          template1: { task: '123' },
          template2: { task: '456' },
          template3: { task: '789' },
        }

      afterEach ->
        room.robot.brain.data.phabricator = { }

      context 'pht search plate', ->
        hubot 'pht search plate'
        it 'should reply the list of matching templates', ->
          expect(hubotResponse(1)).to.eql 'Template \'template1\' uses T123.'
          expect(hubotResponse(2)).to.eql 'Template \'template2\' uses T456.'
          expect(hubotResponse(3)).to.eql 'Template \'template3\' uses T789.'

  # ---------------------------------------------------------------------------------
  context 'user removes a template', ->

    context 'and this template exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.templates = {
          template1: { task: '123' }
        }

      afterEach ->
        room.robot.brain.data.phabricator = { }

      context 'pht remove template1', ->
        hubot 'pht remove template1'
        it 'should reply that there is no such template', ->
          expect(hubotResponse()).to.eql 'Ok. Template \'template1\' was removed.'
          expect(room.robot.brain.data.phabricator.templates.template1).not.to.exist

    context 'but this template does not exist', ->
      beforeEach ->
        room.robot.brain.data.phabricator.templates = {
          template1: { task: '123' }
        }

      afterEach ->
        room.robot.brain.data.phabricator = { }

      context 'pht remove template2', ->
        hubot 'pht remove template2'
        it 'should reply that the removal succeeded', ->
          expect(hubotResponse()).to.eql 'Template \'template2\' was not found.'
          expect(room.robot.brain.data.phabricator.templates.template1).to.exist
