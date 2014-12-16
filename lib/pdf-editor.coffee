path = null
PdfEditorModel = require './pdf-editor-model'

module.exports =
  activate: (state) ->
    @opener = atom.workspace.addOpener openUri
    atom.packages.once('activated', createPdfStatusView)

  deactivate: ->
    @opener.dispose()

# Files with these extensions will be opened as PDFs
pdfExtensions = ['.pdf']
openUri = (uriToOpen) ->
  path ?= require 'path'
  uriExtension = path.extname(uriToOpen).toLowerCase()
  if uriExtension in pdfExtensions
    new PdfEditorModel(uriToOpen)

createPdfStatusView = ->
  {statusBar} = atom.workspaceView
  if statusBar?
    PdfStatusBarView = require  './pdf-status-bar-view'
    view = new PdfStatusBarView(statusBar)
    view.attach()
  PdfGoToPageView = require  './pdf-goto-page-view.coffee'
  new PdfGoToPageView()
