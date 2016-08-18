Helper = require('hubot-test-helper')
Hubot = require('../node_modules/hubot')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs_events.coffee')

nock   = require 'nock'
sinon  = require 'sinon'
expect = require('chai').use(require('sinon-chai')).expect

room = null

# ---------------------------------------------------------------------------------
describe 'phabs_events module', ->

  beforeEach ->
    process.env.PHABRICATOR_URL = 'http://example.com'
    process.env.PHABRICATOR_API_KEY = 'xxx'
    process.env.PHABRICATOR_BOT_PHID = 'PHID-USER-xxx'
    room = helper.createRoom { httpd: false }
    room.robot.brain.userForId 'user_with_phid', {
      name: 'user_with_phid',
      phid: 'PHID-USER-123456789'
    }

  afterEach ->
    delete process.env.PHABRICATOR_URL
    delete process.env.PHABRICATOR_API_KEY
    delete process.env.PHABRICATOR_BOT_PHID

  # ---------------------------------------------------------------------------------
  context 'something emits a phab.createTask event', ->
    it 'should know about phab.createTask', ->
      expect(room.robot.events['phab.createTask']).to.be.defined

    context 'and it does not generate an error, ', ->
      beforeEach (done) ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        room.robot.logger = sinon.spy()
        room.robot.logger.info = sinon.spy()
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })
        room.robot.emit 'phab.createTask', {
          project: 'proj1',
          template: undefined,
          name: 'a task',
          description: undefined,
          user: { name: 'user_with_phid' }
        }
        setTimeout (done), 40

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      it 'logs a success', ->
        expect(room.robot.logger.info).calledOnce
        expect(room.robot.logger.info).calledWith 'Task T42 created = http://example.com/T42'

    context 'and it generates an error, ', ->
      beforeEach (done) ->
        room.robot.brain.data.phabricator.projects = {
          'proj1': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          }
        }
        room.robot.logger = sinon.spy()
        room.robot.logger.error = sinon.spy()
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.edit')
          .reply(200, { error_info: 'failed' })
        room.robot.emit 'phab.createTask', {
          project: 'proj1',
          template: undefined,
          name: 'a task',
          description: undefined,
          user: { name: 'user_with_phid' }
        }
        setTimeout (done), 40

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      it 'logs an error', ->
        expect(room.robot.logger.error).calledOnce
        expect(room.robot.logger.error).calledWith 'failed'
