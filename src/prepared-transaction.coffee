module.exports = (Promise, RunningTransaction, TransactionHandle) ->

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
