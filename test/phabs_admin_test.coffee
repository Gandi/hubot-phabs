require('es6-promise').polyfill()

Helper = require('hubot-test-helper')
Hubot = require('../node_modules/hubot')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs_admin.coffee')

nock = require('nock')
sinon = require('sinon')
expect = require('chai').use(require('sinon-chai')).expect

room = null

describe 'hubot-phabs module', ->

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
    room.robot.brain.userForId 'user', {
      name: 'user'
    }
    room.robot.brain.userForId 'user_with_email', {
      name: 'user_with_email',
      email_address: 'user@example.com'
    }
    room.robot.brain.userForId 'user_with_phid', {
      name: 'user_with_phid',
      phid: 'PHID-USER-123456789'
    }
    room.receive = (userName, message) ->
      new Promise (resolve) =>
        @messages.push [userName, message]
        user = room.robot.brain.userForId userName
        @robot.receive(new Hubot.TextMessage(user, message), resolve)

  afterEach ->
    delete process.env.PHABRICATOR_URL
    delete process.env.PHABRICATOR_API_KEY
    delete process.env.PHABRICATOR_BOT_PHID

  # ---------------------------------------------------------------------------------
  context 'user wants to know the list of projects', ->

    context 'when there is no project registered yet', ->
      context 'phad projects', ->
        hubot 'phad projects'
        it 'should reply the list of known projects', ->
          expect(hubotResponse()).to.eql 'There is no project.'

    context 'when there is some projects registered', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'project1': { },
          'project2': { },
          'project3': { },
        }
        room.robot.brain.data.phabricator.aliases =  { }
      afterEach ->
        room.robot.brain.remove 'phabricator'

      context 'phad projects', ->
        hubot 'phad projects'
        it 'should reply the list of known projects', ->
          expect(hubotResponse()).to.eql 'Known Projects: project1, project2, project3'
