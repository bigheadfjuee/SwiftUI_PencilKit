//
//  ContentView.swift
//  pencilTest
//
//  Created by Tony Lee on 2021/11/1.
//

import SwiftUI
import PencilKit

struct ContentView: View {
  @Environment(\.undoManager) private var undoManager
  @State private var canvasView = PKCanvasView()
  
  var body: some View {
    ZStack{
      MyPKCanvas(canvasView: $canvasView)
      
      VStack() {
        HStack(spacing: 20) {
          Button("Clear") {
            canvasView.drawing = PKDrawing()
          }
          Button("Undo") {
            undoManager?.undo()
          }
          Button("Redo") {
            undoManager?.redo()
          }
        }
        .padding(20)
        Spacer()
      }
    }// ZStack
  }// body
  
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
