cors = require 'cors'
morgan = require 'morgan'
express = require 'express'
bodyParser = require 'body-parser'
errorHandler = require 'errorhandler'
MeshbluConfig = require 'meshblu-config'
meshbluAuthDevice = require 'express-meshblu-auth-device'
meshbluHealthcheck = require 'express-meshblu-healthcheck'
IntervalService = require './src/services/interval-kue'
CronController = require './src/controllers/cron-controller'
IntervalController = require './src/controllers/interval-controller'

PORT  = process.env.PORT ? 80

intervalService = new IntervalService()
cronController = new CronController intervalService: intervalService
intervalController = new IntervalController intervalService: intervalService

meshbluJSON = new MeshbluConfig().toJSON()

app = express()
app.use cors()
app.use morgan 'dev'
app.use errorHandler()
app.use meshbluHealthcheck()
app.use meshbluAuthDevice meshbluJSON
app.use bodyParser.urlencoded limit: '50mb', extended : true
app.use bodyParser.json limit : '50mb'

app.post '/interval/:targetId', intervalController.create
app.post '/cron/:targetId/:cron', cronController.subscribe
app.delete '/:targetId', intervalController.destroy

server = app.listen PORT, ->
  host = server.address().address
  port = server.address().port

  console.log "Server running on #{host}:#{port}"
