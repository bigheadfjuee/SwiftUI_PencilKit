//
//  MyCanvas.swift
//  pencilTest
//
//  Created by Tony Lee on 2021/11/1.
//

import Foundation
import SwiftUI
import PencilKit

struct MyPKCanvas: UIViewRepresentable {
  @Binding var canvasView: PKCanvasView
  let picker = PKToolPicker.init()
  
  func makeUIView(context: Context) -> PKCanvasView {
    canvasView.drawingPolicy = .default // iPad 可由 toolpicker 的選項去設定 (Draw with Finger)
    self.canvasView.tool = PKInkingTool(.pen, color: .red, width: 15)
    self.canvasView.becomeFirstResponder()
    return canvasView
  }
  
  func updateUIView(_ uiView: PKCanvasView, context: Context) {
    picker.addObserver(canvasView)
    picker.setVisible(true, forFirstResponder: uiView)
    DispatchQueue.main.async {
      uiView.becomeFirstResponder()
    }
  }
  
}
