import PTCore
import SwiftUI

// MARK: - One request to the on-device model

/// One streamed answer from Apple's on-device model, for one card. Starting again cancels the last one.
@MainActor @Observable
final class OnDeviceAsk {
    private(set) var text = ""
    private(set) var running = false
    private(set) var error: String?
    private(set) var finishedAt: Date?
    @ObservationIgnored private var task: Task<Void, Never>?

    func run(instructions: String, prompt: String) {
        task?.cancel()
        text = ""
        error = nil
        finishedAt = nil
        running = true
        task = Task {
            do {
                try await LocalModel.stream(instructions: instructions, prompt: prompt) { soFar in
                    guard !Task.isCancelled else { return }
                    self.text = soFar
                }
                if !Task.isCancelled { self.finishedAt = Date() }
            } catch is CancellationError {
            } catch {
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
            if !Task.isCancelled { self.running = false }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        running = false
    }
}

/// Says whether Apple Intelligence can run here, honestly, before anyone taps.
struct LocalModelStatusLine: View {
    let status: LocalModelStatus

    var body: some View {
        Label {
            Text(status.isAvailable ? "Runs on this device with Apple Intelligence. Nothing is sent anywhere."
                                    : "Not available on this device: \(status.text)")
        } icon: {
            Image(systemName: status.isAvailable ? "sparkles" : "exclamationmark.circle")
        }
        .font(.caption)
        .foregroundStyle(status.isAvailable ? Palette.muted : Palette.amber)
    }
}

/// The answer as it streams, then where it came from.
struct OnDeviceAnswer: View {
    let ask: OnDeviceAsk

    var body: some View {
        if !ask.text.isEmpty || ask.running {
            VStack(alignment: .leading, spacing: Space.s) {
                if ask.text.isEmpty {
                    HStack(spacing: Space.s) {
                        ProgressView().controlSize(.small)
                        Text("Apple Intelligence is reading the page on this device…").font(.footnote).foregroundStyle(Palette.muted)
                    }
                } else {
                    Text(ask.text).font(.callout).foregroundStyle(Palette.ink).textSelection(.enabled)
                        .animation(.easeOut(duration: 0.15), value: ask.text)
                }
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text(ask.running ? "Generating on this device…" : "Generated on this device by Apple Intelligence, from the page's own facts. It can be wrong: the sources are below.")
                }
                .font(.caption2)
                .foregroundStyle(Palette.blue)
            }
            .padding(Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: Space.radius, style: .continuous))
        }
        if let error = ask.error {
            Label(error, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Palette.amber)
        }
    }
}

/// A card that asks the on-device model one thing about the page, and streams the answer.
struct OnDeviceCard: View {
    let title: String
    let kicker: String
    let action: String
    let instructions: String
    let prompt: () -> String

    @State private var ask = OnDeviceAsk()
    @State private var status = LocalModel.status

    var body: some View {
        TitledCard(title, kicker: kicker) {
            LocalModelStatusLine(status: status)
            if status.isAvailable {
                HStack {
                    Button {
                        ask.run(instructions: instructions, prompt: prompt())
                    } label: {
                        Label(ask.finishedAt == nil ? action : "Again", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(ask.running)
                    if ask.running {
                        Button("Stop") { ask.cancel() }.buttonStyle(.bordered)
                    }
                }
            }
            OnDeviceAnswer(ask: ask)
        }
        .onAppear { status = LocalModel.status }
        .onDisappear { ask.cancel() }
    }
}

// MARK: - A story, asked about

/// Summarise one story, or explain its AI path, on the device. Opens from a story's sparkles button.
struct StoryAISheet: View {
    let story: PlaceSite.News
    let town: String?
    @Environment(\.dismiss) private var dismiss
    @State private var ask = OnDeviceAsk()
    @State private var status = LocalModel.status

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.m) {
                    if let town { Kicker(town) }
                    Text(story.title).font(Typo.story).foregroundStyle(Palette.ink)
                    if let url = story.sourceURL {
                        Link(destination: url) { Label("Read it at \(story.publisher ?? url.host() ?? "the source")", systemImage: "arrow.up.right") }
                            .font(.footnote)
                    }
                    LocalModelStatusLine(status: status)
                    if status.isAvailable {
                        HStack {
                            Button {
                                ask.run(instructions: LocalPrompts.storyInstructions, prompt: LocalPrompts.story(story, town: town))
                            } label: { Label("Summarise", systemImage: "text.quote") }
                            Button {
                                ask.run(instructions: LocalPrompts.aiPathInstructions, prompt: LocalPrompts.aiPath(story, town: town))
                            } label: { Label("Explain the AI path", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }
                        }
                        .buttonStyle(.bordered)
                        .disabled(ask.running)
                    } else if let path = story.aiPath {
                        // No model: the newsroom's own words are still the answer.
                        TitledCard("The AI path", kicker: story.stepsLabel ?? "as the newsroom wrote it") {
                            Text(path).font(.callout)
                        }
                    }
                    OnDeviceAnswer(ask: ask)
                }
                .padding()
                .frame(maxWidth: 700, alignment: .leading)
            }
            .navigationTitle("Apple Intelligence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .onDisappear { ask.cancel() }
    }
}

/// A small sparkles button that opens the story's on-device summary and "explain the AI path".
public struct StorySummaryButton: View {
    let story: PlaceSite.News
    let town: String?
    @State private var showing = false

    public init(story: PlaceSite.News, town: String?) {
        self.story = story
        self.town = town
    }

    public var body: some View {
        Button {
            showing = true
        } label: {
            Label("Ask Apple Intelligence", systemImage: "sparkles").labelStyle(.iconOnly)
                .font(.footnote).foregroundStyle(Palette.blue)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Summarise or explain this story with Apple Intelligence on this device")
        .sheet(isPresented: $showing) { StoryAISheet(story: story, town: town) }
        // A story under a rights hold is never summarised or explained on the device.
        .opacity(story.isHeld ? 0 : 1)
        .disabled(story.isHeld)
        .accessibilityHidden(story.isHeld)
    }
}

// MARK: - Persona mode

/// "For you" chip on a highlighted item: which of the persona's words matched.
struct PersonaMatchChip: View {
    let match: PersonaMatch

    var body: some View {
        if match.isMatch {
            Label("For you: " + match.matched.prefix(3).joined(separator: ", "), systemImage: "person.crop.circle.badge.checkmark")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .foregroundStyle(Palette.green)
                .background(Palette.green.opacity(0.12), in: Capsule())
                .accessibilityLabel("Matches your persona: \(match.matched.joined(separator: ", "))")
        }
    }
}

/// The header that says persona mode is on, with a way to change it or turn it off. With no persona, an invitation.
public struct PersonaBanner: View {
    @State private var personas = PersonaStore.shared
    @State private var picking = false

    public init() {}

    public var body: some View {
        Group {
            if let persona = personas.persona {
                HStack(alignment: .top, spacing: Space.m) {
                    Image(systemName: "person.crop.circle.badge.checkmark").font(.title2).foregroundStyle(Palette.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Persona mode: \(persona.label)").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        Text(explanation(persona))
                            .font(.caption).foregroundStyle(Palette.muted)
                        suggestions
                    }
                    Spacer(minLength: Space.s)
                    VStack(spacing: Space.xs) {
                        Button("Change") { picking = true }.font(.caption)
                        Button("Off") { personas.persona = nil }.font(.caption).tint(Palette.red)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(Space.m)
                .background(Palette.green.opacity(0.08), in: RoundedRectangle(cornerRadius: Space.radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Space.radius, style: .continuous).strokeBorder(Palette.green.opacity(0.35)))
            } else {
                Button {
                    picking = true
                } label: {
                    Label("Who are you? Pick a persona and the Algarve reorders for you", systemImage: "person.crop.circle.badge.questionmark")
                        .font(.footnote)
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $picking) { PersonaPicker() }
    }

    /// Apple Intelligence can widen the ranking with words of its own; they are shown, and marked as its.
    @ViewBuilder
    private var suggestions: some View {
        if !personas.suggested.isEmpty {
            Label("Apple Intelligence added, on this device: " + personas.suggested.map(\.label).joined(separator: ", "),
                  systemImage: "sparkles")
                .font(.caption2).foregroundStyle(Palette.blue)
        } else if personas.suggesting {
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Apple Intelligence is thinking of more words…").font(.caption2).foregroundStyle(Palette.muted)
            }
        } else if LocalModel.status.isAvailable {
            Button {
                Task { await personas.suggest() }
            } label: {
                Label("Widen with Apple Intelligence", systemImage: "sparkles").font(.caption)
            }
            .buttonStyle(.borderless)
        }
        if let problem = personas.suggestionProblem {
            Text(problem).font(.caption2).foregroundStyle(Palette.amber)
        }
    }

    private func explanation(_ persona: Persona) -> String {
        let words = personas.terms.map(\.label).prefix(5).joined(separator: ", ")
        let ranked = words.isEmpty ? "Ranked on this device by keywords." : "Ranked on this device by keywords (\(words))."
        return "“\(persona.text)”. What matters to you comes first and is marked “For you”. " + ranked
    }
}

/// Pick a ready-made persona or type your own.
public struct PersonaPicker: View {
    @State private var personas = PersonaStore.shared
    @State private var typed = ""
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("I am from… / I invest in… / I care about…", text: $typed, axis: .vertical)
                        .lineLimit(1...3)
                        .submitLabel(.done)
                        .onSubmit(useTyped)
                    Button("Use these words", action: useTyped)
                        .disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)
                    if !typed.isEmpty {
                        let terms = PersonaRanker.terms(for: typed)
                        Text(terms.isEmpty ? "No words to rank by yet." : "Will look for: " + terms.map(\.label).joined(separator: ", "))
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                } header: {
                    Text("In your own words")
                } footer: {
                    Text("Kept on this device only. Stories and organisations are ranked here by the words you use; Apple Intelligence, where the device has it, writes a briefing for you.")
                }
                Section {
                    ForEach(fromData) { persona in personaRow(persona) }
                } header: {
                    Text("From the Algarve's data")
                } footer: {
                    Text("The organisations the towns' AI maps and stories mention most, and a startup in your town.")
                }
                Section("Or pick one") {
                    ForEach(Persona.presets) { persona in
                        Button {
                            personas.persona = persona
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(persona.label).foregroundStyle(Palette.ink)
                                    Text("“\(persona.text)”").font(.caption).foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                if personas.persona?.text == persona.text { Image(systemName: "checkmark").foregroundStyle(Palette.green) }
                            }
                        }
                    }
                }
                if personas.isOn {
                    Section {
                        Button("Turn persona mode off", role: .destructive) {
                            personas.persona = nil
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Persona")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    /// The most-mentioned organisations, and a startup in the town near the reader (or Faro).
    private var fromData: [Persona] {
        let sites = PlaceDirectory.all.compactMap { LocalStore.shared.site($0.id) }
        let town = NearMeLocator.shared.townID.flatMap(PlaceDirectory.info) ?? PlaceDirectory.info("faro")!
        return Persona.fromData(sites) + [Persona.startup(in: town)]
    }

    private func personaRow(_ persona: Persona) -> some View {
        Button {
            personas.persona = persona
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(persona.label).foregroundStyle(Palette.ink)
                    Text("“\(persona.text)”").font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer()
                if personas.persona?.id == persona.id { Image(systemName: "checkmark").foregroundStyle(Palette.green) }
            }
        }
    }

    private func useTyped() {
        let text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 3 else { return }
        personas.persona = .custom(text)
        dismiss()
    }
}

/// Persona mode on the Algarve home: the stories and organisations across all 17 towns and the region that match,
/// best first, and a briefing from Apple Intelligence when the device has it.
public struct PersonaForYouCard: View {
    let store: LocalStore
    @State private var personas = PersonaStore.shared
    @State private var ask = OnDeviceAsk()
    @State private var status = LocalModel.status

    public init(store: LocalStore = .shared) { self.store = store }

    private var sites: [(info: PlaceInfo, site: PlaceSite)] {
        ([PlaceDirectory.region] + PlaceDirectory.towns).compactMap { info in store.site(info.id).map { (info: info, site: $0) } }
    }

    public var body: some View {
        if let persona = personas.persona {
            let stories = PersonaRanker.stories(in: sites, terms: personas.allTerms, limit: 6, town: persona.townID)
            let entries = PersonaRanker.entries(in: sites, terms: personas.allTerms, limit: 6, town: persona.townID)
            TitledCard("For you", kicker: persona.label) {
                if stories.isEmpty && entries.isEmpty {
                    Text("Nothing in the Algarve's news matches “\(persona.text)” yet. Try other words: a topic, a sector or an organisation's name.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
                if status.isAvailable && !(stories.isEmpty && entries.isEmpty) {
                    Button {
                        ask.run(instructions: LocalPrompts.personaInstructions,
                                prompt: LocalPrompts.persona(persona, stories: stories, entries: entries))
                    } label: {
                        Label(ask.finishedAt == nil ? "Brief me on this device" : "Brief me again", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(ask.running)
                    OnDeviceAnswer(ask: ask)
                } else if !status.isAvailable {
                    LocalModelStatusLine(status: status)
                }
                ForEach(stories) { item in
                    AIStoryRow(story: item.story, town: item.town, match: item.match)
                    Divider()
                }
                if !entries.isEmpty {
                    Text("On the AI map").font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                    ForEach(entries) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                PersonaMatchChip(match: item.match)
                                Kicker(item.town)
                            }
                            AIEntryRow(entry: item.entry)
                        }
                    }
                }
            }
            .onChange(of: persona) { _, _ in ask.cancel() }
            .onAppear { status = LocalModel.status }
        }
    }
}

/// A toolbar button that opens the persona picker; filled when persona mode is on.
public struct PersonaToolbarButton: View {
    @State private var personas = PersonaStore.shared
    @State private var picking = false

    public init() {}

    public var body: some View {
        Button {
            picking = true
        } label: {
            Label("Persona", systemImage: personas.isOn ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle.badge.questionmark")
        }
        .sheet(isPresented: $picking) { PersonaPicker() }
    }
}

// MARK: - Near me

/// The town nearest the reader, and its news first. Asks for location only on a tap, while in use; without it the
/// reader picks a town.
public struct NearMeView: View {
    let store: LocalStore
    @State private var locator = NearMeLocator.shared

    public init(store: LocalStore = .shared) { self.store = store }

    public var body: some View {
        TitledCard("Near me", kicker: kicker) {
            switch locator.state {
            case .asking:
                Text("Asking for your location, only while you use the app…").font(.footnote).foregroundStyle(Palette.muted)
            case .locating:
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Finding the nearest town…").font(.footnote).foregroundStyle(Palette.muted)
                }
            case .denied:
                Text("Location is off for PrompTugal. Pick your town instead, or allow it in Settings.").font(.footnote).foregroundStyle(Palette.amber)
            case .failed(let why):
                Text("Could not find your location: \(why). Pick your town instead.").font(.footnote).foregroundStyle(Palette.amber)
            case .found(let near, _) where !near.isLocal:
                Text("You are \(near.distanceText) from \(near.town.name), the nearest of the 17 places: not in the Algarve right now. Pick a town to see its news first.")
                    .font(.footnote).foregroundStyle(Palette.muted)
            default:
                EmptyView()
            }
            if let id = locator.townID, let info = PlaceDirectory.info(id) {
                townNews(info)
            } else if locator.state == .idle {
                Text("See the news of the town you are in first. Your location stays on this device: the app only works out which of the 17 towns is closest.")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
            HStack {
                Button {
                    locator.locate()
                } label: { Label("Use my location", systemImage: "location") }
                    .buttonStyle(.bordered)
                    .disabled(locator.state == .asking || locator.state == .locating)
                Menu {
                    ForEach(PlaceDirectory.towns.sorted { $0.name < $1.name }) { info in
                        Button(info.name) { locator.pick(info.id) }
                    }
                    if locator.pickedTown != nil {
                        Divider()
                        Button("Forget my town", role: .destructive) { locator.pick(nil) }
                    }
                } label: { Label("Pick a town", systemImage: "list.bullet") }
                    .buttonStyle(.bordered)
            }
            .font(.footnote)
        }
    }

    private var kicker: String {
        if case .found(let near, _) = locator.state, near.isLocal { return "You are \(near.distanceText) from \(near.town.name)" }
        if locator.pickedTown != nil { return "Your town" }
        return "Location, while using the app"
    }

    @ViewBuilder
    private func townNews(_ info: PlaceInfo) -> some View {
        let site = store.site(info.id)
        AITownHeader(info: info, site: site)
        ConditionsLine(placeID: info.id)
        let stories = site?.aiNews.prefix(3) ?? []
        if stories.isEmpty {
            Text("\(info.name)'s agent has no local AI stories yet: still researching.").font(.footnote).foregroundStyle(Palette.muted)
        }
        ForEach(Array(stories)) { story in AIStoryRow(story: story, town: nil, townForAI: info.name) }
    }
}

/// The town page's on-device summary, led by the persona when one is on.
public struct TownSummaryCard: View {
    let site: PlaceSite
    @State private var personas = PersonaStore.shared

    public init(site: PlaceSite) { self.site = site }

    public var body: some View {
        OnDeviceCard(title: "\(site.name) in one paragraph",
                     kicker: personas.persona.map { "Apple Intelligence · for \($0.label)" } ?? "Apple Intelligence",
                     action: "Summarise on this device",
                     instructions: LocalPrompts.townInstructions) {
            LocalPrompts.town(site, persona: personas.persona)
        }
        .id(site.id + (personas.persona?.text ?? ""))
    }
}
