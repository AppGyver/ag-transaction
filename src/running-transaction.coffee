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
  RunningTransaction a :: {
    rollback: () -> Promise
    abort: () -> Promise
    done: Promise a
  }
  ###
  class RunningTransaction
    ###
    RunningTransaction null
    ###
    @empty: new RunningTransaction {
      done: Promise.resolve()
    }

    ###
    (a) -> RunningTransaction a
    ###
    @unit: (v) ->
      new RunningTransaction {
        done: Promise.resolve v
      }

    constructor: ({ done, rollback, abort } = {}) ->
      @done = switch done?
        when true then Promise.resolve done
        else Promise.reject new Error "RunningTransaction did not declare a 'done' condition"

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
      Promise.reject new Error 'RunningTransaction did not declare a rollback instruction'

    ###
    Attempt to signal transaction abortion if it's in progress
    ###
    abort: ->
      Promise.reject new Error 'RunningTransaction did not declare an abort instruction'

    ###
    f: (a -> RunningTransaction b) -> RunningTransaction b
    ###
    flatMapDone: (f) ->
      next = @done.then f

      new RunningTransaction {
        done: next.then (t) -> t.done
      }
