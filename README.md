# ag-transaction
Provides a type for asynchronous, rollbackable transactions with progress notifications

## Use case

Assume we have a multi-part asynchronous process.

    model("files").create(data).then (file) ->
      model("fileversions").create(data).then (uploadAdvice) ->
        uploadFile(file, uploadAdvice).then ->
          model("files").findAll(filters).then parseFiles

In addition to what's already afforded by the Promise type, we would like to:

- observe progress (because the file upload may take a very long while)
- be able to abort (in case it's taking too long)

This needs to be done such that the resulting API is as chainable as the original.

## The `Transaction` type

The `Transaction` type is essentially a pair of `{ progress, done }`, where `progress` is a Stream of progress notifications and `done` is a Promise of the eventual result.

    progress: Stream p
    done: Promise d

We additionally require that we can signal abortion of the process,

    abort: () -> Promise

as well as being able to continue off the result of the next step,

    flatMapDone: ((d) -> Transaction p e) -> Transaction p e

The full type is therefore:

    Transaction p d = {
      progress: Stream p
      done: Promise d
      abort: () -> Promise
      flatMapDone: ((d) -> Transaction p e) -> Transaction p e
    }