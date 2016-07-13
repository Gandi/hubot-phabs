Helper = require('hubot-test-helper')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs.coffee')

expect = require('chai').use(require('sinon-chai')).expect

describe 'hello-world', ->

  beforeEach ->
    @room = helper.createRoom(httpd: false)

  # afterEach ->
  #   @room.destroy()

  context 'user says hi to hubot', ->

    it 'should reply to user', ->
      # @room.user.say('alice', '@hubot hi').then =>
      #   expect(@room.messages).to.eql [
      #     ['alice', '@hubot hi']
      #     ['hubot', '@alice hi']
      #   ]
