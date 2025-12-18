import SwiftUI

/// Root content view that switches between blog selector and main editor
public struct ContentView: View {
    @State private var viewModel = BlogViewModel()

    public init() {}

    public var body: some View {
        Group {
            if viewModel.hasBlogSelected {
                MainEditorView(viewModel: viewModel)
            } else {
                BlogSelectorView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
