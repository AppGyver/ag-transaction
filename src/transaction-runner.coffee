module.exports = (Promise, Transaction, TransactionHandle) ->

  ###
  TransactionRunner a :: {
    run :: (f: (Transaction a) -> (b | Promise b)) -> Promise b
  }
  ###
  class TransactionRunner

    @empty: new TransactionRunner ->
      Transaction.empty

    @unit: (v) ->
      new TransactionRunner ->
        Transaction.unit v

    ###
    TransactionRunner.step :: (f: () -> Promise a) -> TransactionRunner a
    ###
    @step: (start) ->
      new TransactionRunner ->
        new Transaction {
          done: start()
        }

    ###
    start :: (() -> Transaction a) | Promise (() -> Transaction a)
    ###
    constructor: (start) ->
      ###
      g: (TransactionHandle a) -> (b | Promise b)
      ###
      @run = (g) ->
        Promise.resolve(g new TransactionHandle start)

    ###
    (f: (a) -> TransactionRunner b) -> TransactionRunner b
    ###
    flatMapDone: (f) ->
      new TransactionRunner =>
        ###
        Promise (Transaction b)
        ###
        @run (ta) ->
          ta.done.then (a) ->
            f(a).run (tb) ->
              new Transaction {
                done: tb.done
              }

    ###
    run :: (f: (TransactionHandle a) -> (b | Promise b)) -> Promise b
    ###
    run: -> throw new Error 'not implemented'
