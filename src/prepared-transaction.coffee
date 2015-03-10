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

      @done = done.promise
      @rollback = -> rollback.promise.then (f) -> f()
      @abort = -> abort.promise.then (f) -> f()

      promises.resolve(startEventually)
        .then((start) ->
          start()
        )
        .then((t) ->
          t.done.then(done.resolve, done.reject)

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
        # The promises in this are set up to take care of themselves, so new Transaction instead of Transaction.create
        ta = new Transaction this
        tb = ta.flatMapDone (a) ->
          # The same goes for the output from f(a)
          new Transaction f(a)

        # We take the flatMapped Transaction and hook an aborted latch that will prevent the next rollback if we've aborted
        aborted = promises.defer()
        new Transaction {
          done: tb.done
          abort: ->
            aborted.resolve()
            tb.abort()
          rollback: ->
            promises.ifCompleted aborted.promise, ta.rollback, tb.rollback
        }

