
module.exports = (Promise) ->
  promises = require('./promises')(Promise)
  Transaction = require('./transaction')(promises)
  PreparedTransaction = require('./prepared-transaction')(promises, Transaction)
  TransactionRunner = require('./transaction-runner')(Promise, Transaction, PreparedTransaction)
  return TransactionRunner
