path = require 'path'
fs = require 'fs-plus'
Serializable = require 'serializable'
{Model} = require 'model'

# Model is responsible for serializable properties — file name and
# view history
# TODO: history
module.exports =
class PdfEditorModel extends Model
  Serializable.includeInto(this)
  atom.deserializers.add(this)

  constructor: ({@filePath}) ->

  serializeParams: ->
    filePath: @filePath
    scale: @scale
    password: @password

  open: ({filePath, password}) ->
    fs.readFile filePath, (err, data) =>
      throw err if err
      PDFJS.getDocument({data: new Uint8Array(data), password}, null,
        (updatePassword, reason) =>
          @passwordNeeded = {updatePassword, reason}).then(
          (@pdfDocument) => )

  getTitle: ->
    if @filePath?
      path.basename(@filePath)
    else
      'untitled'

  getViewClass: ->
    require './pdf-editor-view'

  getUri: ->
    @filePath

  getPath: ->
    @filePath
