_ = require 'lodash'
async = require 'async'
debug = require('debug')('nanocyte-interval-redis:interval-kue')
cronParser = require 'cron-parser'

class IntervalKue
  constructor: (dependencies={}) ->
    @REDIS_PORT        = process.env.REDIS_PORT ? 6379
    @REDIS_HOST        = process.env.REDIS_HOST ? 'localhost'

    @kue = dependencies.kue ? require 'kue'
    MeshbluMessage = dependencies.MeshbluMessage ? require '../meshblu-message'

    @queue = @kue.createQueue
      redis:
        port: @REDIS_PORT
        host: @REDIS_HOST

    @meshbluMessage = new MeshbluMessage

  pong: (params, callback) =>
    debug 'pong', JSON.stringify params
    @createPongJob params, callback

  subscribe: (params, callback) =>
    debug 'subscribe', JSON.stringify params
    return callback(new Error 'nodeId or sendTo not defined') unless params?.sendTo? && params?.nodeId?
    return callback(new Error 'noUnsubscribe should also set fireOnce') if params.noUnsubscribe and !params.fireOnce

    if !params.cronString && params.intervalTime < 1000
      return errorToMeshblu params, 'Minimum interval time is 1000ms', callback

    @createRegisterJob params, callback

  errorToMeshblu: (params, message, callback)=>
    @meshbluMessage.message [params.sendTo],
      topic: 'error'
      payload:
        from: params.nodeId
        message: message
        timestamp: _.now()
    return callback new Error(message)

  unsubscribe: (params, callback) =>
    debug 'unsubscribe', JSON.stringify params

    return callback new Error 'nodeId or sendTo not defined' unless params?.sendTo? && params?.nodeId?

    @createUnregisterJob params, callback

  createRegisterJob: (data, callback)=>
    job = @queue.create('register', data).
      removeOnComplete(true).
      save (error) =>
        callback error, job

  createPongJob: (data, callback)=>
    job = @queue.create('pong', data).
      removeOnComplete(true).
      save (error) =>
        callback error, job

  createUnregisterJob: (data, callback)=>
    job = @queue.create('register', data).
      removeOnComplete(true).
      save (error) =>
        callback error, job

module.exports = IntervalKue
