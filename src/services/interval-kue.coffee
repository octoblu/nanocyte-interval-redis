_ = require 'lodash'
kue = require('kue')
redis = new (require 'ioredis');
debug = require('debug')('interval-service')

class IntervalKue
  constructor: (dependencies={}) ->
    @REDIS_PORT         = process.env.REDIS_PORT ? 6379
    @REDIS_HOST         = process.env.REDIS_HOST ? 'localhost'

    @kue = dependencies.kue ? require 'kue'
    IORedis = dependencies.IORedis ? require 'ioredis'
    @redis = new IORedis @REDIS_PORT, @REDIS_HOST

    @queue = @kue.createQueue
      redis:
        port: @REDIS_PORT
        host: @REDIS_HOST

  subscribeTarget: (groupId, targetId, intervalTime, cronString) =>
    debug 'subscribeTarget group', groupId, 'target', targetId, 'interval', intervalTime

    @unsubscribeTarget groupId, targetId, =>
      @redis.sadd "interval/groups/#{groupId}", targetId
      @redis.mset
        "interval/active/#{groupId}": true
        "interval/active/#{targetId}": true
        "interval/time/#{targetId}": intervalTime
        "interval/cron/#{targetId}": cronString

      job = @queue.create('interval', {
          groupId: groupId,
          targetId: targetId
        }).
        removeOnComplete(true).
        attempts(process.env.INTERVAL_ATTEMPTS ? 999).
        ttl(process.env.INTERVAL_TTL ? 10000).
        save =>
          @redis.sadd "interval/job/#{targetId}", job.id
          debug ' - created job', job.id, 'for', targetId

  unsubscribeTarget: (groupId, targetId, callback) =>
    return if !targetId

    @redis.srem "interval/groups/#{groupId}", targetId
    @redis.del "interval/active/#{targetId}"

    @redis.smembers "interval/job/#{targetId}", (err, jobIds) =>
      _.each jobIds, (jobId) =>
        debug 'unsubscribeTarget group', groupId, 'target', targetId, 'job', jobId
        @redis.srem "interval/job/#{targetId}", jobId

        if jobId
          @kue.Job.get jobId, (err, job) =>
            return if err
            job.remove()

      callback() if callback

  unsubscribeGroup: (groupId) =>
    debug 'unsubscribeGroup', groupId
    @redis.set "interval/active/#{groupId}", false
    @redis.smembers "interval/groups/#{groupId}", (err, targetIds) =>
      debug 'unsubscribeGroup found', err, targetIds
      _.each targetIds, (targetId) =>
        @unsubscribeTarget groupId, targetId

module.exports = IntervalKue
