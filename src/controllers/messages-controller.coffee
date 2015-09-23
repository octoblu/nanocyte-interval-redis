debug = require('debug')('interval-service')
cronParser = require 'cron-parser'

class MessagesController
  constructor: (options={}) ->
    {@intervalService} = options

  subscribe: (req, res) =>
    debug 'subscribe', req.params
    {targetId} = req.params
    {repeat} = req.body.payload
    @intervalService.subscribeTarget targetId: targetId, intervalTime: repeat
    res.status(201).end() if res

  unsubscribe: (req, res) =>
    @intervalService.unsubscribeTarget req.params.targetId
    res.status(201).end() if res

module.exports = MessagesController
