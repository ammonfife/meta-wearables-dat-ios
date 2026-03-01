/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// StreamSessionView.swift
//
//

import MWDATCore
import SwiftUI

struct StreamSessionView: View {
  let wearables: WearablesInterface
  @ObservedObject private var wearablesViewModel: WearablesViewModel
  @StateObject private var viewModel: StreamSessionViewModel
  @StateObject private var scannerVM: ScannerViewModel

  init(wearables: WearablesInterface, wearablesVM: WearablesViewModel) {
    self.wearables = wearables
    self.wearablesViewModel = wearablesVM
    let streamVM = StreamSessionViewModel(wearables: wearables)
    self._viewModel = StateObject(wrappedValue: streamVM)
    self._scannerVM = StateObject(wrappedValue: ScannerViewModel(streamVM: streamVM))
  }

  var body: some View {
    ZStack {
      if viewModel.isStreaming {
        // Full-screen video view with streaming controls + coin scanner
        StreamView(viewModel: viewModel, wearablesVM: wearablesViewModel, scannerVM: scannerVM)
      } else {
        // Pre-streaming setup view with permissions and start button
        NonStreamView(viewModel: viewModel, wearablesVM: wearablesViewModel)
      }
    }
    .alert("Error", isPresented: $viewModel.showError) {
      Button("OK") {
        viewModel.dismissError()
      }
    } message: {
      Text(viewModel.errorMessage)
    }
  }
}
