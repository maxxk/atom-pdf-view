{$, ScrollView} = require 'atom'
path = require 'path'
{File} = require 'pathwatcher'

require './../node_modules/pdf.js/build/generic/build/pdf.js'

# Load viewer modules (pollutes global namespace)
viewerPath = './../node_modules/pdf.js/web/'
pdfjsRequire = (names...) -> for n in names
  require viewerPath + n

pdfjsRequire 'ui_utils', 'pdf_rendering_queue', 'page_view',
  'text_layer_builder', 'pdf_viewer', 'thumbnail_view',
  'document_outline_view', 'document_attachments_view',
  'pdf_find_controller', 'pdf_history', 'grab_to_pan'

# Configure PDFJS preferences
pdfjsPath = (name) ->
  'file://' + path.resolve(__dirname, '../node_modules/pdf.js', name)

PDFJS.workerSrc = pdfjsPath 'build/generic/build/pdf.worker.js'
PDFJS.imageResourcesPath = pdfjsPath 'web/images/'
PDFJS.cMapUrl = pdfjsPath 'web/cmaps'
PDFJS.cMapPacked = true

# mock mozL10n object (for thubmnail_view and page_view)
window.mozL10n =
  translate: ->
  get: (name, {page}, template) -> switch name
    when 'thumb_page_title' then "Page #{page}"
    when 'thumb_page_canvas' then "Thumbnail of Page #{page}"
    else
      console.warn "Unknown localization identifier: #{name}, update mozL10n mock"
      template

module.exports =
class PdfEditorView extends ScrollView
  @content: ->
    @div class: 'pdf-view', tabindex: -1, =>
      @div outlet: 'container', =>
        @div outlet: 'viewer'

  initialize: (@model) ->
    super
    @pdfRenderingQueue = new PDFRenderingQueue

    @pdfViewer = new PDFViewer
      {@container.element, @viewer.element, linkService: this}
    @pdfRenderingQueue.setViewer @pdfViewer

  destroy: ->
    @detach()
