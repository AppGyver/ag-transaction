module.exports = (Promise) ->
  rollbackIfCompleted = (done, rollback) ->
    done.then(
      rollback
      ->
        Promise.reject new Error "Can't roll back a transaction that did not complete"
    )

  abortUnlessCompleted = (done, abort) ->
    whenDidComplete = -> -> Promise.reject new Error "Can't abort a transaction that did complete"

    Promise.race([
      done.then(whenDidComplete, whenDidComplete)
      Promise.resolve(abort).delay(0)
    ]).then((choice) ->
      choice()
    )

  ###
  Transaction a :: {
    rollback: () -> Promise
    abort: () -> Promise
    done: Promise a
  }
  ###
  class Transaction
    ###
    Transaction null
    ###
    @empty: new Transaction {
      done: Promise.resolve()
    }

    ###
    (a) -> Transaction a
    ###
    @unit: (v) ->
      new Transaction {
        done: Promise.resolve v
      }

    constructor: ({ done, rollback, abort } = {}) ->
      @done = switch done?
        when true then Promise.resolve done
        else Promise.reject new Error "Transaction did not declare a 'done' condition"

      if rollback?
        @rollback = => rollbackIfCompleted @done, rollback

      if abort?
        @abort = => abortUnlessCompleted @done, abort

    ###
    Signal transaction completion; no longer abortable, but might be rollbackable
    ###
    done: null

    ###
    Attempt to undo transaction if it's complete
    ###
    rollback: ->
      Promise.reject new Error 'Transaction did not declare a rollback instruction'

    ###
    Attempt to signal transaction abortion if it's in progress
    ###
    abort: ->
      Promise.reject new Error 'Transaction did not declare an abort instruction'

    ###
    f: (a -> Transaction b) -> Transaction b
    ###
    flatMapDone: (f) ->
      next = @done.then f

      new Transaction {
        done: next.then (t) -> t.done
      }
