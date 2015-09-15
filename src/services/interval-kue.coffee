_ = require 'lodash'
kue = require('kue')
debug = require('debug')('interval-service')

class IntervalKue
  constructor: (options={}) ->
    @queue = kue.createQueue()

  subscribeNode: (flowId, nodeId, intervalTime) =>
    @queue.create('subscribe-node', {
      flowId: flowId,
      nodeId: nodeId,
      intervalTime: intervalTime
    }).save()

  unsubscribeFlow: (flowId) =>
    @queue.create('unsubscribe-flow', {flowId: flowId}).save()

module.exports = IntervalKue
