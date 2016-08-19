Helper = require('hubot-test-helper')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/phabs_api.coffee')
Phabricator = require '../lib/phabricator'

http        = require('http')
nock        = require('nock')
sinon       = require('sinon')
expect      = require('chai').use(require('sinon-chai')).expect
querystring = require('querystring')

room = null

describe 'phabs_api module', ->

  beforeEach ->
    process.env.PHABRICATOR_URL = 'http://example.com'
    process.env.PHABRICATOR_API_KEY = 'xxx'
    process.env.PHABRICATOR_BOT_PHID = 'PHID-USER-xxx'
    process.env.PORT = 8088
    room = helper.createRoom()

  afterEach ->
    delete process.env.PHABRICATOR_URL
    delete process.env.PHABRICATOR_API_KEY
    delete process.env.PHABRICATOR_BOT_PHID

  # ---------------------------------------------------------------------------------
  context 'test the http responses', ->
    afterEach ->
      room.destroy()

    context 'with invalid payload', ->
      beforeEach (done) ->
        do nock.enableNetConnect
        options = {
          host: 'localhost',
          port: process.env.PORT,
          path: '/hubot/phabs/api/someproject/task',
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
          path: '/hubot/phabs/api/bugs/task',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          }
        }
        data = '{ "title": "Some title" }'
        req = http.request options, (@response) => done()
        req.write(data)
        req.end()

      afterEach ->
        room.robot.brain.data.phabricator = { }

      it 'responds with status 200', ->
        expect(@response.statusCode).to.equal 200
