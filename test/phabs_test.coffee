require('es6-promise').polyfill()
Helper = require('hubot-test-helper')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs.coffee')

sinon = require("sinon")
expect = require('chai').use(require('sinon-chai')).expect

describe 'hubot-phabs', ->
  @room = null

  beforeEach ->
    @room = helper.createRoom(httpd: false)

  context 'version', ->
    beforeEach ->
      @room.user.say 'alice', '@hubot phab version'

    it 'should reply version number', ->
      expect(@room.messages[0]).to.eql ['alice', '@hubot phab version']
      expect(@room.messages[1][1]).to.match /hubot-phabs module is version [0-9]+\.[0-9]+\.[0-9]+/
