morgan = require 'morgan'
express = require 'express'
errorHandler = require 'errorhandler'
meshbluHealthcheck = require 'express-meshblu-healthcheck'
intervalService = new (require './src/services/interval-kue')
messagesController = new (require './src/controllers/messages-controller') {intervalService:intervalService}

PORT  = process.env.PORT ? 80

app = express()
app.use morgan 'dev'
app.use errorHandler()
app.use meshbluHealthcheck()

app.post '/interval/:targetId/:intervalTime', messagesController.subscribe
app.post '/cron/:targetId/:cron', messagesController.subscribe
app.delete '/:targetId', messagesController.unsubscribe

server = app.listen PORT, ->
  host = server.address().address
  port = server.address().port

  console.log "Server running on #{host}:#{port}"
