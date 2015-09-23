debug = require('debug')('nanocyte-interval-redis:cron-controller')
cronParser = require 'cron-parser'

class CronController
  constructor: (options={}) ->
    {@intervalService} = options

  subscribe: (req, res) =>
    debug 'subscribe', req.params
    @intervalService.subscribeTarget req.params
    res.status(201).end() if res

  unsubscribe: (req, res) =>
    @intervalService.unsubscribeTarget req.params.targetId
    res.status(201).end() if res

module.exports = CronController
