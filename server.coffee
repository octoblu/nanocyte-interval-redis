cors = require 'cors'
morgan = require 'morgan'
express = require 'express'
bodyParser = require 'body-parser'
errorHandler = require 'errorhandler'
MeshbluConfig = require 'meshblu-config'
meshbluAuthDevice = require 'express-meshblu-auth-device'
meshbluHealthcheck = require 'express-meshblu-healthcheck'
intervalService = new (require './src/services/interval-kue')
messagesController = new (require './src/controllers/messages-controller') {intervalService:intervalService}

PORT  = process.env.PORT ? 80

meshbluJSON = new MeshbluConfig().toJSON()

app = express()
app.use cors()
app.use morgan 'dev'
app.use errorHandler()
app.use meshbluHealthcheck()
app.use meshbluAuthDevice meshbluJSON
app.use bodyParser.urlencoded limit: '50mb', extended : true
app.use bodyParser.json limit : '50mb'

app.post '/interval/:targetId', messagesController.subscribe
app.post '/cron/:targetId/:cron', messagesController.subscribe
app.delete '/:targetId', messagesController.unsubscribe

server = app.listen PORT, ->
  host = server.address().address
  port = server.address().port

  console.log "Server running on #{host}:#{port}"
