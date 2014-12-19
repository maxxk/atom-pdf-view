{$, ScrollView} = require 'atom'
fs = require 'fs-plus'
path = require 'path'
vm = require 'vm'
{File} = require 'pathwatcher'

require './../node_modules/pdf.js/build/generic/build/pdf.js'

# Load viewer modules (all of them pollute global namespace)
viewerPath = './../node_modules/pdf.js/web/'
pdfjsRequire = (names...) -> for n in names
  file = path.resolve(__dirname, viewerPath, n + '.js')
  code = fs.readFileSync(file)
  vm.runInThisContext(code, file)

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
      container: @viewerContainer.element
      viewer: @viewer.element
      linkService: @
    @pdfRenderingQueue.setViewer @pdfViewer

    @pdfThumbnailViewer = new PDFThumbnailViewer
      container: @thumbnailContainer.element
      renderingQueue: @pdfRenderingQueue
      linkService: @
    @pdfRenderingQueue.setThumbnailViewer @pdfThumbnailViewer

    @findController = new PDFFindController
      pdfViewer: @pdfViewer
      integratedFind: false
    @pdfViewer.setFindController @findController

    # TODO:
    # @findController.setFindBar(@findBar)

    @sidebarViewOnLoad = atom.config.get('pdf-view.sidebarViewOnLoad')

  open: ({filePath, password, scale}) ->
    filePath ?= @model.filePath
    password ?= @model.password
    @loading = true
    fs.readFile filePath, (err, data) =>
      throw err if err?
      PDFJS.getDocument({data: new Uint8Array(data), password}, null, @passwordNeeded).then (@pdfDocument) =>
          @load()
          @loading = false

  load: ->
    @findController.reset()

    @pagesCount = @pdfDocument.numPages
    id = @documentFingerprint = @pdfDocument.fingerprint
    @store = new ViewHistory id

    @pdfViewer.currentScale = @model.scale ? UNKNOWN_SCALE
    @pdfViewer.setDocument @pdfDocument

    firstPagePromise = @pdfViewer.firstPagePromise
    pagesPromie = @pdfViewer.pagesPromise
    onePageRendered = @pdfViewer.onePageRendered

    @pageRotation = 0
    @isInitialViewSet = false
    @pagesRefMap = @pdfViewer.pagesRefMap

    @pdfThumbnailViewer.setDocument @pdfDocument

    firstPagePromise.then (pdfPage) =>
      @findController.resolveFirstPage()
      # FIXME: is @ neccessary?
      @model.initializeHistory @documentFingerprint, @

    showPreviousViewOnLoad = atom.config.get 'pdf-view.showPreviousViewOnLoad'
    defaultZoomValue = atom.config.get 'pdf-view.defaultZoomValue'
    Promise.all([firstPagePromise, store.initializedPromise]).then (=>
      storedHash = if showPreviousViewOnLoad and store.get('exists', false)
          page: @store.get('page', '1')
          zoom: defaultZoomValue || @store.get('zoom', @pdfViewer.currentScale)
          left: @store.get('scrollLeft', 0)
          top: @store.get('scrollTop', 0)
        else
          page: 1
          zoom: defaultZoomValue
      @setInitialView(storedHash, scale)),
      (reason) =>
        console.error reason
        firstPagePromise.then => @setInitialView(null, @model.scale)

    Promise.all([pagesPromise, @animationStartedPromise]).then =>
      @pdfDocument.getOutline().then (outline) =>
        @outline = new DocumentOutlineView
          outline: outline
          outlineView: @outlineView.element
          linkService: @

        if (not outline) and (not @outlineView.classList.contains 'hidden')
          @switchSidebarView 'thumbs'
        if outline and @sidebarViewOnLoad is 'outline'
          @switchSidebarView 'outline', true

      if @sidebarViewOnLoad is 'thumbs'
        Promise.all([firstPagePromise, onePageRendered]).then =>
          @switchSidebarView 'thumbs', true

      @pdfDocument.getMetadata().then ({info, @metadata}) =>
        @documentInfo = info

        pdfTitle = null
        if metadata?.has 'dc:title'
          title = metadata.get 'dc:title'
          pdfTitle = title if title isnt 'Untitled'
        if (not pdfTitle?) and info?.Title
          pdfTitle = info.Title

        @model.title = pdfTitle if pdfTitle

        if info.IsAcroFormPresent
          console.warn "Warning: AcroForm/XFA is not supported"


  passwordNeeded: (updatePassword, reason) =>


  destroy: ->
    @detach()
