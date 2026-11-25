import SwiftUI
import RepriseCore

/// Studio: editor-first. Prompts open in tabs like files in an editor, the library is a palette (⌘P),
/// and a run inspector sits beside the page so you can write and test a template in one place.
struct StudioView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("studioInspector") private var inspectorTab = "run"

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                StudioTabBar()
                Hairline()
                if let p = model.current {
                    HStack(spacing: 0) {
                        PageEditor(prompt: p)
                            .background(Folio.paper)
                        if model.showMargin {
                            Hairline(vertical: true)
                            inspector(p)
                                .frame(width: 330)
                                .background(Folio.paperDeep)
                        }
                    }
                } else {
                    StartHere(title: "Open a prompt, or write a new one.",
                              hints: [("⌘P", "Open a prompt"), ("⌘N", "New prompt"), ("⇧⌘H", "Harvest from agent history")])
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Folio.paper)
                }
                Hairline()
                StudioStatusBar()
            }
            .background(Folio.paper.ignoresSafeArea())

            if model.showPalette {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { model.showPalette = false }
                StudioPalette()
                    .padding(.top, 70)
                    .transition(.opacity.combined(with: .offset(y: -6)))
            }
        }
        .animation(.easeOut(duration: 0.14), value: model.showPalette)
        .onAppear {
            if model.scope != .all { model.scope = .all }
            model.openTabs = model.openTabs.filter { (try? model.store.prompt($0)) != nil }
            if model.selectedID == nil {
                if let first = model.openTabs.first { model.selectedID = first }
                else if let first = model.items.first?.id { model.open(first) }
            }
        }
        .onChange(of: model.selectedID) { _, id in
            if let id, !model.openTabs.contains(id) { model.openTabs.append(id) }
        }
    }

    private func inspector(_ p: Prompt) -> some View {
        VStack(spacing: 0) {
            Picker("", selection: $inspectorTab) {
                Text("Run").tag("run")
                Text("Details").tag("details")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            Hairline()
            if inspectorTab == "run" {
                RunPanel()
                    .padding(18)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView { DetailsView(prompt: p).padding(18) }
                    .scrollIndicators(.never)
            }
        }
    }
}

struct StudioTabBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            Button { model.showPalette = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2")
                    Text("Library")
                    Text("⌘P").font(.system(size: 11).monospacedDigit()).foregroundStyle(Folio.ash)
                }
            }
            .buttonStyle(GhostButtonStyle())
            .help("Open a prompt (⌘P)")
            .padding(.horizontal, 12)

            Hairline(vertical: true).frame(height: 22)

            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(model.openTabs, id: \.self) { id in
                        StudioTab(id: id, selected: id == model.selectedID)
                    }
                }
            }
            .scrollIndicators(.never)

            Spacer(minLength: 8)
            if let p = model.current {
                ActionsButton(prompt: p)
                Button { withAnimation(.easeOut(duration: 0.18)) { model.showMargin.toggle() } } label: {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(IconButtonStyle())
                .help("Show or hide the inspector (⌥⌘0)")
            }
            NewPromptButton()
                .padding(.leading, 6)
                .padding(.trailing, 14)
        }
        .frame(height: 46)
        .background(Folio.paperDeep)
    }
}

struct StudioTab: View {
    @Environment(AppModel.self) private var model
    let id: ID
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        let title = (selected ? model.current?.title : nil) ?? model.items.first { $0.id == id }?.title
            ?? (try? model.store.prompt(id))?.title ?? "Prompt"
        HStack(spacing: 7) {
            Text(title)
                .font(.system(size: 12.5, weight: selected ? .semibold : .regular, design: Folio.style.textDesign))
                .foregroundStyle(selected ? Folio.ink : Folio.slate)
                .lineLimit(1)
                .frame(maxWidth: 170, alignment: .leading)
            Button { model.closeTab(id) } label: { Image(systemName: "xmark").font(.system(size: 8.5, weight: .bold)) }
                .buttonStyle(.plain)
                .foregroundStyle(Folio.slate)
                .opacity(selected || hovering ? 1 : 0)
                .help("Close tab")
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(selected ? Folio.paper : hovering ? Folio.wash : .clear)
        .overlay(alignment: .top) {
            if selected { Rectangle().fill(Folio.rubric).frame(height: 2) }
        }
        .overlay(alignment: .trailing) { Hairline(vertical: true) }
        .contentShape(Rectangle())
        .onTapGesture { model.selectedID = id }
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Close Tab") { model.closeTab(id) }
            Button("Close Other Tabs") { model.openTabs = [id]; model.selectedID = id }
        }
    }
}

struct StudioStatusBar: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        HStack(spacing: 14) {
            if let p = model.current {
                PlaceText(projectID: p.projectID)
                Spacer()
                let s = model.liveStats
                Text("\(s.tokens.formatted()) tokens")
                Text("\(model.blanks.count) blanks")
                Text(s.saved ? "Saved" : "Editing").foregroundStyle(s.saved ? Folio.slate : Folio.rubric)
            } else {
                Spacer()
            }
        }
        .font(.system(size: 11.5).monospacedDigit())
        .foregroundStyle(Folio.slate)
        .padding(.horizontal, 16)
        .frame(height: 28)
        .background(Folio.paperDeep)
    }
}

/// ⌘P: find a prompt by name or text and open it in a tab.
struct StudioPalette: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool
    @State private var index = 0

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Folio.slate)
                TextField("Open a prompt", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .focused($focused)
                    .onKeyPress(.downArrow) { index = min(index + 1, max(model.items.count - 1, 0)); return .handled }
                    .onKeyPress(.upArrow) { index = max(index - 1, 0); return .handled }
                    .onKeyPress(.escape) { model.showPalette = false; return .handled }
                    .onSubmit { pick(index) }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            Hairline()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(model.items.prefix(60).enumerated()), id: \.element.id) { i, item in
                            HStack(spacing: 10) {
                                ColorKey(hex: item.color, size: 7)
                                Text(item.title).font(.system(size: 13.5, design: Folio.style.textDesign)).foregroundStyle(Folio.ink).lineLimit(1)
                                Spacer()
                                Text(model.project(item.projectID)?.name ?? "").font(.system(size: 11.5)).foregroundStyle(Folio.slate)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(i == index ? Folio.ink.opacity(0.09) : .clear))
                            .contentShape(Rectangle())
                            .onTapGesture { pick(i) }
                            .id(i)
                        }
                        if model.items.isEmpty {
                            Button { model.showPalette = false; model.newPrompt(title: model.query.isEmpty ? "Untitled prompt" : model.query) } label: {
                                HStack { Image(systemName: "plus"); Text(model.query.isEmpty ? "New prompt" : "New prompt “\(model.query)”"); Spacer() }
                                    .font(.system(size: 13.5)).foregroundStyle(Folio.ink)
                                    .padding(.horizontal, 12).frame(height: 34)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                }
                .onChange(of: index) { _, i in proxy.scrollTo(i) }
            }
            .frame(maxHeight: 360)
        }
        .frame(width: 600)
        .fixedSize(horizontal: false, vertical: true)
        .background(Folio.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Folio.rule, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 30, y: 14)
        .onAppear { focused = true; index = 0 }
        .onChange(of: model.query) { index = 0 }
    }

    private func pick(_ i: Int) {
        guard model.items.indices.contains(i) else { return }
        model.open(model.items[i].id)
        model.showPalette = false
        model.query = ""
    }
}
