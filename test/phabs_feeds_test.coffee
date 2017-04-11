require('es6-promise').polyfill()

Helper = require('hubot-test-helper')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs_feeds.coffee')
Phabricator = require '../lib/phabricator'

http        = require('http')
nock        = require('nock')
sinon       = require('sinon')
chai        = require('chai')
chai.use(require('sinon-chai'))
expect      = chai.expect
querystring = require('querystring')
room = null

# -------------------------------------------------------------------------------------------------
describe 'phabs_feeds commands', ->

  hubotEmit = (e, data, tempo = 40) ->
    beforeEach (done) ->
      room.robot.emit e, data
      setTimeout (done), tempo
 
  hubotHear = (message, userName = 'momo', tempo = 40) ->
    beforeEach (done) ->
      room.user.say userName, message
      setTimeout (done), tempo

  hubot = (message, userName = 'momo') ->
    hubotHear "@hubot #{message}", userName

  hubotResponse = (i = 1) ->
    room.messages[i]?[1]

  hubotResponseCount = ->
    room.messages?.length - 1

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
    room.robot.brain.data.phabricator.users['user_with_phid'] = {
      phid: 'PHID-USER-123456789',
      id: 'user_with_phid',
      name: 'user_with_phid'
    }
    room.robot.brain.data.phabricator.users['user_phab'] = {
      phid: 'PHID-USER-123456789',
      id: 'user_phab',
      name: 'user_phab'
    }
    room.receive = (userName, message) ->
      new Promise (resolve) =>
        @messages.push [userName, message]
        user = { name: userName, id: userName }
        @robot.receive(new Hubot.TextMessage(user, message), resolve)

  afterEach ->
    delete process.env.PHABRICATOR_URL
    delete process.env.PHABRICATOR_API_KEY
    delete process.env.PHABRICATOR_BOT_PHID

# -------------------------------------------------------------------------------------------------
describe 'phabs_feeds hook', ->

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
    process.env.PORT = 8088
    room = helper.createRoom()
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


  afterEach ->
    delete process.env.PHABRICATOR_URL
    delete process.env.PHABRICATOR_API_KEY
    delete process.env.PHABRICATOR_BOT_PHID

# -------------------------------------------------------------------------------------------------
  context 'it is not a task', ->
    beforeEach ->
      @postData = '{
        "storyID": "7373",
        "storyType": "PhabricatorApplicationTransactionFeedStory",
        "storyData": {
          "objectPHID": "PHID-PSTE-m4pqx64n2dtrwplk7qkh",
          "transactionPHIDs": {
            "PHID-XACT-PSTE-zmss7ubkaq5pzor": "PHID-XACT-PSTE-zmss7ubkaq5pzor"
          }
        },
        "storyAuthorPHID": "PHID-USER-7p4d4k6v4csqx7gcxcbw",
        "storyText": "ash created P6 new test paste.",
        "epoch": "1469408232"
      }'

    afterEach ->
      room.destroy()

    context 'and there is no feedall with everything enabled', ->
      it 'should not react', ->
        phab = new Phabricator room.robot, process.env
        phab.getFeed(JSON.parse(@postData))
          .then (announce) ->
            null
          .catch (e) ->
            expect(e).to.eql 'no room to announce in'

    context 'and there is a feedall but no feed_everything var', ->
      beforeEach ->
        room.robot.brain.data.phabricator.projects = {
          '*': {
            feeds: [
              'room1'
            ]
          }
        }
      afterEach ->
        room.robot.brain.data.phabricator = { }

      it 'should announce on the room', ->
        expected = {
          message: 'ash created P6 new test paste.',
          rooms: [ 'room1' ]
        }
        phab = new Phabricator room.robot, process.env
        phab.getFeed(JSON.parse(@postData))
          .then (announce) ->
            null
          .catch (e) ->
            expect(e).to.eql 'no room to announce in'

    context 'and there is a feedall but a disabled feed_everything var', ->
      beforeEach ->
        process.env.PHABRICATOR_FEED_EVERYTHING = '0'
        room.robot.brain.data.phabricator.projects = {
          '*': {
            feeds: [
              'room1'
            ]
          }
        }
      afterEach ->
        room.robot.brain.data.phabricator = { }
        delete process.env.PHABRICATOR_FEED_EVERYTHING

      it 'should announce on the room', ->
        expected = {
          message: 'ash created P6 new test paste.',
          rooms: [ 'room1' ]
        }
        phab = new Phabricator room.robot, process.env
        phab.getFeed(JSON.parse(@postData))
          .then (announce) ->
            null
          .catch (e) ->
            expect(e).to.eql 'no room to announce in'

    context 'and there is a feedall', ->
      beforeEach ->
        process.env.PHABRICATOR_FEED_EVERYTHING = '1'
        room.robot.brain.data.phabricator.projects = {
          '*': {
            feeds: [
              'room1'
            ]
          }
        }
      afterEach ->
        room.robot.brain.data.phabricator = { }
        delete process.env.PHABRICATOR_FEED_EVERYTHING

      it 'should announce on the room', ->
        expected = {
          message: 'ash created P6 new test paste.',
          rooms: [ 'room1' ]
        }
        phab = new Phabricator room.robot, process.env
        phab.getFeed(JSON.parse(@postData))
          .then (announce) ->
            expect(announce).to.eql expected

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  context 'it is a task but there is a problem contacting phabricator', ->
    beforeEach ->
      room.robot.brain.data.phabricator.projects = {
        'Bug Report': {
          phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
          feeds: [
            'room1'
          ]
        },
        'project with phid': { phid: 'PHID-PROJ-1234567' },
      }
      room.robot.brain.data.phabricator.aliases = {
        bugs: 'Bug Report',
        bug: 'Bug Report'
      }
      nock(process.env.PHABRICATOR_URL)
        .get('/api/maniphest.search')
        .query({
          'constraints[phids][0]': 'PHID-TASK-sx2g66opn67h4yfl7wk6',
          'attachments[projects]': '1',
          'api.token': 'xxx'
        })
        .reply(500, { error: { code: 500, message: 'oops' } })

      @postData = '{
        "storyID": "7297",
        "storyType": "PhabricatorApplicationTransactionFeedStory",
        "storyData": {
          "objectPHID": "PHID-TASK-sx2g66opn67h4yfl7wk6",
          "transactionPHIDs": {
            "PHID-XACT-TASK-fkyairn5ltzbzkj": "PHID-XACT-TASK-fkyairn5ltzbzkj",
            "PHID-XACT-TASK-dh5r5rtwa5hpfia": "PHID-XACT-TASK-dh5r5rtwa5hpfia"
          }
        },
        "storyAuthorPHID": "PHID-USER-qzoqvowxnb5k5screlji",
        "storyText": "mose triaged T2569: setup webhooks as High priority.",
        "epoch": "1469085410"
      }'

    afterEach ->
      room.robot.brain.data.phabricator = { }
      room.destroy()

    it 'should not react', ->
      expected = { }
      phab = new Phabricator room.robot, process.env
      phab.getFeed(JSON.parse(@postData))
        .then (announce) ->
          expect(announce).to.eql expected
        .catch (e) ->
          expect(e).to.eql 'http error 500'

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  context 'it is a task but is not in any feed', ->
    beforeEach ->
      room.robot.brain.data.phabricator.projects = {
        'Bug Report': {
          phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
          feeds: [
            'room1'
          ]
        },
        'project with phid': { phid: 'PHID-PROJ-1234567' },
      }
      room.robot.brain.data.phabricator.aliases = {
        bugs: 'Bug Report',
        bug: 'Bug Report'
      }
      nock(process.env.PHABRICATOR_URL)
        .get('/api/maniphest.search')
        .query({
          'constraints[phids][0]': 'PHID-TASK-sx2g66opn67h4yfl7wk6',
          'attachments[projects]': '1',
          'api.token': 'xxx'
        })
        .reply(200, { result: {
          'data': [
            {
              'id': 2569,
              'type': 'TASK',
              'phid': 'PHID-TASK-sx2g66opn67h4yfl7wk6',
              'fields': {
                'name': 'setup webhooks',
                'authorPHID': 'PHID-USER-7p4d4k6v4csqx7gcxcbw',
                'ownerPHID': 'PHID-USER-bniykos45qldfh7yumsl',
                'status': {
                  'value': 'resolved',
                  'name': 'Resolved',
                  'color': null
                },
                'priority': {
                  'value': 50,
                  'subpriority': 0,
                  'name': 'Normal',
                  'color': 'orange'
                },
                'points': null,
                'spacePHID': null,
                'dateCreated': 1468489192,
                'dateModified': 1469210692,
                'policy': {
                  'view': 'users',
                  'edit': 'users'
                }
              },
              'attachments': {
                'projects': {
                  'projectPHIDs': [
                    'PHID-PROJ-ccjxd4xuv22sngpwrhql'
                  ]
                }
              }
            }
          ],
          'maps': { },
          'query': {
            'queryKey': 'XQHShcroSRib'
          },
          'cursor': {
            'limit': 100,
            'after': null,
            'before': null,
            'order': null
          }
        } })

      @postData = '{
        "storyID": "7297",
        "storyType": "PhabricatorApplicationTransactionFeedStory",
        "storyData": {
          "objectPHID": "PHID-TASK-sx2g66opn67h4yfl7wk6",
          "transactionPHIDs": {
            "PHID-XACT-TASK-fkyairn5ltzbzkj": "PHID-XACT-TASK-fkyairn5ltzbzkj",
            "PHID-XACT-TASK-dh5r5rtwa5hpfia": "PHID-XACT-TASK-dh5r5rtwa5hpfia"
          }
        },
        "storyAuthorPHID": "PHID-USER-qzoqvowxnb5k5screlji",
        "storyText": "mose triaged T2569: setup webhooks as High priority.",
        "epoch": "1469085410"
      }'

    afterEach ->
      room.robot.brain.data.phabricator = { }
      room.destroy()

    it 'should not react', ->
      expected = {
        message: 'mose triaged T2569: setup webhooks as High priority.',
        rooms: [ ]
      }
      phab = new Phabricator room.robot, process.env
      phab.getFeed(JSON.parse(@postData))
        .then (announce) ->
          expect(announce).to.eql expected

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  context 'it is a task and it is in one feed', ->
    beforeEach ->
      room.robot.brain.data.phabricator.projects = {
        'Bug Report': {
          phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
          feeds: [
            'room1'
          ]
        },
        'project with phid': { phid: 'PHID-PROJ-1234567' },
      }
      room.robot.brain.data.phabricator.aliases = {
        bugs: 'Bug Report',
        bug: 'Bug Report'
      }
      nock(process.env.PHABRICATOR_URL)
        .get('/api/maniphest.search')
        .query({
          'constraints[phids][0]': 'PHID-TASK-sx2g66opn67h4yfl7wk6',
          'attachments[projects]': '1',
          'api.token': 'xxx'
        })
        .reply(200, { result: {
          'data': [
            {
              'id': 2569,
              'type': 'TASK',
              'phid': 'PHID-TASK-67wkenmryjcl66w3zioj',
              'fields': {
                'name': 'setup webhooks',
                'authorPHID': 'PHID-USER-7p4d4k6v4csqx7gcxcbw',
                'ownerPHID': 'PHID-USER-bniykos45qldfh7yumsl',
                'status': {
                  'value': 'resolved',
                  'name': 'Resolved',
                  'color': null
                },
                'priority': {
                  'value': 50,
                  'subpriority': 0,
                  'name': 'Normal',
                  'color': 'orange'
                },
                'points': null,
                'spacePHID': null,
                'dateCreated': 1468489192,
                'dateModified': 1469210692,
                'policy': {
                  'view': 'users',
                  'edit': 'users'
                }
              },
              'attachments': {
                'projects': {
                  'projectPHIDs': [
                    'PHID-PROJ-qhmexneudkt62wc7o3z4'
                  ]
                }
              }
            }
          ],
          'maps': { },
          'query': {
            'queryKey': 'XQHShcroSRib'
          },
          'cursor': {
            'limit': 100,
            'after': null,
            'before': null,
            'order': null
          }
        } })

      @postData = '{
        "storyID": "7297",
        "storyType": "PhabricatorApplicationTransactionFeedStory",
        "storyData": {
          "objectPHID": "PHID-TASK-sx2g66opn67h4yfl7wk6",
          "transactionPHIDs": {
            "PHID-XACT-TASK-fkyairn5ltzbzkj": "PHID-XACT-TASK-fkyairn5ltzbzkj",
            "PHID-XACT-TASK-dh5r5rtwa5hpfia": "PHID-XACT-TASK-dh5r5rtwa5hpfia"
          }
        },
        "storyAuthorPHID": "PHID-USER-qzoqvowxnb5k5screlji",
        "storyText": "mose triaged T2569: setup webhooks as High priority.",
        "epoch": "1469085410"
      }'

    afterEach ->
      room.robot.brain.data.phabricator = { }
      room.destroy()

    it 'should announce it to the appropriate room', ->
      expected = {
        message: 'mose triaged T2569: setup webhooks as High priority.',
        rooms: [ 'room1' ]
      }
      phab = new Phabricator room.robot, process.env
      phab.getFeed(JSON.parse(@postData))
        .then (announce) ->
          expect(announce).to.eql expected

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  context 'it is a task and it is in one parent feed', ->
    beforeEach ->
      room.robot.brain.data.phabricator.projects = {
        'Bug Report': {
          phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
          name: 'Bug Report',
          feeds: [
            'room1'
          ]
        },
        'project with phid': {
          phid: 'PHID-PROJ-1234567',
          name: 'project with phid',
          parent: 'Bug Report'
        },
      }
      room.robot.brain.data.phabricator.aliases = {
        bugs: 'Bug Report',
        bug: 'Bug Report'
      }
      nock(process.env.PHABRICATOR_URL)
        .get('/api/maniphest.search')
        .query({
          'constraints[phids][0]': 'PHID-TASK-sx2g66opn67h4yfl7wk6',
          'attachments[projects]': '1',
          'api.token': 'xxx'
        })
        .reply(200, { result: {
          'data': [
            {
              'id': 2569,
              'type': 'TASK',
              'phid': 'PHID-TASK-67wkenmryjcl66w3zioj',
              'fields': {
                'name': 'setup webhooks',
                'authorPHID': 'PHID-USER-7p4d4k6v4csqx7gcxcbw',
                'ownerPHID': 'PHID-USER-bniykos45qldfh7yumsl',
                'status': {
                  'value': 'resolved',
                  'name': 'Resolved',
                  'color': null
                },
                'priority': {
                  'value': 50,
                  'subpriority': 0,
                  'name': 'Normal',
                  'color': 'orange'
                },
                'points': null,
                'spacePHID': null,
                'dateCreated': 1468489192,
                'dateModified': 1469210692,
                'policy': {
                  'view': 'users',
                  'edit': 'users'
                }
              },
              'attachments': {
                'projects': {
                  'projectPHIDs': [
                    'PHID-PROJ-1234567'
                  ]
                }
              }
            }
          ],
          'maps': { },
          'query': {
            'queryKey': 'XQHShcroSRib'
          },
          'cursor': {
            'limit': 100,
            'after': null,
            'before': null,
            'order': null
          }
        } })

      @postData = '{
        "storyID": "7297",
        "storyType": "PhabricatorApplicationTransactionFeedStory",
        "storyData": {
          "objectPHID": "PHID-TASK-sx2g66opn67h4yfl7wk6",
          "transactionPHIDs": {
            "PHID-XACT-TASK-fkyairn5ltzbzkj": "PHID-XACT-TASK-fkyairn5ltzbzkj",
            "PHID-XACT-TASK-dh5r5rtwa5hpfia": "PHID-XACT-TASK-dh5r5rtwa5hpfia"
          }
        },
        "storyAuthorPHID": "PHID-USER-qzoqvowxnb5k5screlji",
        "storyText": "mose triaged T2569: setup webhooks as High priority.",
        "epoch": "1469085410"
      }'

    afterEach ->
      room.robot.brain.data.phabricator = { }
      room.destroy()

    it 'should announce it to the appropriate room', ->
      expected = {
        message: 'mose triaged T2569: setup webhooks as High priority.',
        rooms: [ 'room1' ]
      }
      phab = new Phabricator room.robot, process.env
      phab.getFeed(JSON.parse(@postData))
        .then (announce) ->
          expect(announce).to.eql expected

  # ---------------------------------------------------------------------------------
  context 'test the http responses', ->
    beforeEach ->
      room.robot.logger = sinon.spy()
      room.robot.logger.debug = sinon.spy()

    afterEach ->
      room.destroy()

    context 'with invalid payload', ->
      beforeEach (done) ->
        do nock.enableNetConnect
        options = {
          host: 'localhost',
          port: process.env.PORT,
          path: '/hubot/phabs/feeds',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          }
        }
        data = querystring.stringify({ })
        req = http.request options, (@response) => done()
        req.write(data)
        req.end()

      it 'responds with status 422', ->
        expect(@response.statusCode).to.equal 422

    context 'with valid payload', ->
      beforeEach (done) ->
        do nock.enableNetConnect
        options = {
          host: 'localhost',
          port: process.env.PORT,
          path: '/hubot/phabs/feeds',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          }
        }
        data = '{ "storyID": "1", "storyData": { "objectPHID": "PHID-TASK-12" }}'
        req = http.request options, (@response) => done()
        req.write(data)
        req.end()
        room.robot.brain.data.phabricator.projects = {
          'Bug Report': {
            phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
            feeds: [
              'room1'
            ]
          },
          'project with phid': { phid: 'PHID-PROJ-1234567' },
        }
        room.robot.brain.data.phabricator.aliases = {
          bugs: 'Bug Report',
          bug: 'Bug Report'
        }
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.search')
          .query({
            'constraints[phids][0]': 'PHID-TASK-12',
            'attachments[projects]': '1',
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            'data': [
              {
                'id': 2569,
                'type': 'TASK',
                'phid': 'PHID-TASK-12',
                'fields': {
                  'name': 'setup webhooks',
                  'authorPHID': 'PHID-USER-7p4d4k6v4csqx7gcxcbw',
                  'ownerPHID': 'PHID-USER-bniykos45qldfh7yumsl',
                  'status': {
                    'value': 'resolved',
                    'name': 'Resolved',
                    'color': null
                  }
                },
                'attachments': {
                  'projects': {
                    'projectPHIDs': [
                      'PHID-PROJ-1234567'
                    ]
                  }
                }
              }
            ],
            'maps': { },
            'query': {
              'queryKey': 'XQHShcroSRib'
            },
            'cursor': {
              'limit': 100,
              'after': null,
              'before': null,
              'order': null
            }
          } })

      afterEach ->
        room.robot.brain.data.phabricator = { }

      it 'responds with status 200', ->
        expect(@response.statusCode).to.equal 200
