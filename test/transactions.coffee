module.exports = (Promise, Transaction) ->
  never = new Promise (resolve, reject) ->
    # Never resolve or reject

  abort = (value) ->
    Transaction.create {
      done: never
      abort: -> Promise.resolve "#{value} aborted"
    }

  rollback = (value) ->
    Transaction.create {
      done: Promise.resolve value
      rollback: (v) ->
        if v is value
          Promise.resolve "#{value} rolled back"
        else
          Promise.reject new Error "Did not get expected value #{value} as rollback argument"
    }

  failsRollback = (message) ->
    Transaction.create {
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
