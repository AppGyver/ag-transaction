module.exports = (promises) ->
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

      dfd = promises.defer()
      t.done = dfd.promise

      switch done?
        when true then promises.resolve(done).then dfd.resolve, dfd.reject
        else dfd.reject new Error "Transaction did not declare a 'done' condition"

      if rollback?
        t.rollback = -> promises.rollbackIfCompleted t.done, rollback

      if abort?
        t.abort = -> promises.abortAndRejectUnlessCompleted t.done, abort, dfd.reject

      new Transaction t

    ###
    Transaction null
    ###
    @empty: Transaction.create {
      done: promises.resolve()
    }

    ###
    (a) -> Transaction a
    ###
    @unit: (v) ->
      Transaction.create {
        done: promises.resolve v
      }

    constructor: ({ done, rollback, abort} = {}) ->
      @done = switch done?
        when true then done
        else promises.reject new Error "Transaction did not declare a 'done' condition"

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
      promises.reject new Error 'Transaction did not declare a rollback instruction'

    ###
    Attempt to signal transaction abortion if it's in progress
    ###
    abort: ->
      promises.reject new Error 'Transaction did not declare an abort instruction'

    ###
    f: (a -> Transaction b) -> Transaction b
    ###
    flatMapDone: (f) ->
      next = @done.then f
      nextDone = next.then (t) -> t.done

      new Transaction {
        done: nextDone
        rollback: =>
          nextDone.then(
            =>
              next.value().rollback().then =>
                @rollback()
            @rollback
          )

        abort: =>
          promises.ifCompleted @done,
            ->
              next.then (tb) ->
                tb.abort()
            @abort
      }
