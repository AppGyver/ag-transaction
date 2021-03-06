module.exports = (Promise, Transaction, PreparedTransaction) ->

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
    TransactionRunner.step :: (f: ({ rollback, abort }) -> Promise a) -> TransactionRunner a
    ###
    @step: (creator) ->
      new TransactionRunner ->
        PreparedTransaction.fromCreator creator

    ###
    start :: (() -> Transaction a) | Promise (() -> Transaction a)
    ###
    constructor: (start) ->
      ###
      g: (PreparedTransaction a) -> (b | Promise b)
      ###
      @run = (g) ->
        Promise.resolve(g new PreparedTransaction start)

    ###
    (f: (a) -> TransactionRunner b) -> TransactionRunner b
    ###
    flatMapDone: (f) ->
      new TransactionRunner =>
        @run (ta) ->
          ta.flatMapDone (a) ->
            PreparedTransaction.fromCreator ({ abort, rollback }) ->
              f(a).run (tb) ->
                abort tb.abort
                rollback tb.rollback
                tb.done

    ###
    run :: (f: (PreparedTransaction a) -> (b | Promise b)) -> Promise b
    ###
    run: -> throw new Error 'not implemented'
