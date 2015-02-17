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
