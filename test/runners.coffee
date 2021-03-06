module.exports = (transactions, Promise, TransactionRunner) ->

  abortsWith = (v) ->
    if !(v instanceof Function)
      do (value = v) ->
        v = -> value

    TransactionRunner.step ({abort}) ->
      abort v
      transactions.never

  rollsbackWith = (v) ->
    if !(v instanceof Function)
      do (value = v) ->
        v = -> value

    TransactionRunner.step ({rollback}) ->
      rollback v
      Promise.resolve()

  failsRollbackWith = (v) ->
    if !(v instanceof Function)
      do (value = v) ->
        v = -> Promise.reject new Error value

    TransactionRunner.step ({rollback}) ->
      rollback v
      Promise.resolve()

  {
    abortsWith
    rollsbackWith
    failsRollbackWith
  }
