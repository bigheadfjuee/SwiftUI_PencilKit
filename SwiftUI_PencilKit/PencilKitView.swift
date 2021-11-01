//
//  PencilKitView.swift
//  live-camera
//
//  Created by Tony Lee on 2021/10/28.
//
import UIKit
import PencilKit
import SwiftUI

struct PencilKitVC : UIViewControllerRepresentable {
  typealias UIViewControllerType = DrawingViewController
  public var vc = DrawingViewController()
  
  func makeUIViewController(context: Context) -> UIViewControllerType {
    return vc
  }
  
  func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
  }
}

class DrawingViewController: UIViewController, PKCanvasViewDelegate, PKToolPickerObserver, UIScreenshotServiceDelegate {
  
  var canvasView: PKCanvasView!
  var undoBarButtonitem: UIBarButtonItem!
  var redoBarButtonItem: UIBarButtonItem!
  
  var toolPicker: PKToolPicker!
  
  /// On iOS 14.0, this is no longer necessary as the finger vs pencil toggle is a global setting in the toolpicker
  var pencilFingerBarButtonItem: UIBarButtonItem!
  
  /// Standard amount of overscroll allowed in the canvas.
  static let canvasOverscrollHeight: CGFloat = 500
  
  /// Data model for the drawing displayed by this view controller.
  var dataModelController: DataModelController!
  
  /// Private drawing sta/Users/tony/Documents/BitBucket/BextCam/live-camera/PencilKitView.swiftte./Users/tony/Documents/BitBucket/BextCam/live-camera/PencilKitView.swift
  var drawingIndex: Int = 0
  var hasModifiedDrawing = false
  
  
  override func viewDidLoad() {
    
    canvasView = PKCanvasView(frame: UIScreen.main.bounds)
//    debugPrint(canvasView.frame)    
    view = canvasView
    
    dataModelController = DataModelController()
    
    undoBarButtonitem = UIBarButtonItem()
    redoBarButtonItem = UIBarButtonItem()
    pencilFingerBarButtonItem = UIBarButtonItem()
    
    canvasView.tool = PKInkingTool(.pen, color: .red, width: 20)
    
    canvasView.backgroundColor = .clear
    
    // for iPhone Fix
    canvasView.isOpaque = true  
    canvasView.drawingPolicy = .anyInput
    canvasView.isPagingEnabled = false
    canvasView.isScrollEnabled = false
  }
  /// Set up the drawing initially.
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // Set up the canvas view with the first drawing from the data model.
    // TODO: delegate
    canvasView.delegate = self
    canvasView.alwaysBounceVertical = true
    
    // Set up the tool picker
    if #available(iOS 14.0, *) {
      toolPicker = PKToolPicker()
    } else {
      // Set up the tool picker, using the window of our parent because our view has not
      // been added to a window yet.
      let window = parent?.view.window
      toolPicker = PKToolPicker.shared(for: window!)
    }
    
    toolPicker.setVisible(true, forFirstResponder: canvasView)
    toolPicker.addObserver(canvasView)
    toolPicker.addObserver(self)
    updateLayout(for: toolPicker)
    canvasView.becomeFirstResponder()
    
    // Before iOS 14, add a button to toggle finger drawing.
    if #available(iOS 14.0, *) { } else {
      pencilFingerBarButtonItem = UIBarButtonItem(title: "Enable Finger Drawing",
                                                  style: .plain,
                                                  target: self,
                                                  action: #selector(toggleFingerPencilDrawing(_:)))
      canvasView.allowsFingerDrawing = false
    }
    
    // Set this view controller as the delegate for creating full screenshots.
    parent?.view.window?.windowScene?.screenshotService?.delegate = self
  }
  
  /// When the view is resized, adjust the canvas scale so that it is zoomed to the default `canvasWidth`.
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    let canvasScale = canvasView.bounds.width / DataModel.canvasWidth
    canvasView.minimumZoomScale = canvasScale
    canvasView.maximumZoomScale = canvasScale
    canvasView.zoomScale = canvasScale
    
    // Scroll to the top.
    updateContentSizeForDrawing()
    canvasView.contentOffset = CGPoint(x: 0, y: -canvasView.adjustedContentInset.top)
  }
  
  /// When the view is removed, save the modified drawing, if any.
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    // Update the drawing in the data model, if it has changed.
    if hasModifiedDrawing {
      //            dataModelController.updateDrawing(canvasView.drawing, at: drawingIndex)
    }
    
    // Remove this view controller as the screenshot delegate.
    view.window?.windowScene?.screenshotService?.delegate = nil
  }
  
  /// Hide the home indicator, as it will affect latency.
  override var prefersHomeIndicatorAutoHidden: Bool {
    return true
  }
  
  // MARK: Actions
  
  /// Action method: Turn finger drawing on or off, but only on devices before iOS 14.0
  @IBAction func toggleFingerPencilDrawing(_ sender: Any) {
    if #available(iOS 14.0, *) { } else {
      canvasView.allowsFingerDrawing.toggle()
      let title = canvasView.allowsFingerDrawing ? "Disable Finger Drawing" : "Enable Finger Drawing"
      pencilFingerBarButtonItem.title = title
    }
  }
  
  /// Helper method to set a new drawing, with an undo action to go back to the old one.
  func setNewDrawingUndoable(_ newDrawing: PKDrawing) {
    let oldDrawing = canvasView.drawing
    undoManager?.registerUndo(withTarget: self) {
      $0.setNewDrawingUndoable(oldDrawing)
    }
    canvasView.drawing = newDrawing
  }
  
  /// Action method: Add a signature to the current drawing.
  @IBAction func signDrawing(sender: UIBarButtonItem) {
    
    // Get the signature drawing at the canvas scale.
    var signature = dataModelController.signature
    let signatureBounds = signature.bounds
    let loc = CGPoint(x: canvasView.bounds.maxX, y: canvasView.bounds.maxY)
    let scaledLoc = CGPoint(x: loc.x / canvasView.zoomScale, y: loc.y / canvasView.zoomScale)
    signature.transform(using: CGAffineTransform(translationX: scaledLoc.x - signatureBounds.maxX, y: scaledLoc.y - signatureBounds.maxY))
    
    // Add the signature drawing to the current canvas drawing.
    setNewDrawingUndoable(canvasView.drawing.appending(signature))
  }
  
  // MARK: Navigation
  
  /// Set up the signature view controller.
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    //        (segue.destination as? SignatureViewController)?.dataModelController = dataModelController
  }
  
  // MARK: Canvas View Delegate
  
  /// Delegate method: Note that the drawing has changed.
  func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
    hasModifiedDrawing = true
    updateContentSizeForDrawing()
  }
  
  /// Helper method to set a suitable content size for the canvas view.
  func updateContentSizeForDrawing() {
    // Update the content size to match the drawing.
    let drawing = canvasView.drawing
    let contentHeight: CGFloat
    
    // Adjust the content size to always be bigger than the drawing height.
    if !drawing.bounds.isNull {
      contentHeight = max(canvasView.bounds.height, (drawing.bounds.maxY + DrawingViewController.canvasOverscrollHeight) * canvasView.zoomScale)
    } else {
      contentHeight = canvasView.bounds.height
    }
    canvasView.contentSize = CGSize(width: DataModel.canvasWidth * canvasView.zoomScale, height: contentHeight)
  }
  
  // MARK: Tool Picker Observer
  
  /// Delegate method: Note that the tool picker has changed which part of the canvas view
  /// it obscures, if any.
  func toolPickerFramesObscuredDidChange(_ toolPicker: PKToolPicker) {
    updateLayout(for: toolPicker)
  }
  
  /// Delegate method: Note that the tool picker has become visible or hidden.
  func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) {
    updateLayout(for: toolPicker)
  }
  
  /// Helper method to adjust the canvas view size when the tool picker changes which part
  /// of the canvas view it obscures, if any.
  ///
  /// Note that the tool picker floats over the canvas in regular size classes, but docks to
  /// the canvas in compact size classes, occupying a part of the screen that the canvas
  /// could otherwise use.
  func updateLayout(for toolPicker: PKToolPicker) {
    let obscuredFrame = toolPicker.frameObscured(in: view)
    
    // If the tool picker is floating over the canvas, it also contains
    // undo and redo buttons.
    if obscuredFrame.isNull {
      canvasView.contentInset = .zero
    }
    
    // Otherwise, the bottom of the canvas should be inset to the top of the
    // tool picker, and the tool picker no longer displays its own undo and
    // redo buttons.
    else {
      canvasView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: view.bounds.maxY - obscuredFrame.minY, right: 0)
    }
    canvasView.scrollIndicatorInsets = canvasView.contentInset
  }
  
  // MARK: Screenshot Service Delegate
  
  /// Delegate method: Generate a screenshot as a PDF.
  func screenshotService(
    _ screenshotService: UIScreenshotService,
    generatePDFRepresentationWithCompletion completion:
    @escaping (_ PDFData: Data?, _ indexOfCurrentPage: Int, _ rectInCurrentPage: CGRect) -> Void) {
      
      // Find out which part of the drawing is actually visible.
      let drawing = canvasView.drawing
      let visibleRect = canvasView.bounds
      
      // Convert to PDF coordinates, with (0, 0) at the bottom left hand corner,
      // making the height a bit bigger than the current drawing.
      let pdfWidth = DataModel.canvasWidth
      let pdfHeight = drawing.bounds.maxY + 100
      let canvasContentSize = canvasView.contentSize.height - DrawingViewController.canvasOverscrollHeight
      
      let xOffsetInPDF = pdfWidth - (pdfWidth * visibleRect.minX / canvasView.contentSize.width)
      let yOffsetInPDF = pdfHeight - (pdfHeight * visibleRect.maxY / canvasContentSize)
      let rectWidthInPDF = pdfWidth * visibleRect.width / canvasView.contentSize.width
      let rectHeightInPDF = pdfHeight * visibleRect.height / canvasContentSize
      
      let visibleRectInPDF = CGRect(
        x: xOffsetInPDF,
        y: yOffsetInPDF,
        width: rectWidthInPDF,
        height: rectHeightInPDF)
      
      // Generate the PDF on a background thread.
      DispatchQueue.global(qos: .background).async {
        
        // Generate a PDF.
        let bounds = CGRect(x: 0, y: 0, width: pdfWidth, height: pdfHeight)
        let mutableData = NSMutableData()
        UIGraphicsBeginPDFContextToData(mutableData, bounds, nil)
        UIGraphicsBeginPDFPage()
        
        // Generate images in the PDF, strip by strip.
        var yOrigin: CGFloat = 0
        let imageHeight: CGFloat = 1024
        while yOrigin < bounds.maxY {
          let imgBounds = CGRect(x: 0, y: yOrigin, width: DataModel.canvasWidth, height: min(imageHeight, bounds.maxY - yOrigin))
          let img = drawing.image(from: imgBounds, scale: 2)
          img.draw(in: imgBounds)
          yOrigin += imageHeight
        }
        
        UIGraphicsEndPDFContext()
        
        // Invoke the completion handler with the generated PDF data.
        completion(mutableData as Data, 0, visibleRectInPDF)
      }
    }
}
