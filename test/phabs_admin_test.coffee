require('es6-promise').polyfill()

Helper = require('hubot-test-helper')
Hubot = require('../node_modules/hubot')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs_admin.coffee')

path   = require 'path'
nock   = require 'nock'
sinon  = require 'sinon'
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
      context 'phad list', ->
        hubot 'phad list'
        it 'should reply the list of known projects', ->
          expect(hubotResponse()).to.eql 'Known Projects: project1, project2, project3'

  # ---------------------------------------------------------------------------------
  context 'user wants to delete a project', ->

    context 'when there is no project registered yet', ->
      context 'phad del project1', ->
        hubot 'phad del project1'
        it 'should reply that this project is unknown', ->
          expect(hubotResponse()).to.eql 'project1 not found in memory.'

    context 'when there is a project registered under that name', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'project1': { },
          'project2': { },
          'project3': { },
        }
        room.robot.brain.data.phabricator.aliases =  { }

      afterEach ->
        room.robot.brain.data.phabricator = { }

      context 'phad delete project1', ->
        hubot 'phad delete project1'
        it 'should reply that this project was forgotten', ->
          expect(hubotResponse()).to.eql 'project1 erased from memory.'
          expect(Object.keys(room.robot.brain.data.phabricator.projects).length)
            .to.eql 2
          expect(room.robot.brain.data.phabricator.projects['project1'])
            .to.eql undefined
      context 'phad del project1', ->
        hubot 'phad del project1'
        it 'should reply that this project was forgotten', ->
          expect(hubotResponse()).to.eql 'project1 erased from memory.'
          expect(Object.keys(room.robot.brain.data.phabricator.projects).length)
            .to.eql 2
          expect(room.robot.brain.data.phabricator.projects['project1'])
            .to.eql undefined

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

        context 'phad info unknown', ->
          hubot 'phad info unknown'
          it 'should reply with proper info', ->
            expect(hubotResponse())
              .to.eql 'Sorry, unknown not found.'

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

        context 'phad info Bug Report', ->
          hubot 'phad info Bug Report'
          it 'should reply with proper info', ->
            expect(hubotResponse())
              .to.eql "'Bug Report' is 'Bug Report', with no alias, with no feed."
          it 'should remember the phid from asking to phabricator', ->
            expect(room.robot.brain.data.phabricator.projects['Bug Report'].phid)
              .to.eql 'PHID-PROJ-qhmexneudkt62wc7o3z4'


    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    context 'when project has no phid recorded', ->
      context 'and the project is known', ->
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

        context 'phad show Bug Report', ->
          hubot 'phad show Bug Report'
          it 'should reply with proper info', ->
            expect(hubotResponse())
              .to.eql "'Bug Report' is 'Bug Report', with no alias, with no feed."
          it 'should remember the phid from asking to phabricator', ->
            expect(room.robot.brain.data.phabricator.projects['Bug Report'].phid)
              .to.eql 'PHID-PROJ-qhmexneudkt62wc7o3z4'


      context 'and the project is unknown to phabricator', ->
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

        context 'phad info Bug Report', ->
          hubot 'phad info Bug Report'
          it 'should reply with proper info', ->
            expect(hubotResponse())
              .to.eql 'Sorry, Bug Report not found.'

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

      context 'phad info project with phid', ->
        hubot 'phad info project with phid'
        it 'should reply with proper info', ->
          expect(hubotResponse())
            .to.eql "'project with phid' is 'project with phid' (aka bugs, bug), with no feed."

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    context 'when project has phid recorded, and feeds', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': { },
          'project with phid': {
            phid: 'PHID-PROJ-1234567',
            feeds: [ '#dev' ]
          },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'Bug Report',
          bug: 'Bug Report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad info project with phid', ->
        hubot 'phad info project with phid'
        it 'should reply with proper info', ->
          expect(hubotResponse())
            .to.eql "'project with phid' is 'project with phid', with no alias, announced on #dev"

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    context 'when project has phid recorded, and aliases, and is called by an alias', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': { phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4' },
          'project with phid': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'Bug Report',
          bug: 'Bug Report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad info bug', ->
        hubot 'phad info bug'
        it 'should reply with proper info', ->
          expect(hubotResponse())
            .to.eql "'bug' is 'Bug Report' (aka bugs, bug), with no feed."

  # ---------------------------------------------------------------------------------
  context 'user wants to create an alias for a project', ->

    context 'and is project is unknown to phabricator', ->
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

      context 'phad alias project1 as bug', ->
        hubot 'phad alias project1 as bug'
        it 'should reply with proper info', ->
          expect(hubotResponse())
            .to.eql 'Sorry, project1 not found.'

    context 'when the alias already exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': { phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4' },
          'project with phid': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'Bug Report',
          bug: 'Bug Report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad alias project with phid as bug', ->
        hubot 'phad alias project with phid as bug'
        it 'should say that the alias already exists', ->
          expect(hubotResponse())
            .to.eql "The alias 'bug' already exists for project 'Bug Report'."


    context 'when the alias does not exists yet', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': { phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4' },
          'project with phid': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'Bug Report',
          bug: 'Bug Report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad alias project with phid as pwp', ->
        hubot 'phad alias project with phid as pwp'
        it 'should say that the alias was created', ->
          expect(hubotResponse())
            .to.eql "Ok, 'project with phid' will be known as 'pwp'."

  # ---------------------------------------------------------------------------------
  context 'user wants to remove an alias', ->

    context 'when the alias exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': { phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4' },
          'project with phid': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'Bug Report',
          bug: 'Bug Report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad forget bug', ->
        hubot 'phad forget bug'
        it 'should say that the alias was forgotten', ->
          expect(hubotResponse())
            .to.eql "Ok, the alias 'bug' is forgotten."
        it 'should have really forgotten the alias', ->
          expect(room.robot.brain.data.phabricator.aliases['bug'])
            .to.be.undefined

    context 'when the alias does not exists yet', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': { phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4' },
          'project with phid': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'Bug Report',
          bug: 'Bug Report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad forget pwp', ->
        hubot 'phad forget pwp'
        it 'should say that the alias already exists', ->
          expect(hubotResponse())
            .to.eql "Sorry, I don't know the alias 'pwp'."

  # ---------------------------------------------------------------------------------
  context 'user wants to add a feed to a project', ->

    context 'and is project is unknown to phabricator', ->
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

      context 'phad feed project1 to #dev', ->
        hubot 'phad feed project1 to #dev'
        it 'should reply with proper info', ->
          expect(hubotResponse())
            .to.eql 'Sorry, project1 not found.'

    context 'but the feed already exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            feeds: [
              '#dev'
            ]
          },
          'project with phid': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'Bug Report',
          bug: 'Bug Report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad feed bug to #dev', ->
        hubot 'phad feed bug to #dev'
        it 'should say that the feed is already there', ->
          expect(hubotResponse())
            .to.eql "The feed from 'Bug Report' to '#dev' already exist."

    context 'and the feed do not already exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            feeds: [ ]
          },
          'project with phid': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'Bug Report',
          bug: 'Bug Report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad feed bug to #dev', ->
        hubot 'phad feed bug to #dev'
        it 'should say that the feed was created', ->
          expect(hubotResponse())
            .to.eql "Ok, 'Bug Report' is now feeding '#dev'."
          expect(room.robot.brain.data.phabricator.projects['Bug Report'].feeds)
            .to.include '#dev'

  # ---------------------------------------------------------------------------------
  context 'user wants to remove a feed from a project', ->

    context 'and is project is unknown to phabricator', ->
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

      context 'phad remove project1 from #dev', ->
        hubot 'phad remove project1 from #dev'
        it 'should reply with proper info', ->
          expect(hubotResponse())
            .to.eql 'Sorry, project1 not found.'

    context 'and the feed exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            feeds: [
              '#dev'
            ]
          },
          'project with phid': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'Bug Report',
          bug: 'Bug Report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad remove bug from #dev', ->
        hubot 'phad remove bug from #dev'
        it 'should say that the feed was removed', ->
          expect(hubotResponse())
            .to.eql "Ok, The feed from 'Bug Report' to '#dev' was removed."
          expect(room.robot.brain.data.phabricator.projects['Bug Report'].feeds)
            .not.to.include '#dev'

    context 'but the feed do not already exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            feeds: [ ]
          },
          'project with phid': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'Bug Report',
          bug: 'Bug Report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad remove bug from #dev', ->
        hubot 'phad remove bug from #dev'
        it 'should say that the feed could not be removed', ->
          expect(hubotResponse())
            .to.eql "Sorry, 'Bug Report' is not feeding '#dev'."

  # ---------------------------------------------------------------------------------
  context 'permissions system', ->
    beforeEach ->
      process.env.HUBOT_AUTH_ADMIN = 'admin_user'
      room.robot.loadFile path.resolve('node_modules/hubot-auth/src'), 'auth.coffee'

      room.robot.brain.userForId 'admin_user', {
        name: 'admin_user',
        phid: 'PHID-USER-123456789'
      }
      room.robot.brain.userForId 'phadmin_user', {
        name: 'phadmin_user',
        phid: 'PHID-USER-123456789',
        roles: [
          'phadmin'
        ]
      }
      room.robot.brain.userForId 'phuser_user', {
        name: 'phuser_user',
        phid: 'PHID-USER-123456789',
        roles: [
          'phuser'
        ]
      }

    context 'user wants to create an alias for a project', ->
      context 'and user is admin', ->
        beforeEach ->
          room.robot.brain.data.phabricator.projects = {
            'Bug Report': { phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4' },
            'project with phid': { phid: 'PHID-PROJ-1234567' },
          }
          room.robot.brain.data.phabricator.aliases = {
            bugs: 'Bug Report',
            bug: 'Bug Report'
          }
          do nock.disableNetConnect

        afterEach ->
          room.robot.brain.data.phabricator = { }
          nock.cleanAll()

        context 'phad alias project with phid as pwp', ->
          hubot 'phad alias project with phid as pwp', 'admin_user'
          it 'should say that the alias was created', ->
            expect(hubotResponse())
              .to.eql "Ok, 'project with phid' will be known as 'pwp'."

      context 'and user is phadmin', ->
        beforeEach ->
          room.robot.brain.data.phabricator.projects = {
            'Bug Report': { phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4' },
            'project with phid': { phid: 'PHID-PROJ-1234567' },
          }
          room.robot.brain.data.phabricator.aliases = {
            bugs: 'Bug Report',
            bug: 'Bug Report'
          }
          do nock.disableNetConnect

        afterEach ->
          room.robot.brain.data.phabricator = { }
          nock.cleanAll()

        context 'phad alias project with phid as pwp', ->
          hubot 'phad alias project with phid as pwp', 'phadmin_user'
          it 'should say that the alias was created', ->
            expect(hubotResponse())
              .to.eql "Ok, 'project with phid' will be known as 'pwp'."

      context 'and user is phuser', ->
        beforeEach ->
          room.robot.brain.data.phabricator.projects = {
            'Bug Report': { phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4' },
            'project with phid': { phid: 'PHID-PROJ-1234567' },
          }
          room.robot.brain.data.phabricator.aliases = {
            bugs: 'Bug Report',
            bug: 'Bug Report'
          }
          do nock.disableNetConnect

        afterEach ->
          room.robot.brain.data.phabricator = { }
          nock.cleanAll()

        context 'phad alias project with phid as pwp', ->
          hubot 'phad alias project with phid as pwp', 'phuser_user'
          it 'warns the user that he has no permission to use that command', ->
            expect(hubotResponse())
              .to.eql "@phuser_user You don't have permission to do that."
