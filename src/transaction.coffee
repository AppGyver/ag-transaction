module.exports = (Promise) ->
  defer = require('./defer')(Promise)

  rollbackIfCompleted = (done, rollback) ->
    done.then(
      rollback
      ->
        Promise.reject new Error "Can't roll back a transaction that did not complete"
    )

  ifCompleted = (promise, thenDo, elseDo) ->
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
    ifCompleted done,
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
    @create: ({ done, rollback, abort } = {}) ->
      t = {
        done: null
        rollback: null
        abort: null
      }

      dfd = defer()
      t.done = dfd.promise

      switch done?
        when true then Promise.resolve(done).then dfd.resolve, dfd.reject
        else dfd.reject new Error "Transaction did not declare a 'done' condition"

      if rollback?
        t.rollback = => rollbackIfCompleted t.done, rollback

      if abort?
        t.abort = => abortAndRejectUnlessCompleted t.done, abort, dfd.reject

      new Transaction t

    ###
    Transaction null
    ###
    @empty: Transaction.create {
      done: Promise.resolve()
    }

    ###
    (a) -> Transaction a
    ###
    @unit: (v) ->
      Transaction.create {
        done: Promise.resolve v
      }

    constructor: ({ done, rollback, abort} = {}) ->
      @done = switch done?
        when true then done
        else Promise.reject new Error "Transaction did not declare a 'done' condition"

      @rollback = rollback if rollback?
      @abort = abort if abort?

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
      nextDone = next.then (t) -> t.done

      new Transaction {
        done: nextDone
        rollback: =>
          # TODO: we never get here because the constructor detects we've failed
          nextDone.then(
            =>
              next.value().rollback().then =>
                @rollback()
            @rollback
          )

        abort: =>
          ifCompleted @done,
            ->
              next.then (tb) ->
                tb.abort()
            @abort
      }
