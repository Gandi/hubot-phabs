require('es6-promise').polyfill()

Helper = require('hubot-test-helper')
Hubot = require('../node_modules/hubot-test-helper/node_modules/hubot')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs.coffee')

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
    room.messages[i][1]

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
  context 'user wants to know hubot-phabs version', ->

    context 'phab version', ->
      hubot 'phab version'
      it 'should reply version number', ->
        expect(hubotResponse()).to.match /hubot-phabs module is version [0-9]+\.[0-9]+\.[0-9]+/

    context 'ph version', ->
      hubot 'ph version'
      it 'should reply version number', ->
        expect(hubotResponse()).to.match /hubot-phabs module is version [0-9]+\.[0-9]+\.[0-9]+/

  # ---------------------------------------------------------------------------------
  context 'user requests the list of known projects', ->

    context 'phab list projects', ->
      hubot 'phab list projects'
      it 'should reply the list of known projects according to PHABRICATOR_PROJECTS', ->
        expect(hubotResponseCount()).to.eql 2
        expect(hubotResponse()).to.eql 'Known Projects: proj1, proj2'

  # ---------------------------------------------------------------------------------
  context 'user asks for task info', ->

    context 'task id is provided', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .query({
            'task_id': 42,
            'api.token': 'xxx'
          })
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-42'
            } })
          .get('/api/user.query')
          .reply(200, { result: [{ userName: 'toto' }] })

      afterEach ->
        nock.cleanAll()

      context 'phab T42', ->
        hubot 'phab T42'
        it 'gives information about the task Txxx', ->
          expect(hubotResponse()).to.eql 'T42 has status open, priority Low, owner toto'

      context 'ph T42 # with an ending space', ->
        hubot 'ph T42 '
        it 'gives information about the task Txxx', ->
          expect(hubotResponse()).to.eql 'T42 has status open, priority Low, owner toto'

    context 'task id is provided but doesn not exist', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: { error_info: 'No such Maniphest task exists.' } })

      afterEach ->
        nock.cleanAll()

      context 'phab T42', ->
        hubot 'phab T42'
        it 'gives information about the task Txxx', ->
          expect(hubotResponse()).to.eql 'oops T42 No such Maniphest task exists.'


    context 'failed implicit re-use of the object id', ->
      context 'when user is known and his phid is in the brain', ->
        hubot 'ph', 'user_with_phid'
        it 'complains that there is no active object id in memory', ->
          expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

    context 'task id is provided, and owner is null', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: null
            } })
          .get('/api/user.query')
          .reply(200, { result: [{ userName: 'toto' }] })

      afterEach ->
        nock.cleanAll()

      context 'phab T42', ->
        hubot 'phab T42'
        it 'gives information about the task Txxx', ->
          expect(hubotResponse()).to.eql 'T42 has status open, priority Low, owner nobody'

    context 'task id is provided, and owner is set, but not in brain', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-000000'
            } })
          .get('/api/user.query')
          .reply(200, { result: [] })

      afterEach ->
        nock.cleanAll()

      context 'phab T42', ->
        hubot 'phab T42'
        it 'gives information about the task Txxx', ->
          expect(hubotResponse()).to.eql 'T42 has status open, priority Low, owner unknown'

  # ---------------------------------------------------------------------------------
  context 'user asks about a user', ->

    context 'phab toto', ->
      hubot 'phab toto'
      it 'warns when that user is unknown', ->
        expect(hubotResponse()).to.eql 'Sorry, I have no idea who toto is. Did you mistype it?'

    context 'phab user', ->
      hubot 'phab user'
      it 'warns when that user has no email', ->
        expect(hubotResponse()).to.eql "Sorry, I can't figure user email address. " +
                                       'Can you help me with .phab user = <email>'

    context 'user has an email', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.query')
          .reply(200, { result: [{ userName: 'user_with_email', phid: 'PHID-USER-999' }] })

      afterEach ->
        nock.cleanAll()

      context 'phab user_with_email', ->
        hubot 'phab user_with_email'
        it 'gets the phid for the user if he has an email', ->
          expect(hubotResponse()).to.eql "Hey I know user_with_email, he's PHID-USER-999"
          expect(room.robot.brain.userForId('user_with_email').phid).to.eql 'PHID-USER-999'

    context 'user has an email, but unknown to phabricator', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.query')
          .reply(200, { result: [] })

      afterEach ->
        nock.cleanAll()

      context 'phab user_with_email', ->
        hubot 'phab user_with_email'
        it 'gets a message complaining about the impossibility to match an email', ->
          expect(hubotResponse()).to.eql 'Sorry, I cannot find user@example.com :('

    context 'phab user_with_phid', ->
      hubot 'phab user_with_phid'
      it 'warns when that user has no email', ->
        expect(hubotResponse()).to.eql "Hey I know user_with_phid, he's PHID-USER-123456789"


  # ---------------------------------------------------------------------------------
  context 'user declares his own email', ->
    context 'phab me as momo@example.com', ->
      hubot 'phab me as momo@example.com'
      it 'says all is going to be fine', ->
        expect(hubotResponse()).to.eql "Okay, I'll remember your email is momo@example.com"
        expect(room.robot.brain.userForId('momo').email_address).to.eql 'momo@example.com'

  # ---------------------------------------------------------------------------------
  context 'user declares email for somebody else', ->
    context 'phab toto = toto@example.com', ->
      hubot 'phab toto = toto@example.com'
      it 'complains if the user is unknown', ->
        expect(hubotResponse()).to.eql 'Sorry I have no idea who toto is. Did you mistype it?'
    context 'phab user = user@example.com', ->
      hubot 'phab user = user@example.com'
      it 'sets the email for the user', ->
        expect(hubotResponse()).to.eql "Okay, I'll remember user email as user@example.com"
        expect(room.robot.brain.userForId('user').email_address).to.eql 'user@example.com'


  # ---------------------------------------------------------------------------------
  context 'user creates a new task', ->
    context 'phab new something blah blah', ->
      hubot 'phab new something blah blah'
      it 'fails to comply if the project is not registered by PHABRICATOR_PROJECTS', ->
        expect(hubotResponse()).to.eql 'Command incomplete.'

    context 'phab new proj1 a task', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 42 } } })

      afterEach ->
        nock.cleanAll()

      context 'when user is doing it for the first time and has no email recorded', ->
        hubot 'phab new proj1 a task'
        it 'invites the user to set his email address', ->
          expect(hubotResponse()).to.eql "Sorry, I can't figure out your email address :( " +
                                         'Can you tell me with `.phab me as you@yourdomain.com`?'
      context 'when user is doing it for the first time and has set an email addresse', ->
        hubot 'phab new proj1 a task', 'user_with_email'
        it 'replies with the object id, and records phid for user', ->
          expect(hubotResponse()).to.eql 'Task T42 created = http://example.com/T42'
          expect(room.robot.brain.userForId('user_with_email').phid).to.eql 'PHID-USER-42'
      context 'when user is known and his phid is in the brain', ->
        hubot 'phab new proj1 a task', 'user_with_phid'
        it 'replies with the object id', ->
          expect(hubotResponse()).to.eql 'Task T42 created = http://example.com/T42'

    context 'phab new proj1 a task', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { error_info: 'Something went wrong' } })

      afterEach ->
        nock.cleanAll()

      context 'when something goes wrong on phabricator side', ->
        hubot 'phab new proj1 a task', 'user_with_phid'
        it 'informs that something went wrong', ->
          expect(hubotResponse()).to.eql 'Something went wrong'


    context 'phab new proj2 a task', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 24 } } })

      afterEach ->
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab new proj2 a task', 'user_with_phid'
        it 'replies with the object id', ->
          expect(hubotResponse()).to.eql 'Task T24 created = http://example.com/T24'


    context 'implicit re-use of the object id', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/user.query')
          .reply(200, { result: [ { phid: 'PHID-USER-42' } ] })
          .get('/api/maniphest.edit')
          .reply(200, { result: { object: { id: 24 } } })
          .get('/api/maniphest.info')
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-123456789'
            } })

      afterEach ->
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab new proj2 a task', 'user_with_phid'
        hubot 'ph', 'user_with_phid'
        it 'replies with the object id', ->
          expect(hubotResponse(1)).to.eql 'Task T24 created = http://example.com/T24'
          expect(hubotResponse(3)).to.eql 'T24 has status open, priority Low, owner user_with_phid'

  # ---------------------------------------------------------------------------------
  context 'user asks to count tasks in a project or column', ->
    context 'phab count something', ->
      hubot 'phab count something'
      it 'fails to comply if the project is not registered by PHABRICATOR_PROJECTS', ->
        expect(hubotResponse()).to.eql 'Command incomplete.'

    context 'phab count proj1', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.query')
          .reply(200, { result: {
            'PHID-TASK-42': { id: 42 },
            'PHID-TASK-43': { id: 43 },
            'PHID-TASK-44': { id: 44 },
            } })

      afterEach ->
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab count proj1', 'user_with_phid'
        it 'replies with the unmber of tasks in the project', ->
          expect(hubotResponse()).to.eql 'proj1 has 3 tasks.'


    context 'phab count proj1', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.query')
          .reply(200, { result: { } })

      afterEach ->
        nock.cleanAll()

      context 'when user is known and his phid is in the brain', ->
        hubot 'phab count proj1', 'user_with_phid'
        it 'replies with the unmber of tasks in the project', ->
          expect(hubotResponse()).to.eql 'proj1 has no tasks.'

  # ---------------------------------------------------------------------------------
  context 'user changes status for a task', ->
    context 'when the task is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.update')
          .reply(200, { result: { error_info: 'No such Maniphest task exists.' } })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 is open', ->
        hubot 'phab T424242 is open'
        it "warns the user that this Task doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops T424242 No such Maniphest task exists.'

    context 'when the task is present', ->

      context 'phab open', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: {
            status: 'open',
            priority: 'Low',
            name: 'Test task',
            ownerPHID: 'PHID-USER-42'
            } })
          .get('/api/user.query')
          .reply(200, { result: [{ userName: 'toto' }] })
          .get('/api/maniphest.update')
          .reply(200, { result: { statusName: 'Open' } })

        afterEach ->
          nock.cleanAll()

        context 'phab is open', ->
          hubot 'phab T42', 'user_with_phid'
          hubot 'phab is open', 'user_with_phid'
          it 'reports the status as open', ->
            expect(hubotResponse(3)).to.eql 'Ok, T42 now has status Open.'

        context 'phab open', ->
          hubot 'phab T42', 'user_with_phid'
          hubot 'phab open', 'user_with_phid'
          it 'reports the status as open', ->
            expect(hubotResponse(3)).to.eql 'Ok, T42 now has status Open.'


      context 'phab T42 is open', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.update')
            .reply(200, { result: { statusName: 'Open' } })

        afterEach ->
          nock.cleanAll()

        context 'phab open', ->
          hubot 'phab open'
          it 'warns the user that there is no active task in memory', ->
            expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

        context 'phab T42 is open', ->
          hubot 'phab T42 is open'
          it 'reports the status as open', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status Open.'

      context 'phab T42 open', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.update')
            .reply(200, { result: { statusName: 'Open' } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 open', ->
          hubot 'phab T42 open'
          it 'reports the status as open', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status Open.'

      context 'phab T42 resolved', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.update')
            .reply(200, { result: { statusName: 'Resolved' } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 resolved', ->
          hubot 'phab T42 resolved'
          it 'reports the status as resolved', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status Resolved.'

      context 'phab T42 wontfix', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.update')
            .reply(200, { result: { statusName: 'Wontfix' } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 wontfix', ->
          hubot 'phab T42 wontfix'
          it 'reports the status as wontfix', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status Wontfix.'

      context 'phab T42 invalid', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.update')
            .reply(200, { result: { statusName: 'Invalid' } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 invalid', ->
          hubot 'phab T42 invalid'
          it 'reports the status as invalid', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status Invalid.'

      context 'phab T42 spite', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.update')
            .reply(200, { result: { statusName: 'Spite' } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 spite', ->
          hubot 'phab T42 spite'
          it 'reports the status as spite', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has status Spite.'

  # ---------------------------------------------------------------------------------
  context 'error: non json', ->
    beforeEach ->
      do nock.disableNetConnect
      nock(process.env.PHABRICATOR_URL)
        .get('/api/maniphest.update')
        .reply(200, '<body></body>', { 'Content-type': 'text/html' })

    afterEach ->
      nock.cleanAll()

    context 'phab T42 spite', ->
      hubot 'phab T42 spite'
      it 'reports an api error', ->
        expect(hubotResponse()).to.eql 'oops T42 api did not deliver json'

  context 'error: lib error', ->
    beforeEach ->
      do nock.disableNetConnect
      nock(process.env.PHABRICATOR_URL)
        .get('/api/maniphest.update')
        .replyWithError({ 'message': 'something awful happened', 'code': 'AWFUL_ERROR' })

    afterEach ->
      nock.cleanAll()

    context 'phab T42 spite', ->
      hubot 'phab T42 spite'
      it 'reports a lib error', ->
        expect(hubotResponse()).to.eql 'oops T42 something awful happened'

  context 'error: lib error', ->
    beforeEach ->
      do nock.disableNetConnect
      nock(process.env.PHABRICATOR_URL)
        .get('/api/maniphest.update')
        .reply(400)

    afterEach ->
      nock.cleanAll()

    context 'phab T42 spite', ->
      hubot 'phab T42 spite'
      it 'reports a http error', ->
        expect(hubotResponse()).to.eql 'oops T42 http error 400'

  # ---------------------------------------------------------------------------------
  context 'user changes priority for a task', ->
    context 'when the task is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.update')
          .reply(200, { result: { error_info: 'No such Maniphest task exists.' } })

      afterEach ->
        nock.cleanAll()

      context 'phab T424242 is low', ->
        hubot 'phab T424242 is low'
        it "warns the user that this Task doesn't exist", ->
          expect(hubotResponse()).to.eql 'oops T424242 No such Maniphest task exists.'

    context 'when the task is present', ->
  
      context 'phab T42 is broken', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.update')
            .reply(200, { result: { priority: 'Unbreak Now!' } })

        afterEach ->
          nock.cleanAll()

        context 'phab broken', ->
          hubot 'phab broken'
          it 'warns the user that there is no active task in memory', ->
            expect(hubotResponse()).to.eql "Sorry, you don't have any task active right now."

        context 'phab T42 is broken', ->
          hubot 'phab T42 is broken'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority Unbreak Now!'
        context 'phab T42 broken', ->
          hubot 'phab T42 broken'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority Unbreak Now!'
        context 'phab T42 unbreak', ->
          hubot 'phab T42 unbreak'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority Unbreak Now!'

  
      context 'phab T42 is none', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.update')
            .reply(200, { result: { priority: 'Needs Triage' } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 none', ->
          hubot 'phab T42 none'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority Needs Triage'
        context 'phab T42 unknown', ->
          hubot 'phab T42 unknown'
          it 'reports the priority to be Unbreak Now!', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority Needs Triage'

      context 'phab T42 is urgent', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.update')
            .reply(200, { result: { priority: 'High' } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 urgent', ->
          hubot 'phab T42 urgent'
          it 'reports the priority to be High', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority High'
        context 'phab T42 high', ->
          hubot 'phab T42 high'
          it 'reports the priority to be High', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority High'

      context 'phab T42 is normal', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.update')
            .reply(200, { result: { priority: 'Normal' } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 normal', ->
          hubot 'phab T42 normal'
          it 'reports the priority to be Normal', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority Normal'

      context 'phab T42 is low', ->
        beforeEach ->
          do nock.disableNetConnect
          nock(process.env.PHABRICATOR_URL)
            .get('/api/maniphest.update')
            .reply(200, { result: { priority: 'Low' } })

        afterEach ->
          nock.cleanAll()

        context 'phab T42 low', ->
          hubot 'phab T42 low'
          it 'reports the priority to be Low', ->
            expect(hubotResponse()).to.eql 'Ok, T42 now has priority Low'

  # ---------------------------------------------------------------------------------
  context 'user assigns someone to a task', ->
    context 'when the user is unknown', ->
      context 'phab assign T424242 to xxx', ->
        hubot 'phab assign T424242 to xxx'
        it 'warns the user that xx is unknown', ->
          expect(hubotResponse()).to.eql "Sorry I don't know who is xxx, " +
                                         'can you .phab xxx = <email>'
      context 'phab assign T424242 to momo', ->
        hubot 'phab assign T424242 to momo'
        it 'warns the user that his email is not known', ->
          expect(hubotResponse()).to.eql "Sorry, I can't figure out your email address :( " +
                                         'Can you tell me with `.phab me as you@yourdomain.com`?'

    context 'task is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.edit')
          .reply(200, { result: { error_info: 'No such Maniphest task exists.' } })

      afterEach ->
        nock.cleanAll()

      context 'phab assign T424242 to user_with_phid', ->
        hubot 'phab assign T424242 to user_with_phid'
        it 'warns the user that the task does not exist', ->
          expect(hubotResponse()).to.eql 'No such Maniphest task exists.'

    context 'task is known', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.edit')
          .reply(200, { result: { id: 42 } })

      afterEach ->
        nock.cleanAll()

      context 'phab assign T42 to user_with_phid', ->
        hubot 'phab assign T42 to user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to.eql 'Ok. T42 is now assigned to user_with_phid'

      context 'phab assign T42 on user_with_phid', ->
        hubot 'phab assign T42 on user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to.eql 'Ok. T42 is now assigned to user_with_phid'

      context 'phab T42 on user_with_phid', ->
        hubot 'phab T42 on user_with_phid'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to.eql 'Ok. T42 is now assigned to user_with_phid'

      context 'phab user_with_phid on T42', ->
        hubot 'phab user_with_phid on T42'
        it 'gives a feedback that the assignment went ok', ->
          expect(hubotResponse()).to.eql 'Ok. T42 is now assigned to user_with_phid'

  # ---------------------------------------------------------------------------------
  context 'someone talks about a task', ->
    context 'when the task is unknown', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/maniphest.info')
          .reply(200, { result: { error_info: 'No such Maniphest task exists.' } })

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
          .reply(200, { result: { error_info: 'No such file exists.' } })

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

    context 'when it is an existing Paste without a language set', ->
      beforeEach ->
        do nock.disableNetConnect
        nock(process.env.PHABRICATOR_URL)
          .get('/api/paste.query')
          .reply(200, { result: [{
            title: 'file.coffee',
            language: '',
            uri: 'https://example.com/P42'
          }] })

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
          .reply(200, { result: [{
            title: 'file.coffee',
            language: 'coffee',
            uri: 'https://example.com/P42'
          }] })

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
