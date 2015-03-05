
module.exports = (Promise) ->
  Transaction = require('./transaction')(Promise)
  PreparedTransaction = require('./prepared-transaction')(Promise, Transaction)
  TransactionRunner = require('./transaction-runner')(Promise, Transaction, PreparedTransaction)
  return TransactionRunner
