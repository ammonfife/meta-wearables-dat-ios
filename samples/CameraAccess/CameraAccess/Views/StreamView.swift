/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// StreamView.swift
//
// Main UI for video streaming from Meta wearable devices using the DAT SDK.
// This view demonstrates the complete streaming API: video streaming with real-time display, photo capture,
// and error handling.
//

import MWDATCore
import SwiftUI

struct StreamView: View {
  @ObservedObject var viewModel: StreamSessionViewModel
  @ObservedObject var wearablesVM: WearablesViewModel
  @ObservedObject var scannerVM: ScannerViewModel

  var body: some View {
    ZStack {
      // Black background for letterboxing/pillarboxing
      Color.black
        .edgesIgnoringSafeArea(.all)

      // Video backdrop
      if let videoFrame = viewModel.currentVideoFrame, viewModel.hasReceivedFirstFrame {
        GeometryReader { geometry in
          Image(uiImage: videoFrame)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .edgesIgnoringSafeArea(.all)
      } else {
        ProgressView()
          .scaleEffect(1.5)
          .foregroundColor(.white)
      }

      // Coin result overlay
      if scannerVM.showResult, let coin = scannerVM.lastResult {
        CoinResultView(coin: coin, onDismiss: { scannerVM.dismissResult() })
          .animation(.spring(response: 0.4), value: scannerVM.showResult)
      }

      // Bottom controls layer
      VStack {
        Spacer()
        ControlsView(viewModel: viewModel, scannerVM: scannerVM)
      }
      .padding(.all, 24)
    }
    .onDisappear {
      Task {
        if viewModel.streamingStatus != .stopped {
          await viewModel.stopSession()
        }
      }
    }
    // Show captured photos from DAT SDK in a preview sheet
    .sheet(isPresented: $viewModel.showPhotoPreview) {
      if let photo = viewModel.capturedPhoto {
        PhotoPreviewView(
          photo: photo,
          onDismiss: {
            viewModel.dismissPhotoPreview()
          }
        )
      }
    }
  }
}

// Extracted controls for clarity
struct ControlsView: View {
  @ObservedObject var viewModel: StreamSessionViewModel
  @ObservedObject var scannerVM: ScannerViewModel

  private let gold = Color(red: 0.831, green: 0.686, blue: 0.216)

  var body: some View {
    // Controls row
    HStack(spacing: 8) {
      CustomButton(
        title: "Stop streaming",
        style: .destructive,
        isDisabled: false
      ) {
        Task {
          await viewModel.stopSession()
        }
      }

      // Coin scan button
      ZStack {
        CircleButton(icon: scannerVM.isScanning ? "circle.dotted" : "dollarsign.circle.fill", text: nil) {
          scannerVM.scan()
        }
        .tint(gold)
        .disabled(scannerVM.isScanning)

        if scannerVM.isScanning {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: gold))
            .allowsHitTesting(false)
        }
      }

      // Photo button
      CircleButton(icon: "camera.fill", text: nil) {
        viewModel.capturePhoto()
      }
    }
  }
}
