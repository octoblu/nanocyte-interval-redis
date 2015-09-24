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

  subscribeTarget: (params, callback=->) =>
    debug 'subscribeTarget target', params
    jobDelay = if params.cronString then @calculateNextCronInterval params.cronString else 0

    @unsubscribeTarget params.targetId, (err) =>
      return callback err if err?
      @redis.mset
        "interval/active/#{params.targetId}": true
        "interval/fromId/#{params.targetId}": params.fromId
        "interval/time/#{params.targetId}": params.intervalTime
        "interval/cron/#{params.targetId}": params.cronString

      @createJob targetId: params.targetId, jobDelay, (err, newJob) =>
          @redis.sadd "interval/job/#{params.targetId}", newJob.id if !err?
          debug ' - created job', newJob.id, 'for', params.targetId
          callback err

  unsubscribeTarget: (targetId, callback=->) =>
    debug 'unsubscribing', targetId
    return if !targetId?

    @redis.del "interval/active/#{targetId}"
    @redis.del "interval/fromId/#{targetId}"
    @redis.del "interval/time/#{targetId}"
    @redis.del "interval/cron/#{targetId}"

    removeJob = (jobId, callback) => @removeTargetJob(targetId, jobId, callback)
    @redis.smembers "interval/job/#{targetId}", (err, jobIds) =>
      return callback err if err?
      async.each jobIds, removeJob, callback

  removeTargetJob: (targetId, jobId, callback) =>
    return if !jobId?
    debug 'unsubscribeTarget target', targetId, 'job', jobId
    @redis.srem "interval/job/#{targetId}", jobId
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
