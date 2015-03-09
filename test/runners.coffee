module.exports = (transactions, Promise, TransactionRunner) ->

  abortsWith = (v) ->
    if !(v instanceof Function)
      do (value = v) ->
        v = -> value

    TransactionRunner.step ({abort}) ->
      abort v
      transactions.never

  {
    abortsWith
  }
