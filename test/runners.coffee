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

  simpleSuccessfulRunnerGen = jsc.generator.oneof [
    jsc.unit.generator.map -> TransactionRunner.empty
    jsc.json.generator.map (json) -> TransactionRunner.unit json
    jsc.json.generator.map (json) -> TransactionRunner.unit Promise.resolve json
    jsc.json.generator.map (json) ->
      TransactionRunner.step ->
        Promise.resolve json
  ]

  arbitrarySuccessfulRunner = jsc.bless generator: jsc.generator.recursive simpleSuccessfulRunnerGen, (gen) ->
    jsc.generator.oneof [
      gen
      jsc.generator.tuple([gen, gen]).map ([r1, r2]) ->
        r1.flatMapDone ->
          r2
    ]

  {
    abortsWith
    rollsbackWith
    failsRollbackWith
    arbitrarySuccessfulRunner
  }
