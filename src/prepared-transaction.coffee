module.exports = (Promise, Transaction) ->
  defer = require('./defer')(Promise)

  ###
  PreparedTransaction a :: {
    done: Promise a
    rollback: () -> Promise
    abort: () -> Promise
  }
  ###
  class PreparedTransaction

    @empty: new PreparedTransaction ->
      Transaction.empty

    @unit: (v) ->
      new PreparedTransaction ->
        Transaction.unit v

    ###
    startEventually: Promise (() -> Transaction a)
    ###
    constructor: (startEventually) ->
      done = defer()
      rollback = defer()
      abort = defer()

      @done = done.promise
      @rollback = -> rollback.promise.then (f) -> f()
      @abort = -> abort.promise.then (f) -> f()

      Promise.resolve(startEventually)
        .then((start) -> start())
        .then((t) ->
          t.done.then(
            done.resolve
            done.reject
          )

          abort.resolve t.abort
          rollback.resolve t.rollback
        )

    done: null
    rollback: null

    ###
    flatMapDone: (f: (a) -> PreparedTransaction b) -> PreparedTransaction b
    ###
    flatMapDone: (f) ->
      new PreparedTransaction =>
        @done.then (a) ->
          tb = f(a)
          new Transaction {
            done: tb.done
          }
