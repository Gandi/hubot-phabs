require('es6-promise').polyfill()

Helper = require('hubot-test-helper')
Hubot = require('../node_modules/hubot')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs_admin.coffee')

nock = require('nock')
sinon = require('sinon')
expect = require('chai').use(require('sinon-chai')).expect

room = null

describe 'phabs_admin module', ->

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
        room.robot.brain.data.phabricator = { }

      context 'phad projects', ->
        hubot 'phad projects'
        it 'should reply the list of known projects', ->
          expect(hubotResponse()).to.eql 'Known Projects: project1, project2, project3'

  # ---------------------------------------------------------------------------------
  context 'user wants to know info for a project', ->

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    context 'when project has no record', ->

      context 'and is unknown to phabricator', ->
        beforeEach ->
          room.robot.brain.data.phabricator.projects = {
            'Bug Report': { },
            'project with phid': { phid: 'PHID-PROJ-1234567' },
          }
          room.robot.brain.data.phabricator.aliases = {
            bugs: 'project with phid',
            bug: 'project with phid'
          }
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/project.query')
            .query({
              'names[0]': 'project1',
              'api.token': 'xxx'
            })
            .reply(200, { result: {
              'data': [ ],
              'slugMap': [ ],
              'cursor': {
                'limit': 100,
                'after': null,
                'before': null
              }
            } })

        afterEach ->
          room.robot.brain.data.phabricator = { }
          nock.cleanAll()

        context 'phad unknown info', ->
          hubot 'phad unknown info'
          it 'should reply with proper info', ->
            expect(hubotResponse())
              .to.eql 'Project unknown not found.'

      context 'and is known to phabricator', ->
        beforeEach ->
          room.robot.brain.data.phabricator.projects = {
            'project with phid': { phid: 'PHID-PROJ-1234567' },
          }
          room.robot.brain.data.phabricator.aliases = {
            bugs: 'project with phid',
            bug: 'project with phid'
          }
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/project.query')
            .query({
              'names[0]': 'project1',
              'api.token': 'xxx'
            })
            .reply(200, { result: {
              'data': {
                'PHID-PROJ-qhmexneudkt62wc7o3z4': {
                  'id': '1402',
                  'phid': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                  'name': 'Bug Report',
                  'profileImagePHID': 'PHID-FILE-2dsjotf2zgtbludzlk4s',
                  'icon': 'bugs',
                  'color': 'yellow',
                  'members': [
                    'PHID-USER-3yc34eijivr6rqs4vgiw',
                    'PHID-USER-7k37pmi3jffv46mzs5te'
                  ],
                  'slugs': [
                    'bug_report'
                  ],
                  'dateCreated': '1449275954',
                  'dateModified': '1468138110'
                }
              },
              'slugMap': [ ],
              'cursor': {
                'limit': 100,
                'after': null,
                'before': null
              }
            } })

        afterEach ->
          room.robot.brain.data.phabricator = { }
          nock.cleanAll()

        context 'phad Bug Report info', ->
          hubot 'phad Bug Report info'
          it 'should reply with proper info', ->
            expect(hubotResponse())
              .to.eql 'Bug Report is Bug Report, with no alias, with no feed.'
          it 'should remember the phid from asking to phabricator', ->
            expect(room.robot.brain.data.phabricator.projects['Bug Report'].phid)
              .to.eql 'PHID-PROJ-qhmexneudkt62wc7o3z4'


    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    context 'when project has no phid recorded', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': { },
          'project with phid': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = { }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.query')
          .query({
            'names[0]': 'project1',
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            'data': {
              'PHID-PROJ-qhmexneudkt62wc7o3z4': {
                'id': '1402',
                'phid': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                'name': 'Bug Report',
                'profileImagePHID': 'PHID-FILE-2dsjotf2zgtbludzlk4s',
                'icon': 'bugs',
                'color': 'yellow',
                'members': [
                  'PHID-USER-3yc34eijivr6rqs4vgiw',
                  'PHID-USER-7k37pmi3jffv46mzs5te'
                ],
                'slugs': [
                  'bug_report'
                ],
                'dateCreated': '1449275954',
                'dateModified': '1468138110'
              }
            },
            'slugMap': [ ],
            'cursor': {
              'limit': 100,
              'after': null,
              'before': null
            }
          } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad Bug Report info', ->
        hubot 'phad Bug Report info'
        it 'should reply with proper info', ->
          expect(hubotResponse()).to.eql 'Bug Report is Bug Report, with no alias, with no feed.'
        it 'should remember the phid from asking to phabricator', ->
          expect(room.robot.brain.data.phabricator.projects['Bug Report'].phid)
            .to.eql 'PHID-PROJ-qhmexneudkt62wc7o3z4'

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    context 'when project has phid recorded, and aliases', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': { },
          'project with phid': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'project with phid',
          bug: 'project with phid'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad project with phid info', ->
        hubot 'phad project with phid info'
        it 'should reply with proper info', ->
          expect(hubotResponse())
            .to.eql 'project with phid is project with phid (aka bugs, bug), with no feed.'
