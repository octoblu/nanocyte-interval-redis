_ = require 'lodash'
debug = require('debug')('nanocyte-interval-redis:interval-controller')

class MessageController
  constructor: (options={}) ->
    {@intervalService} = options

  message: (req, res) =>
    debug 'message request body', req?.body
    switch req?.body?.topic
      when 'register-interval'   then @register req, res
      when 'register-cron'       then @register req, res
      when 'unregister-interval' then @unregister req, res
      when 'unregister-cron'     then @unregister req, res
      else res.status(501).end() if res

  register: (req, res) =>
    debug 'register', req?.body?.payload
    params = _.merge {}, req?.body?.payload, sendTo: req?.body?.fromUuid
    @intervalService.subscribe params
    res.status(201).end() if res

  unregister: (req, res) =>
    debug 'unregister', req?.body?.payload
    params = _.merge {}, req?.body?.payload, sendTo: req?.body?.fromUuid
    @intervalService.unsubscribe params
    res.status(201).end() if res

module.exports = MessageController
