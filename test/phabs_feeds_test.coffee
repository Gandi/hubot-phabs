require('es6-promise').polyfill()

Helper = require('hubot-test-helper')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs_feeds.coffee')

nock = require('nock')
sinon = require('sinon')
expect = require('chai').use(require('sinon-chai')).expect
http = require('http')

room = null

describe 'phabs_feeds module', ->

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

  # ---------------------------------------------------------------------------------
  context 'it is not a task', ->
    beforeEach (done) ->
      postData = '{
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
      room.robot.http('http://localhost:8080')
        .path('/Hubot/phabs/feeds')
        .post(postData) (err, res, payload) ->
          done()

    afterEach ->
      room.destroy()

    it 'should not react', ->
      expect(hubotResponseCount()).to.eql 0

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  context 'it is a task but is not in any feed', ->
    beforeEach (done) ->
      room.robot.brain.data.phabricator.projects = {
        'Bug Report': {
          phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
          feeds: [
            "room1"
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
          'maps': {},
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

      postData = '{
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
        "storyText": "mose triaged T2569: setup webhooks as \"High\" priority.",
        "epoch": "1469085410"
      }'
      room.robot.http('http://localhost:8080')
        .path('/Hubot/phabs/feeds')
        .post(postData) (err, res, payload) ->
          done()


    afterEach ->
      room.robot.brain.data.phabricator = { }
      room.destroy()

    it 'should not react', ->
      expect(hubotResponseCount()).to.eql 0

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  context 'it is a task and it is in one feed', ->
    beforeEach (done) ->
      room.robot.brain.data.phabricator.projects = {
        'Bug Report': {
          phid: 'PHID-PROJ-qhmexneudkt62wc7o3z4',
          feeds: [
            "room1"
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
          'maps': {},
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

      postData = '{
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
        "storyText": "mose triaged T2569: setup webhooks as \"High\" priority.",
        "epoch": "1469085410"
      }'
      room.robot.http('http://localhost:8080')
        .path('/Hubot/phabs/feeds')
        .post(postData) (err, res, payload) ->
          done()


    afterEach ->
      room.robot.brain.data.phabricator = { }
      room.destroy()

    it 'should announce it to the appropriate room', ->
      expect(hubotResponseCount()).to.eql 0
