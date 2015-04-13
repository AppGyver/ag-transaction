jsc = require 'jsverify'

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

  arbitrarySuccessfulRunner = jsc.oneof(
    jsc.constant TransactionRunner.empty
    jsc.bless generator: jsc.json.generator.map (json) ->
      TransactionRunner.unit json
    jsc.bless generator: jsc.json.generator.map (json) ->
      TransactionRunner.unit Promise.resolve json
    jsc.bless generator: jsc.json.generator.map (json) ->
      TransactionRunner.step ->
        Promise.resolve json
  )

  {
    abortsWith
    rollsbackWith
    failsRollbackWith
    arbitrarySuccessfulRunner
  }
