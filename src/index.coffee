
module.exports = (Promise) ->
  RunningTransaction = require('./running-transaction')(Promise)
  TransactionHandle = require('./transaction-handle')(Promise)
  PreparedTransaction = require('./prepared-transaction')(Promise, RunningTransaction, TransactionHandle)
  return PreparedTransaction
