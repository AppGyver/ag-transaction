
module.exports = (Promise, RunningTransaction) ->
  defer = ->
    deferred = {
      promise: null
      resolve: null
      reject: null
    }

    deferred.promise = new Promise (resolve, reject) ->
      deferred.resolve = resolve
      deferred.reject = reject

    deferred

  ###
  TransactionHandle a :: {
    done: Promise a
    retry: () -> Promise
    abort: () -> Promise
  }
  ###
  class TransactionHandle
    ###
    startEventually: Promise (() -> RunningTransaction)
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
          abort.resolve ->
            Promise.reject new Error "TODO"
        )

    done: null
    retry: null
    abort: null

  ###
  PreparedTransaction a :: {
    run :: (f: (RunningTransaction a) -> (b | Promise b)) -> Promise b
  }
  ###
  class PreparedTransaction

    @empty: new PreparedTransaction ->
      RunningTransaction.empty

    @unit: (v) ->
      new PreparedTransaction ->
        RunningTransaction.unit v

    ###
    PreparedTransaction.step :: (f: () -> Promise a) -> PreparedTransaction a
    ###
    @step: (start) ->
      new PreparedTransaction ->
        new RunningTransaction {
          done: start()
        }

    ###
    start :: (() -> RunningTransaction a) | Promise (() -> RunningTransaction a)
    ###
    constructor: (start) ->
      ###
      g: (TransactionHandle a) -> (b | Promise b)
      ###
      @run = (g) ->
        Promise.resolve(g new TransactionHandle start)

    ###
    (f: (a) -> PreparedTransaction b) -> PreparedTransaction b
    ###
    flatMapDone: (f) ->
      new PreparedTransaction =>
        ###
        Promise (RunningTransaction b)
        ###
        @run (ta) ->
          ta.done.then (a) ->
            f(a).run (tb) ->
              new RunningTransaction {
                done: tb.done
              }

    ###
    run :: (f: (TransactionHandle a) -> (b | Promise b)) -> Promise b
    ###
    run: -> throw new Error 'not implemented'
