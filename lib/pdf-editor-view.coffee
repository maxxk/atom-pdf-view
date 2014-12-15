{$, View} = require 'atom'
fs = require 'fs-plus'
path = require 'path'
require './../node_modules/pdf.js/build/generic/build/pdf.js'
{File} = require 'pathwatcher'

PDFJS.workerSrc = "file://" + path.resolve(__dirname, "../node_modules/pdf.js/build/generic/build/pdf.worker.js")

module.exports =
class PdfEditorView extends View
  @content: ->
    @div class: 'pdf-view', tabindex: -1, =>
      @iframe outlet: 'frame', class: 'pdf-js', src: "file://" + path.resolve(__dirname, "viewer.html"), frameborder: 0,
        sandbox="allow-forms allow-popups allow-pointer-lock allow-same-origin allow-scripts"

  initialize: (path) ->
    @filePath = path
    @frameElement = @frame.element
    @frameElement.onload = @frameLoaded

  frameLoaded: =>
    @window = @frameElement.contentWindow
    @app = @window.PDFViewerApplication
    #@window.mozL10n =
    #  setLocale: ->
    #  get: (name, args, string) ->
    #    string # FIXME :(
    #  translate: ->
    #  setLanguage: ->
    @app.open(new Uint8Array(fs.readFileSync(@filePath)))

  getTitle: -> "PDF Editor View"
