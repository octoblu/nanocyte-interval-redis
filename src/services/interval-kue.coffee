_ = require 'lodash'
debug = require('debug')('interval-service')
kue = require('kue')

class IntervalKue
  constructor: (options={}) ->
    @queue = kue.createQueue()

  subscribeNode: (flowId, nodeId, intervalTime) =>

  unsubscribeFlow: (flowId) =>

module.exports = IntervalKue
