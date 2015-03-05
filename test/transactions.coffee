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
      done: Promise.resolve()
      rollback: -> value
    }

  {
    never
    abort
    rollback
  }
