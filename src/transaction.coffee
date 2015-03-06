module.exports = (Promise) ->
  defer = require('./defer')(Promise)

  rollbackIfCompleted = (done, rollback) ->
    done.then(
      rollback
      ->
        Promise.reject new Error "Can't roll back a transaction that did not complete"
    )

  whenCompleted = (promise, thenDo, elseDo) ->
    Promise.race([
      promise.then(
        -> thenDo
        -> thenDo
      )
      Promise.resolve(elseDo).delay(0)
    ]).then((choice) ->
      choice()
    )

  abortAndRejectUnlessCompleted = (done, abort, rejectDone) ->
    whenCompleted done,
      ->
        Promise.reject new Error "Can't abort a transaction that did complete"
      ->
        rejectDone(new Error 'Transaction aborted')
        abort()

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
      dfd = defer()
      @done = dfd.promise

      switch done?
        when true then Promise.resolve(done).then dfd.resolve, dfd.reject
        else dfd.reject new Error "Transaction did not declare a 'done' condition"

      if rollback?
        @rollback = => rollbackIfCompleted @done, rollback

      if abort?
        @abort = => abortAndRejectUnlessCompleted @done, abort, dfd.reject

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
        rollback: =>
          next.then (tb) =>
            tb.rollback().then =>
              @rollback()
      }
