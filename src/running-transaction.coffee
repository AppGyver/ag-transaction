
module.exports = (Promise) ->
  ###
  RunningTransaction a b :: {
    rollback: () -> Promise b
    abort: () -> Promise b
    done: Promise a
  }
  ###
  class RunningTransaction
    @empty: new RunningTransaction {
      done: Promise.resolve()
    }

    @unit: (v) ->
      new RunningTransaction {
        done: Promise.resolve v
      }

    constructor: ({ done, rollback } = {}) ->
      @done = switch done?
        when true then Promise.resolve done
        else Promise.reject new Error "RunningTransaction did not declare a 'done' condition"

      if rollback?
        @rollback = =>
          @done.then(
            rollback
            ->
              Promise.reject new Error "Can't roll back a transaction that did not complete"
          )

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
