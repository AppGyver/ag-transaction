# ag-transaction

Provides a type for asynchronous, rollbackable transactions with progress notifications

## Prerequisites

Assuming a familiarity with [Bluebird](https://github.com/petkaantonov/bluebird/) Promises and [Bacon.js](https://github.com/baconjs/bacon.js/) Streams.

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

## Creating a Transaction with `Transaction.step`

Transaction.step is a function that allows us to lift `Promise`-yielding processes into `Transaction`.

    Transaction.step :: ((
      rollback: () -> Promise
      progress: (p) -> ()
    ) -> Promise d) -> Transaction p d

Let's take a procedure and bake it into a `Transaction`.

    model("files").create(data).then (file) ->
      model("fileversions").create(data).then (fileVersion) ->
        {file, fileVersion}

We use `Transaction.step` to provide the `progress`, `abort` and `flatMapDone` and our procedure for the `done`.

    Transaction.step ->
      model("files").create(data).then (file) ->
        model("fileversions").create(data).then (fileVersion) ->
          {file, fileVersion}

You'll observe that there are two parts that we may wish to reverse later on in case something in the rest of the transaction fails. Let's provide rollback instructions.

    Transaction.step (rollback) ->
      model("files").create(data).then (file) ->
        rollback ->
          file.delete()
        model("fileversions").create(data).then (fileVersion) ->
          rollback ->
            fileVersion.delete()
          {file, fileVersion}

`Transaction.step` will collect the instructions and knows what to do in case we call `abort` or a step fails.

We can also provide progress notifications. Ignoring the rollback instructions for sake of example, we get:

    Transaction.step (rollback, progress) ->
      model("files").create(data).then (file) ->
        progress "halfway there!"
        model("fileversions").create(data).then (fileVersion) ->
          {file, fileVersion}

The example provides a string as the notification, but it can be whatever the consumer should be able to process.

## Chaining `Transaction` steps with `flatMapDone`

Let's imagine we wanted to split the two asynchronous steps we had before.

    createFile = Transaction.step (rollback, progress) ->
      model("files").create(data).then (file) ->
        rollback ->
          file.delete()
        progress "file created"
        file

If we wanted to continue off the value in `done` after this step, we could of course do this:

    createFile.done.then (file) ->
      model("fileversions").create(data).then (fileVersion) ->
        {file, fileVersion}

The result of this operation, however, is not a `Transaction` but a `Promise`. The consumer of this value would not be able to abort the process or inspect its progress - what's done is done and what's not done is not done.

We often want to perform a transaction as multiple sequential steps, where a step depends on the output of a previous one. We achieve this with `flatMapDone`, which accepts the value from the previous step's `done` and returns a new `Transaction`.

    createFile.flatMapDone (file) ->
      Transaction.step (rollback, progress) ->
        model("fileversions").create(data).then (fileVersion) ->
          rollback ->
            fileVersion.delete()
          progress "fileversion created"
          {file, fileVersion}

In terms of our type it means we take a `Transaction`, add another step and get a bigger `Transaction` back. `flatMapDone` will take care to retain the rollback instructions and progress events for us.



