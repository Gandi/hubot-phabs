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
    room.robot.logger = sinon.spy()
    room.robot.logger.warning = sinon.stub()
    room.robot.logger.debug = sinon.stub()
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
          '*': { },
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
        room.robot.brain.data.phabricator.aliases = {
          'p1': 'project1'
        }

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
          expect(room.robot.brain.data.phabricator.aliases['p1'])
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
            'project': { phid: 'PHID-PROJ-1234567' },
          }
          room.robot.brain.data.phabricator.aliases = {
            bugs: 'project',
            bug: 'project'
          }
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/project.search')
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
              .to.eql 'Sorry, tag \'unknown\' not found.'

      context 'and is unknown to phabricator but name returns results', ->
        beforeEach ->
          room.robot.brain.data.phabricator.projects = {
            'Bug Report': { },
            'project': { phid: 'PHID-PROJ-1234567' },
          }
          room.robot.brain.data.phabricator.aliases = {
            bugs: 'project',
            bug: 'project'
          }
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/project.search')
            .query({
              'names[0]': 'project1',
              'api.token': 'xxx'
            })
            .reply(200, { result: {
              'data': [
                {
                  'id': '1402',
                  'phid': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                  'fields': {
                    'name': 'Bug Report 2',
                    'parent': {
                      'id': 42,
                      'phid': 'PHID-PROJ-1234',
                      'name': 'parent-project'
                    }
                  }
                }
              ]
            } })

        afterEach ->
          room.robot.brain.data.phabricator = { }
          nock.cleanAll()

        context 'phad info unknown', ->
          hubot 'phad info unknown'
          it 'should reply with proper info', ->
            expect(hubotResponse())
              .to.eql 'Sorry, tag \'unknown\' not found.'

      context 'and is known to phabricator', ->
        beforeEach ->
          room.robot.brain.data.phabricator.projects = {
            'project': { phid: 'PHID-PROJ-1234567' },
          }
          room.robot.brain.data.phabricator.aliases = {
            bugs: 'project',
            bug: 'project'
          }
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/project.search')
            .query({
              'names[0]': 'project1',
              'api.token': 'xxx'
            })
            .reply(200, { result: {
              'data': [
                {
                  'id': '1402',
                  'phid': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                  'fields': {
                    'name': 'Bug Report',
                    'parent': {
                      'id': 42,
                      'phid': 'PHID-PROJ-1234567',
                      'name': 'project'
                    }
                  }
                }
              ]
            } })
            .get('/api/maniphest.query')
            .query({
              'projectPHIDs[0]': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
              'status': 'status-any',
              'order': 'order-modified'
            })
            .reply(200, { result: {
              '1': { id: '1' },
              '2': { id: '2' },
              '3': { id: '3' }
            } })
            .get('/api/maniphest.gettasktransactions')
            .reply(200, { result: {
              trans1: [{
                transactionType: 'core:columns',
                newValue: [
                  {
                    boardPHID: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                    columnPHID: 'PHID-PCOL-ikeu5quydkkw55cqlbmx'
                  }
                ]
              }]
            } })
            .get('/api/phid.lookup')
            .reply(200, { result: { } })


        afterEach ->
          room.robot.brain.data.phabricator = { }
          nock.cleanAll()

        context 'phad info Bug Report', ->
          hubot 'phad info Bug Report'
          it 'should reply with proper info', ->
            expect(hubotResponse())
              .to.eql "'Bug Report' is 'project/Bug Report' " +
                      '(aka project_bug_report), ' +
                      'with no feed, and no columns (child of project).'
          it 'should remember the phid from asking to phabricator', ->
            expect(room.robot.brain.data.phabricator.projects['project/Bug Report'].phid)
              .to.eql 'PHID-PROJ-qhmexneudkt62wc7o3z4'
            expect(room.robot.brain.data.phabricator.projects['project/Bug Report'].parent)
              .to.eql 'project'

        context 'phad info parent-project / Bug Report', ->
          hubot 'phad info parent-project / Bug Report'
          it 'should reply with proper info', ->
            expect(hubotResponse())
              .to.eql 'Parent project parent-project not found. Please .phad info parent-project'

        context 'phad info project / Bug Report', ->
          hubot 'phad info project / Bug Report'
          it 'should reply with proper info', ->
            expect(hubotResponse())
              .to.eql "'project / Bug Report' is 'project/Bug Report' " +
                      '(aka project_bug_report), ' +
                      'with no feed, and no columns (child of project).'
          it 'should remember the phid from asking to phabricator', ->
            expect(room.robot.brain.data.phabricator.projects['project/Bug Report'].phid)
              .to.eql 'PHID-PROJ-qhmexneudkt62wc7o3z4'
            expect(room.robot.brain.data.phabricator.projects['project/Bug Report'].parent)
              .to.eql 'project'

        context 'phad info project/Bug Report', ->
          hubot 'phad info project/Bug Report'
          it 'should reply with proper info', ->
            expect(hubotResponse())
              .to.eql "'project/Bug Report' is 'project/Bug Report' " +
                      '(aka project_bug_report), ' +
                      'with no feed, and no columns (child of project).'
          it 'should remember the phid from asking to phabricator', ->
            expect(room.robot.brain.data.phabricator.projects['project/Bug Report'].phid)
              .to.eql 'PHID-PROJ-qhmexneudkt62wc7o3z4'
            expect(room.robot.brain.data.phabricator.projects['project/Bug Report'].parent)
              .to.eql 'project'

        context 'phad info bugs /Bug Report', ->
          hubot 'phad info bugs /Bug Report'
          it 'should reply with proper info', ->
            expect(hubotResponse())
              .to.eql "'bugs /Bug Report' is 'project/Bug Report' " +
                      '(aka project_bug_report), ' +
                      'with no feed, and no columns (child of project).'
          it 'should remember the phid from asking to phabricator', ->
            expect(room.robot.brain.data.phabricator.projects['project/Bug Report'].phid)
              .to.eql 'PHID-PROJ-qhmexneudkt62wc7o3z4'
            expect(room.robot.brain.data.phabricator.projects['project/Bug Report'].parent)
              .to.eql 'project'


      context 'and is known to phabricator', ->
        beforeEach ->
          room.robot.brain.data.phabricator.projects = {
            'project': { phid: 'PHID-PROJ-1234567' },
          }
          room.robot.brain.data.phabricator.aliases = {
            bugs: 'project',
            bug: 'project'
          }
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/project.search')
            .query({
              'names[0]': 'project1',
              'api.token': 'xxx'
            })
            .reply(200, { result: {
              'data': [
                {
                  'id': '1402',
                  'phid': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                  'fields': {
                    'name': 'Bug Report',
                  }
                }
              ]
            } })
            .get('/api/maniphest.query')
            .query({
              'projectPHIDs[0]': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
              'status': 'status-any',
              'order': 'order-modified'
            })
            .reply(200, { result: {
              'PHID-TASK-llyghhtxzgc25wbsn7lk': {
                'id': '12',
                'phid': 'PHID-TASK-llyghhtxzgc25wbsn7lk'
              },
              'PHID-TASK-lnpaaqlyvkuar5yf7qk6': {
                'id': '13',
                'phid': 'PHID-TASK-lnpaaqlyvkuar5yf7qk6'
              }
            } })
            .get('/api/maniphest.gettasktransactions')
            .query({
              'ids[]': [ 12, 13 ]
            })
            .reply(200, { result: {
              '12': [
                {
                  'taskID': '12',
                  'transactionType': 'status',
                  'oldValue': 'open',
                  'newValue': 'resolved'
                },
                {
                  'taskID': '12',
                  'transactionType': 'core:columns',
                  'oldValue': null,
                  'newValue': [
                    {
                      'boardPHID': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                      'columnPHID': 'PHID-PCOL-ikeu5quydkkw55cqlbmx'
                    }
                  ]
                }
              ],
              '13': [
                {
                  'taskID': '13',
                  'transactionType': 'status',
                  'oldValue': 'open',
                  'newValue': 'resolved'
                },
                {
                  'taskID': '13',
                  'transactionType': 'core:columns',
                  'oldValue': null,
                  'newValue': [
                    {
                      'boardPHID': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                      'columnPHID': 'PHID-PCOL-ikeu5quydkkw55cqlb00'
                    }
                  ]
                }
              ]
            } })
            .get('/api/phid.lookup')
            .query({
              'names[]': [
                'PHID-PCOL-ikeu5quydkkw55cqlbmx',
                'PHID-PCOL-ikeu5quydkkw55cqlb00'
              ]
            })
            .reply(200, { result: {
              'PHID-PCOL-ikeu5quydkkw55cqlbmx': {
                'phid': 'PHID-PCOL-ikeu5quydkkw55cqlbmx',
                'name': 'Back Log'
              },
              'PHID-PCOL-ikeu5quydkkw55cqlb00': {
                'phid': 'PHID-PCOL-ikeu5quydkkw55cqlb00',
                'name': 'Done'
              }
             } })


        afterEach ->
          room.robot.brain.data.phabricator = { }
          nock.cleanAll()

        context 'phad info Bug Report', ->
          hubot 'phad info Bug Report'
          it 'should reply with proper info', ->
            expect(hubotResponse())
              .to.eql "'Bug Report' is 'Bug Report' (aka bug_report), " +
                      'with no feed, columns back_log, done.'
          it 'should remember the phid from asking to phabricator', ->
            expect(room.robot.brain.data.phabricator.projects['Bug Report'].phid)
              .to.eql 'PHID-PROJ-qhmexneudkt62wc7o3z4'
            expect(room.robot.brain.data.phabricator.projects['Bug Report'].columns.done)
              .to.eql 'PHID-PCOL-ikeu5quydkkw55cqlb00'

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    context 'when project has phid recorded, and aliases', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': {
            phid: 'PHID-PROJ-1234567',
            name: 'Bug Report'
          }
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'Bug Report',
          bug: 'Bug Report'
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.search')
          .query({
            'names[0]': 'project1',
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            'data': [
              {
                'id': '1402',
                'phid': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                'fields': {
                  'name': 'Bug Report',
                }
              }
            ]
          } })
          .get('/api/maniphest.query')
          .query({
            'projectPHIDs[0]': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            'status': 'status-any',
            'order': 'order-modified'
          })
          .reply(200, { result: {
            'PHID-TASK-llyghhtxzgc25wbsn7lk': {
              'id': '12',
              'phid': 'PHID-TASK-llyghhtxzgc25wbsn7lk'
            },
            'PHID-TASK-lnpaaqlyvkuar5yf7qk6': {
              'id': '13',
              'phid': 'PHID-TASK-lnpaaqlyvkuar5yf7qk6'
            }
          } })
          .get('/api/maniphest.gettasktransactions')
          .query({
            'ids[]': [ 12, 13 ]
          })
          .reply(200, { result: {
            '12': [
              {
                'taskID': '12',
                'transactionType': 'status',
                'oldValue': 'open',
                'newValue': 'resolved'
              },
              {
                'taskID': '12',
                'transactionType': 'core:columns',
                'oldValue': null,
                'newValue': [
                  {
                    'boardPHID': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                    'columnPHID': 'PHID-PCOL-ikeu5quydkkw55cqlbmx'
                  }
                ]
              }
            ],
            '13': [
              {
                'taskID': '13',
                'transactionType': 'status',
                'oldValue': 'open',
                'newValue': 'resolved'
              },
              {
                'taskID': '13',
                'transactionType': 'core:columns',
                'oldValue': null,
                'newValue': [
                  {
                    'boardPHID': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                    'columnPHID': 'PHID-PCOL-ikeu5quydkkw55cqlb00'
                  }
                ]
              }
            ]
          } })
          .get('/api/phid.lookup')
          .query({
            'names[]': [
              'PHID-PCOL-ikeu5quydkkw55cqlbmx',
              'PHID-PCOL-ikeu5quydkkw55cqlb00'
            ]
          })
          .reply(200, { result: {
            'PHID-PCOL-ikeu5quydkkw55cqlbmx': {
              'phid': 'PHID-PCOL-ikeu5quydkkw55cqlbmx',
              'name': 'Back Log'
            },
            'PHID-PCOL-ikeu5quydkkw55cqlb00': {
              'phid': 'PHID-PCOL-ikeu5quydkkw55cqlb00',
              'name': 'Done'
            }
           } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad refresh bugs', ->
        hubot 'phad refresh bugs'
        it 'should reply with proper info', ->
          expect(hubotResponse())
            .to.eql "'bugs' is 'Bug Report' (aka bugs, bug, bug_report), " +
                    'with no feed, columns back_log, done.'
        it 'should remember the phid from asking to phabricator', ->
          expect(room.robot.brain.data.phabricator.projects['Bug Report'].phid)
            .to.eql 'PHID-PROJ-qhmexneudkt62wc7o3z4'
          expect(room.robot.brain.data.phabricator.projects['Bug Report'].columns.done)
            .to.eql 'PHID-PCOL-ikeu5quydkkw55cqlb00'


    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    context 'when project has phid recorded, and aliases', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': { },
          'project': {
            phid: 'PHID-PROJ-1234567',
            name: 'project'
          },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'project',
          bug: 'project'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad info project', ->
        hubot 'phad info project'
        it 'should reply with proper info', ->
          expect(hubotResponse())
            .to.eql "'project' is 'project' (aka bugs, bug), " +
                    'with no feed, and no columns.'

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    context 'when project has phid recorded, and feeds', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': { },
          'project': {
            phid: 'PHID-PROJ-1234567',
            name: 'project',
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

      context 'phad info project', ->
        hubot 'phad info project'
        it 'should reply with proper info', ->
          expect(hubotResponse())
            .to.eql "'project' is 'project', with no alias, " +
                    'announced on #dev, and no columns.'

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    context 'when project has phid recorded, and aliases, and is called by an alias', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'bug report': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'bug report'
          },
          'project': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'bug report',
          bug: 'bug report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad info bug', ->
        hubot 'phad info bug'
        it 'should reply with proper info', ->
          expect(hubotResponse())
            .to.eql "'bug' is 'bug report' (aka bugs, bug), with no feed, and no columns."

  # ---------------------------------------------------------------------------------
  context 'user wants to create an alias for a project', ->

    context 'and is project is unknown to phabricator', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': { },
          'project': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'project',
          bug: 'project'
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.search')
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
            .to.eql 'Sorry, tag \'project1\' not found.'

    context 'when the alias already exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': { phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4' },
          'project': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'Bug Report',
          bug: 'Bug Report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad alias project as bug', ->
        hubot 'phad alias project as bug'
        it 'should say that the alias already exists', ->
          expect(hubotResponse())
            .to.eql "The alias 'bug' already exists for project 'Bug Report'."


    context 'when the alias does not exists yet', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': { phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4' },
          'project': {
            phid: 'PHID-PROJ-1234567',
            name: 'project'
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

      context 'phad alias project as pwp', ->
        hubot 'phad alias project as pwp'
        it 'should say that the alias was created', ->
          expect(hubotResponse())
            .to.eql "Ok, 'project' will be known as 'pwp'."

  # ---------------------------------------------------------------------------------
  context 'user wants to remove an alias', ->

    context 'when the alias exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'Bug Report'
          },
          'project': { phid: 'PHID-PROJ-1234567' },
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
          'project': { phid: 'PHID-PROJ-1234567' },
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
          'project': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'project',
          bug: 'project'
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.search')
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
            .to.eql 'Sorry, tag \'project1\' not found.'

    context 'but the feed already exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'bug report': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'bug report',
            feeds: [
              '#dev'
            ]
          },
          'project': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'bug report',
          bug: 'bug report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad feed bug to #dev', ->
        hubot 'phad feed bug to #dev'
        it 'should say that the feed is already there', ->
          expect(hubotResponse())
            .to.eql "The feed from 'bug report' to '#dev' already exist."

    context 'and the feed do not already exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'bug report': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'bug report',
            feeds: [ ]
          },
          'project': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'bug report',
          bug: 'bug report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad feed bug to #dev', ->
        hubot 'phad feed bug to #dev'
        it 'should say that the feed was created', ->
          expect(hubotResponse())
            .to.eql "Ok, 'bug report' is now feeding '#dev'."
          expect(room.robot.brain.data.phabricator.projects['bug report'].feeds)
            .to.include '#dev'

  # ---------------------------------------------------------------------------------
  context 'user wants to add a catchall feed', ->

    context 'but the feed already exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          '*': {
            feeds: [
              '#dev'
            ]
          },
          'project': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'bug report',
          bug: 'bug report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad feedall to #dev', ->
        hubot 'phad feedall to #dev'
        it 'should say that the feed is already there', ->
          expect(hubotResponse())
            .to.eql "The catchall feed to '#dev' already exist."

    context 'and the feed do not already exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          '*': { }
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad feedall to #dev', ->
        hubot 'phad feedall to #dev'
        it 'should say that the feed was created', ->
          expect(hubotResponse())
            .to.eql "Ok, all feeds will be announced on '#dev'."
          expect(room.robot.brain.data.phabricator.projects['*'].feeds)
            .to.include '#dev'

  # ---------------------------------------------------------------------------------
  context 'user wants to remove a feed from a project', ->

    context 'and is project is unknown to phabricator', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': { },
          'project': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'project',
          bug: 'project'
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.search')
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
            .to.eql 'Sorry, tag \'project1\' not found.'

    context 'and phabricator reports an error', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': { },
          'project': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'project',
          bug: 'project'
        }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.search')
          .query({
            'names[0]': 'project1',
            'api.token': 'xxx'
          })
          .reply(500, { message: 'Internal error' })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad remove project1 from #dev', ->
        hubot 'phad remove project1 from #dev'
        it 'should reply with proper info', ->
          expect(hubotResponse())
            .to.eql 'http error 500'


    context 'and the feed exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'bug report': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'bug report',
            feeds: [
              '#dev'
            ]
          },
          'project': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'bug report',
          bug: 'bug report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad remove bug from #dev', ->
        hubot 'phad remove bug from #dev'
        it 'should say that the feed was removed', ->
          expect(hubotResponse())
            .to.eql "Ok, The feed from 'bug report' to '#dev' was removed."
          expect(room.robot.brain.data.phabricator.projects['bug report'].feeds)
            .not.to.include '#dev'

    context 'but the feed do not already exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          'bug report': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            name: 'bug report',
            feeds: [ ]
          },
          'project': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'bug report',
          bug: 'bug report'
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad remove bug from #dev', ->
        hubot 'phad remove bug from #dev'
        it 'should say that the feed could not be removed', ->
          expect(hubotResponse())
            .to.eql "Sorry, 'bug report' is not feeding '#dev'."

  # ---------------------------------------------------------------------------------
  context 'user wants to remove a catchall feed', ->

    context 'and the feed exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          '*': {
            feeds: [
              '#dev'
            ]
          },
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad removeall from #dev', ->
        hubot 'phad removeall from #dev'
        it 'should say that the feed was removed', ->
          expect(hubotResponse())
            .to.eql "Ok, The catchall feed to '#dev' was removed."
          expect(room.robot.brain.data.phabricator.projects['*'].feeds)
            .not.to.include '#dev'

    context 'but the feed do not already exists', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          '*': {
            feeds: [ ]
          },
        }
        do nock.disableNetConnect

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad removeall from #dev', ->
        hubot 'phad removeall from #dev'
        it 'should say that the feed could not be removed', ->
          expect(hubotResponse())
            .to.eql "Sorry, the catchall feed for '#dev' doesn't exist."

  # ---------------------------------------------------------------------------------
  context 'user wants to know the columns for a project', ->

    context 'but project never had any task', ->
      beforeEach ->
        room.robot.brain.data.phabricator = { }
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.search')
          .query({
            'names[0]': 'project1',
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            'data': [
              {
                'id': '1402',
                'phid': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                'fields': {
                  'name': 'project1',
                }
              }
            ]
          } })
          .get('/api/maniphest.query')
          .reply(200, { result: { } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad columns project1', ->
        hubot 'phad columns project1'
        it 'should say there is no task', ->
          expect(hubotResponse())
            .to.eql 'The project project1 has no columns.'
          expect(room.robot.logger.warning).calledTwice

    context 'but the tasks in that project never moved around', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/project.search')
          .query({
            'names[0]': 'project1',
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            'data': [
              {
                'id': '1402',
                'phid': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                'fields': {
                  'name': 'project1',
                }
              }
            ]
          } })
          .get('/api/maniphest.query')
          .reply(200, { result: {
            '1': { id: '1' },
            '2': { id: '2' },
            '3': { id: '3' }
          } })
          .get('/api/maniphest.gettasktransactions')
          .reply(200, { result: { } })

      afterEach ->
        room.robot.brain.data.phabricator = { }
        nock.cleanAll()

      context 'phad columns project1', ->
        hubot 'phad columns project1'
        it 'should say that tasks did not move', ->
          expect(hubotResponse())
            .to.eql 'The project project1 has no columns.'

    context 'and there is a way to get columns from existing tasks', ->
      context 'with a project name', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/project.search')
            .query({
              'names[0]': 'project1',
              'api.token': 'xxx'
            })
            .reply(200, { result: {
              'data': [
                {
                  'id': '1402',
                  'phid': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                  'fields': {
                    'name': 'project1',
                  }
                }
              ]
            } })
            .get('/api/maniphest.query')
            .query({
              'projectPHIDs[0]': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
              'status': 'status-any',
              'order': 'order-modified'
            })
            .reply(200, { result: {
              'PHID-TASK-llyghhtxzgc25wbsn7lk': {
                'id': '12',
                'phid': 'PHID-TASK-llyghhtxzgc25wbsn7lk'
              },
              'PHID-TASK-lnpaaqlyvkuar5yf7qk6': {
                'id': '13',
                'phid': 'PHID-TASK-lnpaaqlyvkuar5yf7qk6'
              }
            } })
            .get('/api/maniphest.gettasktransactions')
            .query({
              'ids[]': [ 12, 13 ]
            })
            .reply(200, { result: {
              '12': [
                {
                  'taskID': '12',
                  'transactionType': 'status',
                  'oldValue': 'open',
                  'newValue': 'resolved'
                },
                {
                  'taskID': '12',
                  'transactionType': 'core:columns',
                  'oldValue': null,
                  'newValue': [
                    {
                      'boardPHID': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                      'columnPHID': 'PHID-PCOL-ikeu5quydkkw55cqlbmx'
                    }
                  ]
                }
              ],
              '13': [
                {
                  'taskID': '13',
                  'transactionType': 'status',
                  'oldValue': 'open',
                  'newValue': 'resolved'
                },
                {
                  'taskID': '13',
                  'transactionType': 'core:columns',
                  'oldValue': null,
                  'newValue': [
                    {
                      'boardPHID': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                      'columnPHID': 'PHID-PCOL-ikeu5quydkkw55cqlb00'
                    }
                  ]
                }
              ]
            } })
            .get('/api/phid.lookup')
            .query({
              'names[]': [
                'PHID-PCOL-ikeu5quydkkw55cqlbmx',
                'PHID-PCOL-ikeu5quydkkw55cqlb00'
              ]
            })
            .reply(200, { result: {
              'PHID-PCOL-ikeu5quydkkw55cqlbmx': {
                'phid': 'PHID-PCOL-ikeu5quydkkw55cqlbmx',
                'name': 'Back Log'
              },
              'PHID-PCOL-ikeu5quydkkw55cqlb00': {
                'phid': 'PHID-PCOL-ikeu5quydkkw55cqlb00',
                'name': 'Done'
              }
             } })

        afterEach ->
          room.robot.brain.data.phabricator = { }
          nock.cleanAll()

        context 'phad columns project1', ->
          hubot 'phad columns project1'
          it 'should say ok', ->
            expect(hubotResponse())
              .to.eql 'Columns for project1: back_log, done'

      context 'with a project PHID', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/project.search')
            .query({
              'names[0]': 'project1',
              'api.token': 'xxx'
            })
            .reply(200, { result: {
              'data': [
                {
                  'id': '1402',
                  'phid': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                  'fields': {
                    'name': 'project1',
                  }
                }
              ]
            } })
            .get('/api/maniphest.query')
            .query({
              'projectPHIDs[0]': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
              'status': 'status-any',
              'order': 'order-modified'
            })
            .reply(200, { result: {
              'PHID-TASK-llyghhtxzgc25wbsn7lk': {
                'id': '12',
                'phid': 'PHID-TASK-llyghhtxzgc25wbsn7lk'
              },
              'PHID-TASK-lnpaaqlyvkuar5yf7qk6': {
                'id': '13',
                'phid': 'PHID-TASK-lnpaaqlyvkuar5yf7qk6'
              }
            } })
            .get('/api/maniphest.gettasktransactions')
            .query({
              'ids[]': [ 12, 13 ]
            })
            .reply(200, { result: {
              '12': [
                {
                  'taskID': '12',
                  'transactionType': 'status',
                  'oldValue': 'open',
                  'newValue': 'resolved'
                },
                {
                  'taskID': '12',
                  'transactionType': 'core:columns',
                  'oldValue': null,
                  'newValue': [
                    {
                      'boardPHID': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                      'columnPHID': 'PHID-PCOL-ikeu5quydkkw55cqlbmx'
                    }
                  ]
                }
              ],
              '13': [
                {
                  'taskID': '13',
                  'transactionType': 'status',
                  'oldValue': 'open',
                  'newValue': 'resolved'
                },
                {
                  'taskID': '13',
                  'transactionType': 'core:columns',
                  'oldValue': null,
                  'newValue': [
                    {
                      'boardPHID': 'PHID-PROJ-qhmexneudkt62wc7o3z4',
                      'columnPHID': 'PHID-PCOL-ikeu5quydkkw55cqlb00'
                    }
                  ]
                }
              ]
            } })
            .get('/api/phid.lookup')
            .query({
              'names[]': [
                'PHID-PCOL-ikeu5quydkkw55cqlbmx',
                'PHID-PCOL-ikeu5quydkkw55cqlb00'
              ]
            })
            .reply(200, { result: {
              'PHID-PCOL-ikeu5quydkkw55cqlbmx': {
                'phid': 'PHID-PCOL-ikeu5quydkkw55cqlbmx',
                'name': 'Back Log'
              },
              'PHID-PCOL-ikeu5quydkkw55cqlb00': {
                'phid': 'PHID-PCOL-ikeu5quydkkw55cqlb00',
                'name': 'Done'
              }
             } })

        afterEach ->
          room.robot.brain.data.phabricator = { }
          nock.cleanAll()

        context 'phad columns PHID-PROJ-qhmexneudkt62wc7o3z4', ->
          hubot 'phad columns PHID-PROJ-qhmexneudkt62wc7o3z4'
          it 'should say ok', ->
            expect(hubotResponse())
              .to.eql 'Columns for PHID-PROJ-qhmexneudkt62wc7o3z4: back_log, done'

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
            'project': {
              phid: 'PHID-PROJ-1234567',
              name: 'project'
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

        context 'phad alias project as pwp', ->
          hubot 'phad alias project as pwp', 'admin_user'
          it 'should say that the alias was created', ->
            expect(hubotResponse())
              .to.eql "Ok, 'project' will be known as 'pwp'."

      context 'and user is phadmin', ->
        beforeEach ->
          room.robot.brain.data.phabricator.projects = {
            'Bug Report': { phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4' },
            'project': {
              phid: 'PHID-PROJ-1234567',
              name: 'project'
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

        context 'phad alias project as pwp', ->
          hubot 'phad alias project as pwp', 'phadmin_user'
          it 'should say that the alias was created', ->
            expect(hubotResponse())
              .to.eql "Ok, 'project' will be known as 'pwp'."

      context 'and user is phuser', ->
        beforeEach ->
          room.robot.brain.data.phabricator.projects = {
            'Bug Report': { phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4' },
            'project': { phid: 'PHID-PROJ-1234567' },
          }
          room.robot.brain.data.phabricator.aliases = {
            bugs: 'Bug Report',
            bug: 'Bug Report'
          }
          do nock.disableNetConnect

        afterEach ->
          room.robot.brain.data.phabricator = { }
          nock.cleanAll()

        context 'phad del project', ->
          hubot 'phad del project', 'phuser_user'
          it 'warns the user that he has no permission to use that command', ->
            expect(hubotResponse())
              .to.eql "You don't have permission to do that."

        context 'phad forget project', ->
          hubot 'phad forget project', 'phuser_user'
          it 'warns the user that he has no permission to use that command', ->
            expect(hubotResponse())
              .to.eql "You don't have permission to do that."
