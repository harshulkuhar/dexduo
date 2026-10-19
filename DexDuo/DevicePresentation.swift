import SwiftUI
import UIKit

extension DeviceProfile {
    var orientationMask: UIInterfaceOrientationMask { self == .phone ? .landscape : .portrait }
}

@MainActor final class DevicePresentation: ObservableObject {
    @Published private(set) var state = DeviceProfileState()
    @Published private(set) var orientationFailed = false
    private weak var window: UIWindow?
    private var requestedLandscape = false
    private static var sceneProfiles: [ObjectIdentifier: DeviceProfile] = [:]

    static func orientations(for window: UIWindow?) -> UIInterfaceOrientationMask {
        guard let scene = window?.windowScene else { return .portrait }
        return (sceneProfiles[ObjectIdentifier(scene)] ?? .unresolved).orientationMask
    }

    func observe(window: UIWindow?, hasHinge: Bool, closed: Bool?) {
        guard let window, let scene = window.windowScene else { return }
        if self.window?.windowScene !== scene { requestedLandscape = false }
        self.window = window
        var next = state
        next.observe(isPhone: UIDevice.current.userInterfaceIdiom == .phone,
                     attached: true, hasHinge: hasHinge, closed: closed)
        let changedProfile = next.profile != state.profile
        if next.profile != state.profile || next.isFolded != state.isFolded { state = next }
        Self.sceneProfiles[ObjectIdentifier(scene)] = next.profile
        if changedProfile { window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
        requestLandscapeIfNeeded()
    }

    func requestLandscapeIfNeeded(retry: Bool = false) {
        guard state.profile == .phone, let scene = window?.windowScene else { return }
        if scene.interfaceOrientation.isLandscape {
            requestedLandscape = false
            orientationFailed = false
            return
        }
        if retry { requestedLandscape = false }
        guard !requestedLandscape, scene.activationState == .foregroundActive else { return }
        requestedLandscape = true
        orientationFailed = false
        Task { @MainActor [weak self, weak scene] in
            await Task.yield()
            guard let self, let scene, self.state.profile == .phone,
                  self.window?.windowScene === scene, scene.activationState == .foregroundActive else { return }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { [weak self] _ in
                Task { @MainActor in
                    self?.requestedLandscape = false
                    self?.orientationFailed = true
                }
            }
        }
    }
}

struct DeviceProfileProbe: UIViewRepresentable {
    let presentation: DevicePresentation

    func makeUIView(context: Context) -> ProbeView { ProbeView(presentation: presentation) }
    func updateUIView(_ view: ProbeView, context: Context) {}

    final class ProbeView: UIView {
        private weak var presentation: DevicePresentation?
        private var hingeInteraction: (any UIInteraction)?

        init(presentation: DevicePresentation) {
            self.presentation = presentation
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            if #available(iOS 27.1, *), UIDevice.current.userInterfaceIdiom == .phone {
                if hingeInteraction == nil {
                    let interaction = UIHingeInteraction { [weak self] _, update in
                        guard let self else { return }
                        let closed: Bool? = update.hinge.flatMap { hinge in
                            hinge.status == .unknown ? nil : hinge.status == .closed
                        }
                        self.presentation?.observe(window: self.window, hasHinge: update.hinge != nil, closed: closed)
                    }
                    hingeInteraction = interaction
                    addInteraction(interaction)
                }
            } else {
                presentation?.observe(window: window, hasHinge: false, closed: nil)
            }
        }
    }
}
