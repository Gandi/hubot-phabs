require('es6-promise').polyfill()
Helper = require('hubot-test-helper')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs.coffee')

sinon = require("sinon")
expect = require('chai').use(require('sinon-chai')).expect

describe 'hubot-phabs', ->
  @room = null

  beforeEach ->
    process.env.PHABRICATOR_URL = "http://example.com"
    process.env.PHABRICATOR_API_KEY = "xxx"
    process.env.PHABRICATOR_BOT_PHID = "PHID-USER-xxx"
    process.env.PHABRICATOR_PROJECTS = "PHID-PROJ-xxx:proj1,PHID-PROJ-yyy:proj2"
    @room = helper.createRoom(httpd: false)

  afterEach ->
    delete process.env.PHABRICATOR_URL
    delete process.env.PHABRICATOR_API_KEY
    delete process.env.PHABRICATOR_BOT_PHID
    delete process.env.PHABRICATOR_PROJECTS

  context 'phab version', ->
    beforeEach ->
      @room.user.say 'momo', '@hubot phab version'
    it 'should reply version number', ->
      expect(@room.messages.length).to.eql 2
      expect(@room.messages[0]).to.eql ['momo', '@hubot phab version']
      expect(@room.messages[1][1]).to.match /hubot-phabs module is version [0-9]+\.[0-9]+\.[0-9]+/

  context 'ph version', ->
    beforeEach ->
      @room.user.say 'momo', '@hubot ph version'
    it 'should reply version number', ->
      expect(@room.messages.length).to.eql 2
      expect(@room.messages[1][1]).to.match /hubot-phabs module is version [0-9]+\.[0-9]+\.[0-9]+/

  context 'phab list projects', ->
    beforeEach ->
      @room.user.say 'momo', '@hubot phab list projects'
    it 'should reply version number', ->
      expect(@room.messages.length).to.eql 2
      expect(@room.messages[1][1]).to.match /Known Projects: proj1, proj2/

