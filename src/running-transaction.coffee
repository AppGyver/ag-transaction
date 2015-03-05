
module.exports = (Promise) ->
  ###
  RunningTransaction a :: {
    retry: () -> Promise
    abort: () -> Promise
    done: Promise a
  }
  ###
  class RunningTransaction
    @Empty: new RunningTransaction {
      done: Promise.resolve()
    }

    constructor: ({ done }) ->
      @done = switch done?
        when true then done
        else Promise.reject new Error "RunningTransaction did not declare a 'done' condition"

    done: null

    retry: ->
      alert 'TODO'
    abort: ->
      alert 'TODO'

    ###
    f: (a -> RunningTransaction b) -> RunningTransaction b
    ###
    flatMapDone: (f) ->
      next = @done.then f

      new RunningTransaction {
        done: next.then (t) -> t.done
      }
