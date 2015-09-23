_ = require 'lodash'
async = require 'async'
debug = require('debug')('interval-service')

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

  subscribeTarget: (params, callback=->) =>
    debug 'subscribeTarget target', params
    params.intervalTime = calculateNextCronInterval cronString if params.cronString

    @unsubscribeTarget params.targetId, =>
      @redis.mset
        "interval/active/#{params.targetId}": true
        "interval/time/#{params.targetId}": params.intervalTime
        "interval/cron/#{params.targetId}": params.cronString

      jobDelay = if params.cronString then params.intervalTime else 0
      job = @queue.create('interval', targetId: params.targetId ).
        delay(jobDelay).
        removeOnComplete(true).
        attempts(@INTERVAL_ATTEMPTS).
        ttl(@INTERVAL_TTL).
        save (err) =>
          @redis.sadd "interval/job/#{params.targetId}", job.id
          debug ' - created job', job.id, 'for', params.targetId
          callback err

  unsubscribeTarget: (targetId, callback=->) =>
    return if !targetId?
    removeJob = (jobId) => @removeTargetJob(targetId,jobId)
    @redis.del "interval/active/#{targetId}"
    @redis.smembers "interval/job/#{targetId}", (err, jobIds) =>
      async.each jobIds, removeJob, callback

  removeTargetJob: (targetId, jobId) =>
    return if !jobId?
    debug 'unsubscribeTarget target', targetId, 'job', jobId
    @redis.srem "interval/job/#{targetId}", jobId
    @kue.Job.get jobId, (err, job) =>
      return if err
      job.remove()

module.exports = IntervalKue
