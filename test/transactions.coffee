module.exports = (Promise, Transaction) ->
  never = new Promise (resolve, reject) ->
    # Never resolve or reject

  abort = (value) ->
    new Transaction {
      done: never
      abort: -> value
    }

  rollback = (value) ->
    new Transaction {
      done: Promise.resolve value
      rollback: (v) ->
        if v is value
          Promise.resolve "#{value} rolled back"
        else
          Promise.reject new Error "Did not get expected value #{value} as rollback argument"
    }

  failsRollback = (message) ->
    new Transaction {
      done: Promise.resolve()
      rollback: ->
        Promise.reject new Error message
    }

  {
    never
    abort
    rollback
    failsRollback
  }
