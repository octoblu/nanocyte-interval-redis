class MessagesController
  constructor: (options={}) ->
    {@intervalService} = options

  subscribe: (req, res) =>
    @intervalService.subscribeTarget req.params.groupId, req.params.targetId, req.params.intervalTime ? 1000
    res.status(201).end() if res

  unsubscribe: (req, res) =>
    @intervalService.unsubscribeGroup req.params.groupId
    res.status(201).end() if res

module.exports = MessagesController
