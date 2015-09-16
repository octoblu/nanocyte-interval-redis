debug = require('debug')('interval-service')
cronParser = require 'cron-parser'

class MessagesController
  constructor: (options={}) ->
    {@intervalService} = options

  subscribeInterval: (req, res) =>
    @intervalService.subscribeTarget req.params.groupId, req.params.targetId, req.params.intervalTime ? 1000
    res.status(201).end() if res

  subscribeCron: (req, res) =>
    debug req.params.groupId, req.params.targetId, req.params.cron

    try
      nextCron = (cronParser.parseExpression req.params.cron).next()
      debug 'cron parser results:', (nextCron.getTime() - Date.now())/1000, 's on date', nextCron
      @intervalService.subscribeTarget(
        req.params.groupId,
        req.params.targetId,
        nextCron.getTime() - Date.now(),
        req.params.cron)

    catch err
      debug 'cron parser error:', err

    res.status(201).end() if res

  unsubscribe: (req, res) =>
    @intervalService.unsubscribeGroup req.params.groupId
    res.status(201).end() if res

module.exports = MessagesController
