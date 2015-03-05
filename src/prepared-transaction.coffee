module.exports = (Promise) ->
  defer = require('./defer')(Promise)

  ###
  PreparedTransaction a :: {
    done: Promise a
    retry: () -> Promise
    abort: () -> Promise
  }
  ###
  class PreparedTransaction
    ###
    startEventually: Promise (() -> Transaction)
    ###
    constructor: (startEventually) ->
      done = defer()
      retry = defer()
      abort = defer()

      @done = done.promise
      @retry = -> retry.promise.then (f) -> f()
      @abort = -> abort.promise.then (f) -> f()

      Promise.resolve(startEventually)
        .then((start) -> start())
        .then((t) ->
          t.done.then(
            done.resolve
            done.reject
          )
          retry.resolve ->
            Promise.reject new Error "TODO"
          abort.resolve t.abort
        )

    done: null
    retry: null
    abort: null
