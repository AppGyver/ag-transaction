###
Transaction a :: {
  done: Promise a
  retry: () -> Promise
  abort: () -> Promise
}
###

module.exports = (Promise, RunningTransaction) ->
  ###
  PreparedTransaction a :: {
    run :: (f: (RunningTransaction a) -> (b | Promise b)) -> Promise b
  }
  ###
  class PreparedTransaction

    @empty: new PreparedTransaction (f) ->
      f RunningTransaction.empty

    @unit: (v) ->
      new PreparedTransaction (f) ->
        Promise.resolve(RunningTransaction.unit v).then(f)

    ###
    PreparedTransaction.step :: (f: () -> Promise a) -> PreparedTransaction a
    ###
    @step: (start) ->
      new PreparedTransaction (f) ->
        Promise.resolve(new RunningTransaction {
          done: start()
        }).then(f)

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
    run :: (f: (Transaction a) -> (b | Promise b)) -> Promise b
    ###
    run: -> throw new Error 'not implemented'
