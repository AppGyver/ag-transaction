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

    ###
    PreparedTransaction.Step :: (f: () -> Promise a) -> PreparedTransaction a
    ###
    @Step: (start) ->
      new PreparedTransaction (f) ->
        Promise.resolve(new RunningTransaction {
          done: start()
        }).then(f)
