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
      delete process.env.PHABRICATOR_LISTS_INCOMING
      @room = helper.createRoom { httpd: false }

    describe '.ready', ->
      it 'is false if there is no env set', ->
        @phab_error = new Phabricator @room.robot, process.env
        msg = sinon.spy()
        msg.send = sinon.stub()
        ready = @phab_error.ready(msg)
        expect(ready).to.be.false
        expect(msg.send).calledTwice
      it 'is false if there is no url env set', ->
        process.env.PHABRICATOR_URL = 'http://example.com'
        @phab_error = new Phabricator @room.robot, process.env
        msg = sinon.spy()
        msg.send = sinon.stub()
        ready = @phab_error.ready(msg)
        expect(msg.send).calledOnce
        expect(ready).to.be.false

  context 'when env is set,', ->
    beforeEach ->
      process.env.PHABRICATOR_URL = 'http://example.com'
      process.env.PHABRICATOR_API_KEY = 'xxx'
      process.env.PHABRICATOR_BOT_PHID = 'PHID-USER-xxx'
      process.env.PHABRICATOR_PROJECTS = 'PHID-PROJ-xxx:proj1,PHID-PROJ-yyy:proj2'
      room = helper.createRoom { httpd: false }
      @phab = new Phabricator room.robot, process.env
      @msg = sinon.spy()
      @msg.message = sinon.spy()
      @msg.send = sinon.stub()
    afterEach ->
      delete process.env.PHABRICATOR_URL
      delete process.env.PHABRICATOR_API_KEY
      delete process.env.PHABRICATOR_BOT_PHID
      delete process.env.PHABRICATOR_PROJECTS

    describe 'new', ->
      it 'should initialize vars', ->
        expect(@phab.url).to.eql(process.env.PHABRICATOR_URL)
        expect(@phab.apikey).to.eql(process.env.PHABRICATOR_API_KEY)
        expect(@phab.bot_phid).to.eql(process.env.PHABRICATOR_BOT_PHID)

    describe '.ready', ->
      it 'should be ready', ->
        ready = @phab.ready(@msg)
        expect(@msg.send).not.called
        expect(ready).to.be.true
