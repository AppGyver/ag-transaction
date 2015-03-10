module.exports = (promises, Transaction) ->
  noop = ->

  ###
  PreparedTransaction a :: {
    done: Promise a
    rollback: () -> Promise
    abort: () -> Promise
  }
  ###
  class PreparedTransaction

    ###
    fromCreator :: (f: ({ done, rollback, abort }) -> ()) -> Transaction
    ###
    @fromCreator: (f) ->
      t = {
        done: null
        rollback: null
        abort: null
      }
      new PreparedTransaction ->
        t.done = promises.resolve(f {
          rollback: (v) -> t.rollback = v
          abort: (v) -> t.abort = v
        })
        Transaction.create t

    @empty: new PreparedTransaction ->
      Transaction.empty

    @unit: (v) ->
      new PreparedTransaction ->
        Transaction.unit v

    ###
    startEventually: Promise (() -> Transaction a)
    ###
    constructor: (startEventually) ->
      done = promises.defer()
      rollback = promises.defer()
      abort = promises.defer()
      aborted = promises.defer()

      @done = done.promise
      @rollback = -> rollback.promise.then (f) ->
        # Prevent rollback if aborted already.
        # Why exactly do we need to do this?
        # Will probably cause issues at some point.
        promises.ifCompleted aborted.promise, noop, f

      @abort = -> abort.promise.then (f) ->
        # Signal abortion to trigger rollback latch above.
        aborted.resolve()
        f()

      promises.resolve(startEventually)
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
    abort: null

    ###
    flatMapDone: (f: (a) -> PreparedTransaction b) -> PreparedTransaction b
    ###
    flatMapDone: (f) ->
      new PreparedTransaction =>
        Transaction.create(this).flatMapDone (a) ->
          Transaction.create(f(a))

