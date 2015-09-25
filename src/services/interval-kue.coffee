_ = require 'lodash'
async = require 'async'
debug = require('debug')('interval-service')
cronParser = require 'cron-parser'

class IntervalKue
  constructor: (dependencies={}) ->
    @INTERVAL_TTL      = process.env.INTERVAL_TTL ? 10000
    @INTERVAL_ATTEMPTS = process.env.INTERVAL_ATTEMPTS ? 999
    @REDIS_PORT        = process.env.REDIS_PORT ? 6379
    @REDIS_HOST        = process.env.REDIS_HOST ? 'localhost'

    @kue = dependencies.kue ? require 'kue'
    IORedis = dependencies.IORedis ? require 'ioredis'
    @redis = new IORedis @REDIS_PORT, @REDIS_HOST

    @queue = @kue.createQueue
      redis:
        port: @REDIS_PORT
        host: @REDIS_HOST

  subscribe: (params, callback=->) =>
    debug 'subscribe', params
    return callback(new Error 'nodeId or sendTo not defined') if (!params?.sendTo?) or (!params?.nodeId?)

    jobDelay = if params.cronString then @calculateNextCronInterval params.cronString else 0

    @unsubscribe params, (err) =>
      debug 'called unsubscribe', err
      return callback err if err?
      @redis.mset
        "interval/active/#{params.sendTo}/#{params.nodeId}": true
        "interval/time/#{params.sendTo}/#{params.nodeId}": params.intervalTime
        "interval/cron/#{params.sendTo}/#{params.nodeId}": params.cronString

      @createJob {sendTo: params.sendTo, nodeId: params.nodeId}, jobDelay, (err, newJob) =>
          @redis.sadd "interval/job/#{params.sendTo}/#{params.nodeId}", newJob.id if !err?
          debug ' - created job', newJob.id, 'for', params.nodeId
          callback err

  unsubscribe: (params, callback=->) =>
    debug 'unsubscribe', params
    return callback(new Error 'nodeId or sendTo not defined') if (!params?.sendTo?) or (!params?.nodeId?)

    @redis.del "interval/active/#{params.sendTo}/#{params.nodeId}"
    @redis.del "interval/time/#{params.sendTo}/#{params.nodeId}"
    @redis.del "interval/cron/#{params.sendTo}/#{params.nodeId}"

    curryJob = (jobId, callback) => @removeJob(params, jobId, callback)
    @redis.smembers "interval/job/#{params.sendTo}/#{params.nodeId}", (err, jobIds) =>
      return callback err if err?
      async.each jobIds, curryJob, callback

  removeJob: (params, jobId, callback) =>
    debug 'removeJob', params, 'for jobId', jobId
    return callback(new Error 'jobId not defined') if !jobId?
    @redis.srem "interval/job/#{params.sendTo}/#{params.nodeId}", jobId
    @kue.Job.get jobId, (err, job) =>
      job.remove() if !err?
      callback err

  calculateNextCronInterval: (cronString, currentDate) =>
    currentDate ?= new Date
    timeDiff = 0
    parser = cronParser.parseExpression cronString, currentDate: currentDate

    while timeDiff <= 0
      nextDate = parser.next()
      nextDate.setMilliseconds 0
      timeDiff = nextDate - currentDate
      debug 'this is the next time', timeDiff, nextDate.getTime()

    return timeDiff

  createJob: (data, intervalTime, callback)=>
    job = @queue.create('interval', data).
      delay(intervalTime).
      removeOnComplete(true).
      attempts(@INTERVAL_ATTEMPTS).
      ttl(@INTERVAL_TTL).
      save (err) =>
        callback err, job

module.exports = IntervalKue
