debug = require('debug')('nanocyte-interval-redis:interval-controller')
cronParser = require 'cron-parser'

class IntervalController
  constructor: (options={}) ->
    {@intervalService} = options

  create: (req, res) =>
    debug 'create', req.params
    {targetId} = req.params
    {repeat} = req.body.payload
    @intervalService.subscribeTarget targetId: targetId, intervalTime: repeat
    res.status(201).end() if res

  destroy: (req, res) =>
    @intervalService.unsubscribeTarget req.params.targetId
    res.status(201).end() if res

module.exports = IntervalController
