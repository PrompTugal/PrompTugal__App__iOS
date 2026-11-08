import PTCore
import PTWeb
import SwiftUI

/// The newsroom's graph, drawn natively: 1,688 nodes and 2,863 edges in one Canvas,
/// using the layout the website's build computed. Pinch to zoom, drag to pan, tap a
/// node to see its neighbours as sentences, find the path between two nodes.
public struct GraphExplorerView: View {
    @Environment(NewsFeeds.self) private var data
    @Environment(\.horizontalSizeClass) private var width
    @State private var index: GraphIndex?
    @State private var indexing = false
    @State private var selected: Int?
    @State private var pathStart: Int?
    @State private var path: [Int] = []
    @State private var hiddenWorlds: Set<String> = []
    @State private var query = ""
    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero
    @State private var showsDetail = false
    /// The explorer's real width (iPad Split View can make it narrow): the detail opens beside
    /// the graph only when there is room, otherwise as a sheet.
    @State private var explorerWidth: CGFloat = 0
    /// On iPhone the legend starts folded, so the graph gets the whole screen.
    @State private var legendOpen: Bool?

    private var feed: RemoteFeed<GraphExplorer> { data.graph }

    public init() {}

    public var body: some View {
        Group {
            if let index {
                explorer(index)
            } else {
                Page {
                    ScreenHeader(kicker: String(localized: "News", bundle: .module), title: String(localized: "The graph", bundle: .module),
                                 summary: String(localized: "Every company, event, person, place and source the newsroom knows, and how they connect.", bundle: .module))
                    if indexing {
                        ProgressView(String(localized: "Laying out \(feed.value?.nodes.count ?? 0) nodes…", bundle: .module)).frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        StateView(phase: feed.phase, hasData: false, title: String(localized: "graph", bundle: .module)) { Task { await feed.load(force: true) } }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Graph", bundle: .module))
        .searchable(text: $query, prompt: String(localized: "Find a node", bundle: .module))
        .searchSuggestions { suggestions }
        .task {
            await feed.load()
            await buildIndex()
        }
        .onChange(of: feed.updated) { _, _ in Task { await buildIndex() } }
        .webTwin(webURL, title: String(localized: "Graph explorer", bundle: .module))
    }

    private var webURL: URL {
        var components = URLComponents(url: FeedClient.site.appendingPathComponent("graph/"), resolvingAgainstBaseURL: false)!
        if let selected, let index, index.contains(selected) {
            let id = index.graph.nodes[selected].id
            components.queryItems = [URLQueryItem(name: "focus", value: id)]
        }
        return components.url ?? FeedClient.site
    }

    private func buildIndex() async {
        guard let graph = feed.value, !indexing else { return }
        if let index, index.graph.nodes.count == graph.nodes.count, index.graph.version == graph.version { return }
        indexing = true
        let built = await Task.detached(priority: .userInitiated) { GraphIndex(graph) }.value
        // A new graph has new node numbers: anything pointing into the old one must go.
        selected = nil
        path = []
        pathStart = nil
        showsDetail = false
        index = built
        indexing = false
    }

    // MARK: Explorer layout

    @ViewBuilder private func explorer(_ index: GraphIndex) -> some View {
        let safeSelected = index.contains(selected) ? selected : nil
        let safePath = path.allSatisfy { index.contains($0) } ? path : []
        let canvas = GraphCanvas(index: index, selected: safeSelected, path: safePath, hiddenWorlds: hiddenWorlds,
                                 zoom: zoom * pinch, pan: CGSize(width: pan.width + drag.width, height: pan.height + drag.height),
                                 select: select)
            .gesture(MagnifyGesture().updating($pinch) { value, state, _ in state = value.magnification }
                .onEnded { value in zoom = min(max(zoom * value.magnification, 0.5), 40) })
            .simultaneousGesture(DragGesture(minimumDistance: 4).updating($drag) { value, state, _ in state = value.translation }
                .onEnded { value in pan.width += value.translation.width; pan.height += value.translation.height })
            .onGeometryChange(for: CGSize.self) { $0.size } action: { lastCanvasSize = $0 }
            .overlay(alignment: .topLeading) { legend(index) }
            .overlay(alignment: .bottomTrailing) { zoomControls }

        Group {
        if width == .regular, GraphLayout.sidePanel(width: explorerWidth) {
            HStack(spacing: 0) {
                canvas
                if safeSelected != nil {
                    Divider()
                    detail(index).frame(width: GraphLayout.panelWidth(width: explorerWidth))
                }
            }
        } else {
            canvas.sheet(isPresented: $showsDetail) {
                NavigationStack { detail(index) }.presentationDetents([.medium, .large])
            }
        }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { explorerWidth = $0 }
    }

    private func select(_ node: Int?) {
        if let node, let start = pathStart, start != node, let index {
            path = index.path(from: start, to: node) ?? []
            pathStart = nil
        }
        selected = node
        showsDetail = node != nil
    }

    private func legend(_ index: GraphIndex) -> some View {
        let open = legendOpen ?? (width != .compact)
        return VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.snappy) { legendOpen = !open }
            } label: {
                Label(open ? String(localized: "Worlds", bundle: .module) : String(localized: "\(index.graph.nodes.count.formatted()) nodes", bundle: .module),
                      systemImage: open ? "chevron.up" : "line.3.horizontal.decrease.circle")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            if open {
            ForEach(index.graph.worlds ?? []) { world in
                Button {
                    if hiddenWorlds.contains(world.id) { hiddenWorlds.remove(world.id) } else { hiddenWorlds.insert(world.id) }
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(GraphColors.world(world.id)).frame(width: 9, height: 9)
                            .opacity(hiddenWorlds.contains(world.id) ? 0.25 : 1)
                        Text(world.label ?? world.id).font(.caption)
                            .foregroundStyle(hiddenWorlds.contains(world.id) ? Palette.muted : Palette.ink)
                            .strikethrough(hiddenWorlds.contains(world.id))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(world.label ?? world.id), \(hiddenWorlds.contains(world.id) ? String(localized: "hidden", bundle: .module) : String(localized: "shown", bundle: .module))")
            }
            Text(String(localized: "\(index.graph.nodes.count.formatted()) nodes · \(index.edges.count.formatted()) edges", bundle: .module))
                .font(.caption2).foregroundStyle(Palette.muted)
            if pathStart != nil {
                Label(String(localized: "Tap a second node for the path", bundle: .module), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.caption).foregroundStyle(Palette.green)
            }
            }
        }
        .padding(Space.s)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(Space.m)
    }

    private var zoomControls: some View {
        HStack(spacing: 0) {
            Button { zoom = max(zoom / 1.5, 0.5) } label: { Image(systemName: "minus").frame(width: 40, height: 40) }
                .accessibilityLabel(String(localized: "Zoom out", bundle: .module))
            Button { zoom = 1; pan = .zero } label: { Image(systemName: "arrow.up.left.and.down.right.magnifyingglass").frame(width: 40, height: 40) }
                .accessibilityLabel(String(localized: "Fit the whole graph", bundle: .module))
            Button { zoom = min(zoom * 1.5, 40) } label: { Image(systemName: "plus").frame(width: 40, height: 40) }
                .accessibilityLabel(String(localized: "Zoom in", bundle: .module))
        }
        .background(.regularMaterial, in: Capsule())
        .padding(Space.m)
    }

    // MARK: Search

    @ViewBuilder private var suggestions: some View {
        if let index, query.count >= 2 {
            let matches = index.graph.nodes.indices
                .filter { index.graph.nodes[$0].title.localizedStandardContains(query) }
                .sorted { (index.graph.nodes[$0].pr ?? 0) > (index.graph.nodes[$1].pr ?? 0) }
                .prefix(12)
            ForEach(Array(matches), id: \.self) { node in
                Button {
                    focus(on: node, in: index)
                    query = ""
                } label: {
                    Label(index.graph.nodes[node].title, systemImage: symbol(index.graph.nodes[node].type))
                }
            }
        }
    }

    private func focus(on node: Int, in index: GraphIndex) {
        select(node)
        zoom = 6
        let point = index.position(node)
        // Pan so the node sits in the middle: the canvas maps bounds.mid to the centre at zoom 1.
        let base = GraphCanvas.baseScale(index.bounds, in: lastCanvasSize)
        pan = CGSize(width: -(point.x - index.bounds.midX) * base * zoom, height: -(point.y - index.bounds.midY) * base * zoom)
    }

    @State private var lastCanvasSize = CGSize(width: 800, height: 800)

    // MARK: Detail

    private func detail(_ index: GraphIndex) -> some View {
        Group {
            if let selected, index.contains(selected) {
                let node = index.graph.nodes[selected]
                List {
                    Section {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Kicker(node.type, color: GraphColors.world(index.world(of: node)))
                            Text(node.title).font(Typo.title)
                            HStack(spacing: Space.m) {
                                Text(String(localized: "\(node.deg ?? 0) links", bundle: .module))
                                Text(String(localized: "PageRank \((node.pr ?? 0).formatted(.number.precision(.fractionLength(2))))", bundle: .module))
                                Text(String(localized: "Betweenness \((node.bc ?? 0).formatted(.number.precision(.fractionLength(0))))", bundle: .module))
                            }
                            .font(Typo.dataSmall).foregroundStyle(Palette.muted)
                        }
                        if let url = node.url {
                            NavigationLink { WebPage(url: url, title: node.title) } label: {
                                Label(String(localized: "Open its page", bundle: .module), systemImage: "doc.richtext")
                            }
                        }
                        Button {
                            pathStart = selected
                            path = []
                        } label: {
                            Label(String(localized: "Find a path from here", bundle: .module), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        }
                        Button { focus(on: selected, in: index) } label: { Label(String(localized: "Zoom to it", bundle: .module), systemImage: "scope") }
                    }
                    if path.count > 1, path.allSatisfy({ index.contains($0) }) {
                        Section(String(localized: "Path, \(path.count - 1) steps", bundle: .module)) {
                            ForEach(Array(zip(path, path.dropFirst())), id: \.0) { from, to in
                                if let edge = index.neighbours[from].map({ index.edges[$0] })
                                    .first(where: { ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from) }) {
                                    Text(index.sentence(edge)).font(.footnote)
                                }
                            }
                            Button(String(localized: "Clear path", bundle: .module)) { path = [] }
                        }
                    }
                    Section(String(localized: "Connections (\(index.neighbours[selected].count))", bundle: .module)) {
                        ForEach(index.neighbours[selected].prefix(80), id: \.self) { edgeIndex in
                            let edge = index.edges[edgeIndex]
                            let other = edge.from == selected ? edge.to : edge.from
                            Button { select(other) } label: {
                                Text(index.sentence(edge)).font(.footnote).foregroundStyle(Palette.ink)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Close", bundle: .module)) { self.selected = nil; showsDetail = false }
                    }
                }
            }
        }
    }

    private func symbol(_ type: String) -> String {
        switch type {
        case "company": "building.2"
        case "person": "person"
        case "event": "calendar"
        case "place": "mappin"
        case "organisation": "building.columns"
        case "topic": "tag"
        case "story", "article": "newspaper"
        case "fact", "evidence", "source": "checkmark.seal"
        default: "circle"
        }
    }
}

/// The drawing itself: one stroked path for all edges, then nodes sized by PageRank, then labels.
struct GraphCanvas: View {
    let index: GraphIndex
    let selected: Int?
    let path: [Int]
    let hiddenWorlds: Set<String>
    let zoom: CGFloat
    let pan: CGSize
    let select: (Int?) -> Void

    static func baseScale(_ bounds: CGRect, in size: CGSize) -> CGFloat {
        min(size.width / bounds.width, size.height / bounds.height) * 0.92
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let scale = Self.baseScale(index.bounds, in: size) * zoom
            let mid = CGPoint(x: index.bounds.midX, y: index.bounds.midY)
            let transform = { (point: CGPoint) -> CGPoint in
                CGPoint(x: (point.x - mid.x) * scale + size.width / 2 + pan.width,
                        y: (point.y - mid.y) * scale + size.height / 2 + pan.height)
            }
            let visible = index.graph.nodes.map { !hiddenWorlds.contains(index.world(of: $0)) }
            let neighbourSet: Set<Int> = selected.map { node in
                Set(index.neighbours[node].map { let edge = index.edges[$0]; return edge.from == node ? edge.to : edge.from })
            } ?? []
            let pathSet = Set(path)

            Canvas { context, _ in
                // Edges.
                var lines = Path()
                for edge in index.edges where visible[edge.from] && visible[edge.to] {
                    lines.move(to: transform(index.position(edge.from)))
                    lines.addLine(to: transform(index.position(edge.to)))
                }
                context.stroke(lines, with: .color(Palette.muted.opacity(selected == nil ? 0.22 : 0.1)), lineWidth: 0.5)

                if let selected {
                    var focus = Path()
                    for edgeIndex in index.neighbours[selected] {
                        let edge = index.edges[edgeIndex]
                        focus.move(to: transform(index.position(edge.from)))
                        focus.addLine(to: transform(index.position(edge.to)))
                    }
                    context.stroke(focus, with: .color(Palette.red.opacity(0.8)), lineWidth: 1.2)
                }
                if path.count > 1 {
                    var route = Path()
                    route.move(to: transform(index.position(path[0])))
                    for node in path.dropFirst() { route.addLine(to: transform(index.position(node))) }
                    context.stroke(route, with: .color(Palette.green), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }

                // Nodes.
                for (i, node) in index.graph.nodes.enumerated() where visible[i] {
                    let point = transform(index.position(i))
                    guard point.x > -20, point.y > -20, point.x < size.width + 20, point.y < size.height + 20 else { continue }
                    let rank = (node.pr ?? 0) / max(index.maxRank, 0.0001)
                    let radius = (1.6 + 7 * sqrt(rank)) * min(max(sqrt(zoom), 1), 2.5)
                    let dimmed = selected != nil && i != selected && !neighbourSet.contains(i) && !pathSet.contains(i)
                    let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(GraphColors.world(index.world(of: node)).opacity(dimmed ? 0.25 : 0.9)))
                    if i == selected || pathSet.contains(i) {
                        context.stroke(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)), with: .color(Palette.ink), lineWidth: 1.5)
                    }
                }

                // Labels: the most central nodes, the selection and its neighbours, and more as you zoom in.
                let labelBudget = zoom < 1.5 ? 8 : (zoom < 4 ? 30 : (zoom < 8 ? 80 : 160))
                var labelled = 0
                let ranked = index.graph.nodes.indices.sorted { (index.graph.nodes[$0].pr ?? 0) > (index.graph.nodes[$1].pr ?? 0) }
                let priority = (selected.map { [$0] } ?? []) + path + neighbourSet.sorted()
                for i in priority + ranked where visible[i] {
                    let point = transform(index.position(i))
                    guard point.x > 0, point.y > 0, point.x < size.width, point.y < size.height else { continue }
                    let important = i == selected || pathSet.contains(i) || neighbourSet.contains(i)
                    if !important && labelled >= labelBudget { continue }
                    labelled += 1
                    let text = Text(index.graph.nodes[i].title)
                        .font(important ? .caption.weight(.semibold) : .caption2)
                        .foregroundStyle(Palette.ink)
                    context.draw(text, at: CGPoint(x: point.x + 6, y: point.y), anchor: .leading)
                    if labelled > labelBudget + 60 { break }
                }
            }
            .background(Palette.paper)
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { tap in
                var best: (Int, CGFloat)?
                for i in index.graph.nodes.indices where visible[i] {
                    let point = transform(index.position(i))
                    let distance = hypot(point.x - tap.location.x, point.y - tap.location.y)
                    if distance < 22, distance < (best?.1 ?? .infinity) { best = (i, distance) }
                }
                select(best?.0)
            })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Graph of \(index.graph.nodes.count) nodes. Use search to find a node.", bundle: .module))
        }
    }
}

/// Where the node detail goes, from the width the explorer really has.
enum GraphLayout {
    /// Beside the graph from 700 pt; below that a sheet, so the graph keeps a usable width.
    static func sidePanel(width: CGFloat) -> Bool { width >= 700 }

    /// The panel: up to 340 pt, never more than 38 % of the width.
    static func panelWidth(width: CGFloat) -> CGFloat { min(340, max(260, width * 0.38)) }
}

#Preview("Graph · iPhone") {
    NavigationStack { GraphExplorerView() }.environment(NewsFeeds()).phonePreview()
}

#Preview("Graph · iPad") {
    NavigationStack { GraphExplorerView() }.environment(NewsFeeds()).padPreview()
}
