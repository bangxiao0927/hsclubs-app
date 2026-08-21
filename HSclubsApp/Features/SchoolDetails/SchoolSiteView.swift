import SwiftUI

struct SchoolSiteView: View {
    let school: DirectorySchool
    let siteURL: URL
    let mobileAuthEnabled: Bool
    @Bindable var schoolSelection: SchoolSelection

    @State private var isLoading = false
    @State private var failureMessage: String?
    @State private var login = MobileAuthLoginController(webAuth: ASWebAuthenticationRunner())
    @State private var webSession = SchoolWebSession()

    init(
        school: DirectorySchool,
        siteURL: URL,
        mobileAuthEnabled: Bool,
        schoolSelection: SchoolSelection
    ) {
        self.school = school
        self.siteURL = siteURL
        self.mobileAuthEnabled = mobileAuthEnabled
        self.schoolSelection = schoolSelection
    }

    var body: some View {
        ZStack {
            SchoolSiteWebView(
                url: siteURL,
                mobileAuthEnabled: mobileAuthEnabled,
                onLoadingChanged: { isLoading = $0 },
                onFailure: { failureMessage = $0 },
                onLoginRequested: { returnTo in
                    guard mobileAuthEnabled, school.mobileAuth else { return }
                    Task { await login.signIn(to: school, returnTo: returnTo, using: webSession) }
                },
                onWebViewCreated: { webSession.attach($0) }
            )
            .ignoresSafeArea()

            if let failureMessage {
                VStack {
                    Label(failureMessage, systemImage: "wifi.exclamationmark")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(12)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 12)
                    Spacer()
                }
            }

            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                        .padding(12)
                        .background(.regularMaterial, in: Capsule())
                        .accessibilityLabel("Loading school site")
                }
            }

            FloatingSchoolButton(school: school, schoolSelection: schoolSelection)
        }
        // A signing-in overlay while the system sheet is dismissed and the code is spent.
        .overlay {
            if login.state == .completing {
                ProgressView("Signing in...")
                    .padding(16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert(
            "Sign-in problem",
            isPresented: Binding(
                get: { if case .failed = login.state { return true } else { return false } },
                set: { presented in if !presented { login.dismissFailure() } }
            )
        ) {
            Button("OK", role: .cancel) { login.dismissFailure() }
        } message: {
            if case .failed(let message) = login.state { Text(message) }
        }
    }
}

private struct FloatingSchoolButton: View {
    let school: DirectorySchool
    @Bindable var schoolSelection: SchoolSelection

    @State private var dragTranslation = CGSize.zero
    @State private var restingCenterY: CGFloat = 220
    @State private var edge: FloatingSwitcherEdge = .trailing
    @State private var didDrag = false
    @State private var suppressTap = false
    @State private var isExpanded = false
    @State private var collapseTask: Task<Void, Never>?

    private let layout = FloatingSwitcherLayout()

    private var size: CGFloat { layout.buttonSize }

    var body: some View {
        GeometryReader { geometry in
            let bounds = geometry.size

            ZStack {
                if isExpanded {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                                isExpanded = false
                            }
                        }
                        .accessibilityIdentifier("switcher-tap-away")
                }

                HStack(spacing: 12) {
                    if isExpanded && edge == .trailing {
                        panel
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }

                    ball
                        .scaleEffect(didDrag ? 0.86 : 1)
                        .overlay {
                            FloatingSwitcherGestureView(
                                onTap: togglePanel,
                                onDragChanged: handleDragChanged,
                                onDragEnded: { translation in
                                    handleDragEnded(translation, in: bounds)
                                }
                            )
                            .contentShape(Circle())
                        }
                        .accessibilityAction {
                            togglePanel()
                        }

                    if isExpanded && edge == .leading {
                        panel
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edgeAlignment)
                .offset(
                    x: currentOffsetX,
                    y: currentOffsetY(in: bounds)
                )
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.88), value: isExpanded)
            .animation(.easeOut(duration: 0.15), value: didDrag)
            .onChange(of: schoolSelection.isSwitching) { _, isSwitching in
                if isSwitching { cancelCollapse() }
            }
            .onDisappear {
                cancelCollapse()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var ball: some View {
        Image(systemName: "graduationcap")
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(.black.opacity(0.72), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
            .contentShape(Circle())
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(isExpanded ? "Close school options" : "Open school options")
            .accessibilityIdentifier("school-site-back")
    }

    private var panel: some View {
        Button {
            schoolSelection.requestSwitch()
        } label: {
            Label("Switch School", systemImage: "arrow.left.arrow.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.black.opacity(0.78), in: Capsule())
        }
        .accessibilityIdentifier("switch-school-action")
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }

    private var edgeAlignment: Alignment {
        edge == .trailing ? .trailing : .leading
    }

    private var currentOffsetX: CGFloat {
        layout.horizontalOffset(
            edge: edge,
            translationX: dragTranslation.width,
            isExpanded: isExpanded
        )
    }

    private func currentOffsetY(in bounds: CGSize) -> CGFloat {
        clampedCenterY(restingCenterY + dragTranslation.height, in: bounds) - bounds.height / 2
    }

    private func clampedCenterY(_ value: CGFloat, in bounds: CGSize) -> CGFloat {
        layout.clampedCenterY(value, height: bounds.height)
    }

    private func togglePanel() {
        guard !suppressTap else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
            isExpanded.toggle()
        }
        scheduleCollapseIfNeeded()
    }

    private func scheduleCollapseIfNeeded() {
        collapseTask?.cancel()
        guard isExpanded else { return }
        collapseTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                isExpanded = false
            }
        }
    }

    private func cancelCollapse() {
        collapseTask?.cancel()
        collapseTask = nil
    }

    private func handleDragChanged(_ translation: CGSize) {
        if isExpanded {
            isExpanded = false
            cancelCollapse()
        }
        didDrag = true
        suppressTap = true
        dragTranslation = translation
    }

    private func handleDragEnded(_ translation: CGSize, in bounds: CGSize) {
        withAnimation(.easeOut(duration: 0.42)) {
            edge = layout.resolvedEdge(
                from: edge,
                translationX: translation.width,
                width: bounds.width
            )
            restingCenterY = clampedCenterY(
                restingCenterY + translation.height,
                in: bounds
            )
            dragTranslation = .zero
            didDrag = false
        }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            suppressTap = false
        }
    }
}
