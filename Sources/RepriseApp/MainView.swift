import SwiftUI
import RepriseCore

/// The one structure: library on the left, the page in the middle with the most room,
/// a quiet inspector on the right. Solid draws it as flat regions with hairlines;
/// Glass floats each region as its own pane over the blurred desktop.
struct MainView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let glass = Variant.glass
        let outline = Variant.library == .outline
        HStack(spacing: glass ? 8 : 0) {
            if model.showSidebar {
                LibrarySidebar(outline: outline)
                    .frame(width: outline ? 286 : 228)
                    .background(PaneBackground(tone: .deep))
                    .transition(.move(edge: .leading).combined(with: .opacity))
                divider
            }
            if !outline {
                PromptList()
                    .frame(width: 292)
                    .background(PaneBackground(tone: .mid))
                divider
            }
            EditorPane(leadingInset: model.showSidebar || !outline ? 0 : 70)
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                .background(PaneBackground(tone: .page))
            if model.showMargin, let p = model.current {
                divider
                VStack(spacing: 0) {
                    Color.clear.frame(height: glass ? 6 : 34)
                    InspectorView(prompt: p)
                }
                .frame(width: 286)
                .background(PaneBackground(tone: .deep))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(glass ? 8 : 0)
        .ignoresSafeArea(.container, edges: .top)
        .background(WindowGround().ignoresSafeArea())
        .animation(.easeOut(duration: 0.2), value: model.showSidebar)
        .animation(.easeOut(duration: 0.2), value: model.showMargin)
        .onChange(of: model.selectedID) { _, _ in revealCurrent() }
        .onAppear { revealCurrent() }
    }

    /// The outline always shows where the open prompt lives.
    private func revealCurrent() {
        guard Variant.library == .outline, let p = model.current else { return }
        model.openProjects.insert(p.projectID)
        if let sid = model.project(p.projectID)?.spaceID { model.foldedSpaces.remove(sid) }
    }

    @ViewBuilder private var divider: some View {
        if !Variant.glass { Hairline(vertical: true) }
    }
}

struct EditorPane: View {
    @Environment(AppModel.self) private var model
    var leadingInset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                if !model.showSidebar {
                    Button { withAnimation(.easeOut(duration: 0.2)) { model.showSidebar = true } } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .buttonStyle(IconButtonStyle())
                    .help("Show the sidebar (⌃⌘S)")
                }
                Spacer()
                if let p = model.current {
                    if !model.showMargin { CopyButton().padding(.trailing, 4) }
                    ActionsButton(prompt: p)
                    Button { model.showMargin.toggle() } label: { Image(systemName: "sidebar.right") }
                        .buttonStyle(IconButtonStyle())
                        .help(model.showMargin ? "Hide the inspector (⌥⌘0)" : "Show the inspector: blanks, files, agents (⌥⌘0)")
                }
                NewPromptButton().padding(.leading, 6)
            }
            .padding(.leading, 14 + leadingInset)
            .padding(.trailing, 14)
            .frame(height: 52)

            if let p = model.current {
                PageEditor(prompt: p, inset: 48, topPadding: 10)
            } else {
                StartHere()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
