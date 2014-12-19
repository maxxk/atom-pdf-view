path = require 'path'
fs = require 'fs-plus'
Serializable = require 'serializable'

# Model is responsible for serializable properties — file name and
# view history
# TODO: history
module.exports =
class PdfEditorModel
  Serializable.includeInto(this)
  atom.deserializers.add(this)

  constructor: ({@filePath}) ->

  serializeParams: ->
    filePath: @filePath
    scale: @scale
    password: @password

  getTitle: -> @title ?
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
