_ = require 'lodash'
kue = require('kue')
redis = new (require 'ioredis');
debug = require('debug')('interval-service')

class IntervalKue
  constructor: (options={}) ->
    @queue = kue.createQueue()

  subscribeTarget: (groupId, targetId, intervalTime) =>
    debug 'subscribeTarget group', groupId, 'target', targetId, 'interval', intervalTime

    @unsubscribeTarget groupId, targetId, =>
      redis.sadd "groups/#{groupId}", targetId
      redis.mset
        "repeat/#{groupId}": true
        "repeat/#{targetId}": true

      job = @queue.create('interval', {
          groupId: groupId,
          targetId: targetId,
          intervalTime: intervalTime
        }).
        removeOnComplete(true).
        save =>
          redis.set "job/#{targetId}", job.id
          debug ' - created job', job.id, 'for', targetId

  unsubscribeTarget: (groupId, targetId, callback) =>
    return if !targetId

    redis.srem "groups/#{groupId}", targetId
    redis.del "repeat/#{targetId}"

    redis.get "job/#{targetId}", (err, jobId) =>
      debug 'unsubscribeTarget group', groupId, 'target', targetId, 'job', jobId
      redis.del "job/#{targetId}"

      if jobId
        kue.Job.get jobId, (err, job) =>
          return if err
          job.remove()

      callback() if callback

  unsubscribeGroup: (groupId) =>
    debug 'unsubscribeGroup', groupId
    redis.del "repeat/#{groupId}"
    redis.smembers "groups/#{groupId}", (err, targetIds) =>
      debug 'unsubscribeGroup found', err, targetIds
      _.each targetIds, (targetId) =>
        @unsubscribeTarget groupId, targetId

module.exports = IntervalKue
