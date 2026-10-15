import Combine

class WindowRouter: ObservableObject {
    static let windowID = "main"

    @Published var activeSheet: ActiveSheet?
}
