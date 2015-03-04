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
    @done = done if done?

  done: Promise.reject new Error "RunningTransaction did not declare a 'done' condition"

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


###
PreparedTransaction a :: {
  run :: (f: (RunningTransaction a) -> (b | Promise b)) -> Promise b
}
###
class PreparedTransaction

  ###
  run :: (f: (RunningTransaction a) -> (b | Promise b)) -> Promise b
  ###
  constructor: (@run) ->

  ###
  (f: (a) -> PreparedTransaction b) -> PreparedTransaction b
  ###
  flatMapDone: (f) ->
    ###
    g: (RunningTransaction b) -> (c | Promise c)
    ###
    new PreparedTransaction (g) =>
      @run (ta) ->
        g new RunningTransaction {
          done: ta.flatMapDone((a) ->
            new RunningTransaction {
              done: f(a).run (tb) ->
                tb.done
            }).done
        }

  ###
  run :: (f: (RunningTransaction a) -> (b | Promise b)) -> Promise b
  ###
  run: -> throw new Error 'not implemented'

  ###
  PreparedTransaction.Step :: (f: () -> Promise a) -> PreparedTransaction a
  ###
  @Step: (start) ->
    new PreparedTransaction (f) ->
      Promise.resolve(new RunningTransaction {
        done: start()
      }).then(f)

module.exports = PreparedTransaction
