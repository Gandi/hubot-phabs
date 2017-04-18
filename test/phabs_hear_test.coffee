require('es6-promise').polyfill()

Helper = require('hubot-test-helper')
Hubot = require('../node_modules/hubot')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs_hear.coffee')

nock = require('nock')
sinon = require('sinon')
expect = require('chai').use(require('sinon-chai')).expect

room = null

describe 'phabs_hear module', ->

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
    process.env.PHABRICATOR_PROJECTS = 'PHID-PROJ-xxx:proj1,PHID-PCOL-yyy:proj2'
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
    delete process.env.PHABRICATOR_PROJECTS

  # ---------------------------------------------------------------------------------
  context 'someone talks about a task that is blacklisted', ->
    beforeEach ->
      do nock.disableNetConnect
      room.robot.brain.data.phabricator.blacklist = [ 'T42', 'V3' ]

    afterEach ->
      nock.cleanAll()
      room.robot.brain.data.phabricator.blacklist = [ ]

    context 'whatever about T42 or something', ->
      hubot 'whatever about T42 or something'
      it 'does not say anything', ->
        expect(hubotResponseCount()).to.eql 1
        expect(hubotResponse()).to.be.undefined

  # ---------------------------------------------------------------------------------
  context 'someone talks about a type of item that is disabled per configuration', ->
    beforeEach ->
      do nock.disableNetConnect
      process.env.PHABRICATOR_ENABLED_ITEMS = 'P,r'
      room = helper.createRoom { httpd: false }

    afterEach ->
      nock.cleanAll()
      delete process.env.PHABRICATOR_ENABLED_ITEMS
      room.robot.brain.data.phabricator.blacklist = [ ]

    context 'whatever about T42 or something', ->
      hubot 'whatever about T42 or something'
      it 'does not say anything', ->
        expect(hubotResponseCount()).to.eql 1
        expect(hubotResponse()).to.be.undefined

  # ---------------------------------------------------------------------------------
  context 'someone talks about a type of item but the hear is totaly disabled', ->
    beforeEach ->
      do nock.disableNetConnect
      process.env.PHABRICATOR_ENABLED_ITEMS = ''
      room = helper.createRoom { httpd: false }

    afterEach ->
      nock.cleanAll()
      delete process.env.PHABRICATOR_ENABLED_ITEMS
      room.robot.brain.data.phabricator.blacklist = [ ]

    context 'whatever about T42 or something', ->
      hubot 'whatever about T42 or something'
      it 'does not say anything', ->
        expect(hubotResponseCount()).to.eql 1
        expect(hubotResponse()).to.be.undefined

  # ---------------------------------------------------------------------------------
  context 'someone talks about a task', ->
    context 'when the task is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { error_info: 'No such Maniphest task exists.' })

      afterEach ->
        nock.cleanAll()

      context 'whatever about T424242 or something', ->
        hubot 'whatever about T424242 or something'
        it "warns the user that this Task doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops T424242 No such Maniphest task exists.'

    context 'when it is an open task', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            status: 'open',
            isClosed: false,
            title: 'some task',
            priority: 'Low',
            uri: 'http://example.com/T42'
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about T42 or something', ->
        hubot 'whatever about T42 or something'
        it "warns the user that this Task doesn't exist", ->
          expect(hubotResponse()).to.eql 'http://example.com/T42 - some task (Low)'
      context 'whatever about http://example.com/T42 or something', ->
        hubot 'whatever about http://example.com/T42 or something'
        it "warns the user that this Task doesn't exist", ->
          expect(hubotResponse()).to.eql 'T42 - some task (Low)'

    context 'when it is a closed task', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            status: 'resolved',
            isClosed: true,
            title: 'some task',
            priority: 'Low',
            uri: 'http://example.com/T42'
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about T42 or something', ->
        hubot 'whatever about T42 or something'
        it 'gives information about the Task, including uri', ->
          expect(hubotResponse()).to.eql 'http://example.com/T42 (resolved) - some task (Low)'
      context 'whatever about http://example.com/T42 or something', ->
        hubot 'whatever about http://example.com/T42 or something'
        it 'gives information about the Task, without uri', ->
          expect(hubotResponse()).to.eql 'T42 (resolved) - some task (Low)'


  # ---------------------------------------------------------------------------------
  context 'someone talks about a file', ->
    context 'when the file is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/file.info')
          .reply(200, { error_info: 'No such file exists.' })

      afterEach ->
        nock.cleanAll()

      context 'whatever about F424242 or something', ->
        hubot 'whatever about F424242 or something'
        it "warns the user that this File doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops F424242 No such file exists.'

    context 'when it is an existing file', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/file.info')
          .reply(200, { result: {
            name: 'image.png',
            mimeType: 'image/png',
            byteSize: '1409',
            uri: 'https://example.com/F42'
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about F42 or something', ->
        hubot 'whatever about F42 or something'
        it 'gives information about the File, including uri', ->
          expect(hubotResponse()).to.eql 'https://example.com/F42 - image.png (image/png 1.38 kB)'
      context 'whatever about http://example.com/F42 or something', ->
        hubot 'whatever about http://example.com/F42 or something'
        it 'gives information about the File, without uri', ->
          expect(hubotResponse()).to.eql 'F42 - image.png (image/png 1.38 kB)'

  # ---------------------------------------------------------------------------------
  context 'someone talks about a paste', ->
    context 'when the Paste is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/paste.query')
          .reply(200, { result: { } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about P424242 or something', ->
        hubot 'whatever about P424242 or something'
        it "warns the user that this Paste doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops P424242 was not found.'

    context 'when the request returns an error', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/paste.query')
          .reply(404, { message: 'not found' })

      afterEach ->
        nock.cleanAll()

      context 'whatever about P424242 or something', ->
        hubot 'whatever about P424242 or something'
        it "warns the user that this Paste doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops P424242 http error 404'

    context 'when it is an existing Paste without a language set', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/paste.query')
          .reply(200, { result: {
            'PHID-PSTE-hdxawtm6psdtsxy3nyzk': {
              title: 'file.coffee',
              language: '',
              uri: 'https://example.com/P42'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about P42 or something', ->
        hubot 'whatever about P42 or something'
        it 'gives information about the Paste, including uri', ->
          expect(hubotResponse()).to.eql 'https://example.com/P42 - file.coffee'
      context 'whatever about http://example.com/P42 or something', ->
        hubot 'whatever about http://example.com/P42 or something'
        it 'gives information about the Paste, without uri', ->
          expect(hubotResponse()).to.eql 'P42 - file.coffee'


    context 'when it is an existing Paste with a language set', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/paste.query')
          .reply(200, { result: {
            'PHID-PSTE-hdxawtm6psdtsxy3nyzk': {
              title: 'file.coffee',
              language: 'coffee',
              uri: 'https://example.com/P42'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about P42 or something', ->
        hubot 'whatever about P42 or something'
        it 'gives information about the Paste, including uri', ->
          expect(hubotResponse()).to.eql 'https://example.com/P42 - file.coffee (coffee)'
      context 'whatever about http://example.com/P42 or something', ->
        hubot 'whatever about http://example.com/P42 or something'
        it 'gives information about the Paste, without uri', ->
          expect(hubotResponse()).to.eql 'P42 - file.coffee (coffee)'

  # ---------------------------------------------------------------------------------
  context 'someone talks about a mock', ->
    context 'when the mock is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: { } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about M424242 or something', ->
        hubot 'whatever about M424242 or something'
        it "warns the user that this Mock doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops M424242 was not found.'

    context 'when the request returns an error', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(404, { message: 'not found' })

      afterEach ->
        nock.cleanAll()

      context 'whatever about M424242 or something', ->
        hubot 'whatever about M424242 or something'
        it "warns the user that this Paste doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops M424242 http error 404'


    context 'when it is an existing Mock without a status closed', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: {
            'M42': {
              'phid': 'PHID-MOCK-6g6p65ez5ctxudji5twy',
              'uri': 'https://example.com/M42',
              'typeName': 'Pholio Mock',
              'type': 'MOCK',
              'name': 'M42',
              'fullName': 'M42: Test Mock',
              'status': 'open'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about M42 or something', ->
        hubot 'whatever about M42 or something'
        it 'gives information about the mock, including uri', ->
          expect(hubotResponse()).to.eql 'https://example.com/M42 - Test Mock'
      context 'whatever about http://example.com/M42 or something', ->
        hubot 'whatever about http://example.com/M42 or something'
        it 'gives information about the mock, without uri', ->
          expect(hubotResponse()).to.eql 'M42: Test Mock'

    context 'when it is an existing Mock with a status closed', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: {
            'M42': {
              'phid': 'PHID-MOCK-6g6p65ez5ctxudji5twy',
              'uri': 'https://example.com/M42',
              'typeName': 'Pholio Mock',
              'type': 'MOCK',
              'name': 'M42',
              'fullName': 'M42: Test Mock',
              'status': 'closed'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about M42 or something', ->
        hubot 'whatever about M42 or something'
        it 'gives information about the mock, including uri', ->
          expect(hubotResponse()).to.eql 'https://example.com/M42 - Test Mock (closed)'
      context 'whatever about http://example.com/M42 or something', ->
        hubot 'whatever about http://example.com/M42 or something'
        it 'gives information about the mock, without uri', ->
          expect(hubotResponse()).to.eql 'M42: Test Mock (closed)'

  # ---------------------------------------------------------------------------------
  context 'someone talks about a build', ->
    context 'when the build is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: { } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about B424242 or something', ->
        hubot 'whatever about B424242 or something'
        it "warns the user that this build doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops B424242 was not found.'

    context 'when it is an existing build without a status closed', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: {
            'B12999': {
              'phid': 'PHID-HMBB-zeg6ru5vnd4fbp744s5f',
              'uri': 'https://example.com/B12999',
              'typeName': 'Buildable',
              'type': 'HMBB',
              'name': 'B12999',
              'fullName': 'B12999: rP46ceba728fee: (stable) Fix an issue',
              'status': 'open'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about B12999 or something', ->
        hubot 'whatever about B12999 or something'
        it 'gives information about the build, including uri', ->
          expect(hubotResponse())
            .to.eql 'https://example.com/B12999 - rP46ceba728fee: (stable) Fix an issue'
      context 'whatever about http://example.com/B12999 or something', ->
        hubot 'whatever about http://example.com/B12999 or something'
        it 'gives information about the build, without uri', ->
          expect(hubotResponse()).to.eql 'B12999: rP46ceba728fee: (stable) Fix an issue'

    context 'when it is an existing build with a status closed', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: {
            'B12999': {
              'phid': 'PHID-HMBB-zeg6ru5vnd4fbp744s5f',
              'uri': 'https://example.com/B12999',
              'typeName': 'Buildable',
              'type': 'HMBB',
              'name': 'B12999',
              'fullName': 'B12999: rP46ceba728fee: (stable) Fix an issue',
              'status': 'closed'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about B12999 or something', ->
        hubot 'whatever about B12999 or something'
        it 'gives information about the build, including uri', ->
          expect(hubotResponse())
            .to.eql 'https://example.com/B12999 - rP46ceba728fee: (stable) Fix an issue (closed)'
      context 'whatever about http://example.com/B12999 or something', ->
        hubot 'whatever about http://example.com/B12999 or something'
        it 'gives information about the build, without uri', ->
          expect(hubotResponse()).to.eql 'B12999: rP46ceba728fee: (stable) Fix an issue (closed)'

  # ---------------------------------------------------------------------------------
  context 'someone talks about a question', ->
    context 'when the question is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: { } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about Q424242 or something', ->
        hubot 'whatever about Q424242 or something'
        it "warns the user that this question doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops Q424242 was not found.'

    context 'when it is an existing question without a status closed', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: {
            'Q434': {
              'phid': 'PHID-QUES-j22mqmbhb3mbcd2it7zs',
              'uri': 'https://example.com/Q434',
              'typeName': 'Ponder Question',
              'type': 'QUES',
              'name': 'Q434',
              'fullName': 'Q434: Width in wiki pages',
              'status': 'open'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about Q434 or something', ->
        hubot 'whatever about Q434 or something'
        it 'gives information about the question, including uri', ->
          expect(hubotResponse()).to.eql 'https://example.com/Q434 - Width in wiki pages'
      context 'whatever about http://example.com/Q434 or something', ->
        hubot 'whatever about http://example.com/Q434 or something'
        it 'gives information about the question, without uri', ->
          expect(hubotResponse()).to.eql 'Q434: Width in wiki pages'

    context 'when it is an existing question with a status closed', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: {
            'Q434': {
              'phid': 'PHID-QUES-j22mqmbhb3mbcd2it7zs',
              'uri': 'https://example.com/Q434',
              'typeName': 'Ponder Question',
              'type': 'QUES',
              'name': 'Q434',
              'fullName': 'Q434: Width in wiki pages',
              'status': 'closed'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about Q434 or something', ->
        hubot 'whatever about Q434 or something'
        it 'gives information about the question, including uri', ->
          expect(hubotResponse()).to.eql 'https://example.com/Q434 - Width in wiki pages (closed)'
      context 'whatever about http://example.com/Q434 or something', ->
        hubot 'whatever about http://example.com/Q434 or something'
        it 'gives information about the question, without uri', ->
          expect(hubotResponse()).to.eql 'Q434: Width in wiki pages (closed)'

  # ---------------------------------------------------------------------------------
  context 'someone talks about a legalpad', ->
    context 'when the legalpad is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: { } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about L424242 or something', ->
        hubot 'whatever about L424242 or something'
        it "warns the user that this legalpad doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops L424242 was not found.'

    context 'when it is an existing legalpad without a status closed', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: {
            'L38': {
              'phid': 'PHID-LEGD-chmhkotszvqaucdrvh5t',
              'uri': 'https://example.com/L38',
              'typeName': 'Legalpad Document',
              'type': 'LEGD',
              'name': 'L38 Test',
              'fullName': 'L38 Test',
              'status': 'open'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about L38 or something', ->
        hubot 'whatever about L38 or something'
        it 'gives information about the legalpad, including uri', ->
          expect(hubotResponse()).to.eql 'https://example.com/L38 - Test'
      context 'whatever about http://example.com/L38 or something', ->
        hubot 'whatever about http://example.com/L38 or something'
        it 'gives information about the legalpad, without uri', ->
          expect(hubotResponse()).to.eql 'L38 Test'

    context 'when it is an existing legalpad with a status closed', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: {
            'L38': {
              'phid': 'PHID-LEGD-chmhkotszvqaucdrvh5t',
              'uri': 'https://example.com/L38',
              'typeName': 'Legalpad Document',
              'type': 'LEGD',
              'name': 'L38 Test',
              'fullName': 'L38 Test',
              'status': 'closed'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about L38 or something', ->
        hubot 'whatever about L38 or something'
        it 'gives information about the legalpad, including uri', ->
          expect(hubotResponse()).to.eql 'https://example.com/L38 - Test (closed)'
      context 'whatever about http://example.com/L38 or something', ->
        hubot 'whatever about http://example.com/L38 or something'
        it 'gives information about the legalpad, without uri', ->
          expect(hubotResponse()).to.eql 'L38 Test (closed)'

  # ---------------------------------------------------------------------------------
  context 'someone talks about a vote', ->
    context 'when the vote is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: { } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about V424242 or something', ->
        hubot 'whatever about V424242 or something'
        it "warns the user that this vote doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops V424242 was not found.'

    context 'when it is an existing vote without a status closed', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: {
            'V30': {
              'phid': 'PHID-POLL-hqztsdcva3jkucu4mmv2',
              'uri': 'https://example.com/V30',
              'typeName': 'Slowvote Poll',
              'type': 'POLL',
              'name': 'V30',
              'fullName': 'V30: This is a poll',
              'status': 'open'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about V30 or something', ->
        hubot 'whatever about V30 or something'
        it 'gives information about the vote, including uri', ->
          expect(hubotResponse()).to.eql 'https://example.com/V30 - This is a poll'
      context 'whatever about http://example.com/V30 or something', ->
        hubot 'whatever about http://example.com/V30 or something'
        it 'gives information about the vote, without uri', ->
          expect(hubotResponse()).to.eql 'V30: This is a poll'

    context 'when it is an existing vote with a status closed', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: {
            'V30': {
              'phid': 'PHID-POLL-hqztsdcva3jkucu4mmv2',
              'uri': 'https://example.com/V30',
              'typeName': 'Slowvote Poll',
              'type': 'POLL',
              'name': 'V30',
              'fullName': 'V30: This is a poll',
              'status': 'closed'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about V30 or something', ->
        hubot 'whatever about V30 or something'
        it 'gives information about the vote, including uri', ->
          expect(hubotResponse()).to.eql 'https://example.com/V30 - This is a poll (closed)'
      context 'whatever about http://example.com/V30 or something', ->
        hubot 'whatever about http://example.com/V30 or something'
        it 'gives information about the vote, without uri', ->
          expect(hubotResponse()).to.eql 'V30: This is a poll (closed)'

  # ---------------------------------------------------------------------------------
  context 'someone talks about a diff', ->
    context 'when the diff is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: { } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about D555555 or something', ->
        hubot 'whatever about D555555 or something'
        it "warns the user that this Diff doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops D555555 was not found.'

    context 'when it is an open diff', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: {
            'D55': {
              'phid': 'PHID-DREV-hqztsdcva3jkucu4mmv2',
              'uri': 'http://example.com/D55',
              'typeName': 'Differential Revision',
              'type': 'DREV',
              'name': 'D55',
              'fullName': 'D55: some diff',
              'status': 'open'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about D55 or something', ->
        hubot 'whatever about D55 or something'
        it "gives information about the open Diff, including uri", ->
          expect(hubotResponse()).to.eql 'http://example.com/D55 - some diff'
      context 'whatever about http://example.com/D55 or something', ->
        hubot 'whatever about http://example.com/D55 or something'
        it "gives information about the open Diff, without uri", ->
          expect(hubotResponse()).to.eql 'D55: some diff'

    context 'when it is a closed diff', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: {
            'D55': {
              'phid': 'PHID-DREV-hqztsdcva3jkucu4mmv2',
              'uri': 'http://example.com/D55',
              'typeName': 'Differential Revision',
              'type': 'DREV',
              'name': 'D55',
              'fullName': 'D55: some diff',
              'status': 'closed'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about D55 or something', ->
        hubot 'whatever about D55 or something'
        it 'gives information about the closed Diff, including uri', ->
          expect(hubotResponse()).to.eql 'http://example.com/D55 - some diff (closed)'
      context 'whatever about http://example.com/D55 or something', ->
        hubot 'whatever about http://example.com/D55 or something'
        it 'gives information about the closed Diff, without uri', ->
          expect(hubotResponse()).to.eql 'D55: some diff (closed)'

  # ---------------------------------------------------------------------------------
  context 'someone talks about a commit', ->
    context 'when the commit is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: { } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about rP156f7196453c or something', ->
        hubot 'whatever about rP156f7196453c or something'
        it "warns the user that this commit doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops rP156f7196453c was not found.'

    context 'when the request returns an error', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(404, { message: 'not found' })

      afterEach ->
        nock.cleanAll()

      context 'whatever about rTULIP156f7196453c or something', ->
        hubot 'whatever about rTULIP156f7196453c or something'
        it "warns the user that this Paste doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops rTULIP156f7196453c http error 404'

    context 'when it is an existing commit without a status closed', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: {
            'rTULIP156f7196453c': {
              'phid': 'PHID-CMIT-7dpynrtygtd7z3bv7f64',
              'uri': 'https://example.com/rP156f7196453c6612ee90f97e41bb9389e5d6ec0b',
              'typeName': 'Diffusion Commit',
              'type': 'CMIT',
              'name': 'rTULIP156f7196453c',
              'fullName': 'rTULIP156f7196453c: (stable) Promote 2016 Week 28',
              'status': 'open'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about rTULIP156f7196453c or something', ->
        hubot 'whatever about rTULIP156f7196453c or something'
        it 'gives information about the Paste, including uri', ->
          expect(hubotResponse())
            .to.eql 'https://example.com/rP156f7196453c6612ee90f97e41bb9389e5d6ec0b - ' +
                    '(stable) Promote 2016 Week 28'
      context 'whatever about http://example.com/rTULIP156f7196453c or something', ->
        hubot 'whatever about http://example.com/rTULIP156f7196453c or something'
        it 'gives information about the Paste, without uri', ->
          expect(hubotResponse()).to.eql 'rTULIP156f7196453c: (stable) Promote 2016 Week 28'

    context 'when it is an existing commit with a status closed', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/phid.lookup')
          .reply(200, { result: {
            'rTULIP156f7196453c': {
              'phid': 'PHID-CMIT-7dpynrtygtd7z3bv7f64',
              'uri': 'https://example.com/rP156f7196453c6612ee90f97e41bb9389e5d6ec0b',
              'typeName': 'Diffusion Commit',
              'type': 'CMIT',
              'name': 'rTULIP156f7196453c',
              'fullName': 'rTULIP156f7196453c: (stable) Promote 2016 Week 28',
              'status': 'closed'
            }
          } })

      afterEach ->
        nock.cleanAll()

      context 'whatever about rTULIP156f7196453c or something', ->
        hubot 'whatever about rTULIP156f7196453c or something'
        it 'gives information about the Paste, including uri', ->
          expect(hubotResponse())
            .to.eql 'https://example.com/rP156f7196453c6612ee90f97e41bb9389e5d6ec0b - ' +
                    '(stable) Promote 2016 Week 28 (closed)'
      context 'whatever about http://example.com/rTULIP156f7196453c or something', ->
        hubot 'whatever about http://example.com/rTULIP156f7196453c or something'
        it 'gives information about the Paste, without uri', ->
          expect(hubotResponse())
            .to.eql 'rTULIP156f7196453c: (stable) Promote 2016 Week 28 (closed)'
