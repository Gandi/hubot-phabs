Phabricator = require('../lib/phabricator.coffee')
sinon = require('sinon')
expect = require('chai').use(require('sinon-chai')).expect
nock = require('nock')

Helper = require('hubot-test-helper')
Hubot = require('../node_modules/hubot')
# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs_hear.coffee')

describe 'Phabricator lib', ->

  context 'when env is not set,', ->
    beforeEach ->
      delete process.env.PHABRICATOR_URL
      delete process.env.PHABRICATOR_API_KEY
      delete process.env.PHABRICATOR_BOT_PHID
      @room = helper.createRoom { httpd: false }

    describe '.ready', ->
      it 'is false if there is no env set', ->
        @phab_error = new Phabricator @room.robot, process.env
        @room.robot.logger = sinon.spy()
        @room.robot.logger.error = sinon.stub()
        ready = @phab_error.ready()
        expect(ready).to.be.false
        expect(@room.robot.logger.error).calledTwice
      it 'is false if there is no url env set', ->
        process.env.PHABRICATOR_URL = 'http://example.com'
        @phab_error = new Phabricator @room.robot, process.env
        @room.robot.logger = sinon.spy()
        @room.robot.logger.error = sinon.stub()
        ready = @phab_error.ready()
        expect(@room.robot.logger.error).calledOnce
        expect(ready).to.be.false

  context 'when env is set,', ->
    beforeEach ->
      process.env.PHABRICATOR_URL = 'http://example.com'
      process.env.PHABRICATOR_API_KEY = 'xxx'
      process.env.PHABRICATOR_BOT_PHID = 'PHID-USER-xxx'
      room = helper.createRoom { httpd: false }
      @phab = new Phabricator room.robot, process.env
      @msg = sinon.spy()
      @msg.message = sinon.spy()
      @msg.send = sinon.stub()
    afterEach ->
      delete process.env.PHABRICATOR_URL
      delete process.env.PHABRICATOR_API_KEY
      delete process.env.PHABRICATOR_BOT_PHID

    describe 'new', ->
      it 'should initialize vars', ->
        expect(@phab.url).to.eql(process.env.PHABRICATOR_URL)
        expect(@phab.apikey).to.eql(process.env.PHABRICATOR_API_KEY)

    describe '.ready', ->
      it 'should be ready', ->
        ready = @phab.ready(@msg)
        expect(@msg.send).not.called
        expect(ready).to.be.true
