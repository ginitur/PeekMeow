import AppKit
import PeekMeowCore
import SwiftUI

/// Owns the floating edge panel: placement and hover reveal.
@MainActor
final class PanelController {
    private let panel = PeekPanel()
    private var positionManager = PanelPositionManager()
    private let hostView = EdgeHostView()
    private let hover = HoverController()
    private var hostingView: NSHostingView<PeekRootView>?
    private var anchorPlacement: PanelPlacement?
    private var screenChangeObserver: (any NSObjectProtocol)?
    private var shellExpanded = false
    private let reveal = RevealChrome()
    private var motionGeneration = 0
    private var suppressAnimatedCollapse = false
    private let appState: AppState
    private let preferences: PreferencesModel
    private var currentExpansion: ExpansionLayout?
    private var outsideMoveMonitor: Any?
    private var resizeMonitor: Any?
    private var resizeStartMouse: CGPoint?
    private var resizeStartSize: PanelContentSize?
    private var resizeHolding = false
    private var editorScreenRect: CGRect?
    #if DEBUG
    private var lastInteractionLog: InteractionLogKey?
    #endif

    private var previewSize: CGSize {
        let edge = anchorPlacement?.edge ?? .right
        let visible = anchorPlacement.flatMap { screenForAnchor($0)?.visibleFrame.size }
            ?? CGSize(width: 1440, height: 900)
        return preferences.snapshot.windowSize(edgeIsVertical: edge.isVertical, visible: visible)
    }

    init(appState: AppState, preferences: PreferencesModel) {
        self.appState = appState
        self.preferences = preferences
        hostView.wantsLayer = true
        hostView.layer?.backgroundColor = NSColor.clear.cgColor
        hostView.onDragBegan = { [weak self] in
            guard let self else { return }
            self.motionGeneration += 1
            self.shellExpanded = false
            self.reveal.animates = false
            self.reveal.opacity = 1
            self.hover.beginDrag()
            self.syncChrome(animated: false)
        }
        hostView.onDrag = { [weak self] point in
            self?.handleDrag(at: point)
        }
        hostView.onDragEnded = { [weak self] point in
            self?.handleDragEnded(at: point)
        }
        hostView.onClick = { [weak self] in
            self?.hover.click()
        }
        hostView.onPointerEntered = { [weak self] in
            self?.hover.pointerEntered()
        }
        hostView.onPointerExited = { [weak self] in
            self?.hover.pointerExited()
        }
        hostView.onPointerMoved = { [weak self] _ in
            self?.evaluatePointer()
        }
        hover.regionContainsPointer = { [weak self] in
            self?.pointerIsInsideHoverRegion() ?? false
        }
        hover.onOutput = { [weak self] output in
            self?.handleHoverOutput(output)
        }
        panel.contentView = hostView
        panel.allowsKey = false
        hover.setDelays(
            open: preferences.snapshot.hoverOpenDelay,
            close: preferences.snapshot.hoverCloseDelay
        )
        positionManager.stackLength = preferences.snapshot.edgeTabLength
        observeScreenChanges()
    }

    func showRestoredOrDefault() {
        applyPreferences()
        guard let screen = ScreenManager.mainSnapshot() else {
            return
        }
        let stored = PlacementStore.placement(for: screen.identifier)
            ?? DisplayPlacement(
                displayIdentifier: screen.identifier,
                edge: AppSettings.default.selectedEdge,
                offset: AppSettings.default.edgeOffset
            )
        setAnchor(restoredPlacement(stored, on: screen), persist: false)
        panel.orderFrontRegardless()
    }

    func hide() {
        endPanelResize()
        stopOutsideMonitor()
        panel.orderOut(nil)
    }

    func resetPosition() {
        guard let screen = ScreenManager.mainSnapshot() else {
            return
        }
        suppressAnimatedCollapse = true
        hover.forceCollapse()
        suppressAnimatedCollapse = false
        let stored = DisplayPlacement(
            displayIdentifier: screen.identifier,
            edge: .right,
            offset: AppSettings.default.edgeOffset
        )
        PlacementStore.upsert(stored)
        setAnchor(restoredPlacement(stored, on: screen), persist: false)
        panel.orderFrontRegardless()
    }

    func refreshChrome() {
        syncChrome(animated: false)
    }

    func applyPreferences() {
        let prefs = preferences.snapshot
        hover.setDelays(open: prefs.hoverOpenDelay, close: prefs.hoverCloseDelay)
        positionManager.stackLength = prefs.edgeTabLength
        let appearance = preferences.windowAppearance
        NSApp.appearance = appearance
        panel.appearance = appearance
        if let anchor = anchorPlacement, let screen = screenForAnchor(anchor) {
            anchorPlacement = restoredPlacement(anchor.stored, on: screen)
        }
        guard anchorPlacement != nil else { return }
        syncChrome(animated: false)
    }

    func reposition() {
        let screens = ScreenManager.allSnapshots()
        guard let main = ScreenManager.mainSnapshot() ?? screens.first else {
            hide()
            return
        }
        let saved = anchorPlacement?.stored
            ?? PlacementStore.placement(for: main.identifier)
            ?? DisplayPlacement(
                displayIdentifier: main.identifier,
                edge: .right,
                offset: AppSettings.default.edgeOffset
            )
        let resolved = ScreenMigration.resolve(
            saved: saved,
            screens: screens,
            mainScreenID: main.identifier
        )
        guard let screen = resolved.screen else {
            hide()
            return
        }
        setAnchor(restoredPlacement(resolved.placement, on: screen), persist: true)
    }

    private func handleDrag(at point: CGPoint) {
        guard let screen = screen(for: point) else { return }
        let grab = anchorPlacement?.frame.size
            ?? EdgeGeometry.collapsedWindowSize(edge: .right, stackLength: positionManager.stackLength)
        let placement = EdgeGeometry.draggingPlacement(
            pointer: point,
            screen: screen,
            stackLength: positionManager.stackLength,
            grabSize: grab,
            screens: ScreenManager.allSnapshots()
        )
        setAnchor(placement, persist: false, animated: false)
    }

    private func handleDragEnded(at point: CGPoint) {
        guard let screen = screen(for: point) else {
            hover.endDrag()
            return
        }
        let placement = EdgeGeometry.committedPlacement(
            pointer: point,
            screen: screen,
            stackLength: positionManager.stackLength,
            screens: ScreenManager.allSnapshots()
        )
        setAnchor(placement, persist: true, animated: false)
        hover.endDrag()
    }

    private func handleHoverOutput(_ output: HoverOutput) {
        switch output {
        case .expand:
            startOutsideMonitor()
            expandChrome()
        case .beginEditing:
            startOutsideMonitor()
            if !shellExpanded {
                expandChrome()
            }
            enterKeyMode()
        case .endEditing:
            exitKeyMode()
        case .collapse:
            stopOutsideMonitor()
            editorScreenRect = nil
            if hover.isDragging || suppressAnimatedCollapse {
                motionGeneration += 1
                shellExpanded = false
                reveal.animates = false
                reveal.opacity = 1
                syncChrome(animated: false)
            } else {
                collapseChrome()
            }
        case .scheduleOpen, .scheduleClose, .cancelTimers:
            refreshPresentedContent()
        case .none:
            break
        }
        if hover.engine.isPinned || hover.engine.phase == .collapsed {
            stopOutsideMonitor()
        }
        publishInteractionLog(at: NSEvent.mouseLocation)
    }

    private func expandChrome() {
        motionGeneration += 1
        let generation = motionGeneration
        shellExpanded = true
        reveal.reduceMotion = preferences.reducesMotion
        reveal.collapsing = false
        if preferences.reducesMotion || hover.isDragging {
            reveal.animates = false
            reveal.opacity = 1
            syncChrome(animated: false)
            return
        }
        reveal.animates = true
        reveal.opacity = 0
        let duration = preferences.movementDuration(LayoutMetrics.expandDuration)
        syncChrome(animated: true, expanding: true, duration: duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + LayoutMetrics.contentFadeDelay) { [weak self] in
            guard let self, self.motionGeneration == generation else { return }
            self.reveal.opacity = 1
        }
    }

    private func collapseChrome() {
        motionGeneration += 1
        let generation = motionGeneration
        reveal.reduceMotion = preferences.reducesMotion
        if preferences.reducesMotion || hover.isDragging {
            reveal.animates = false
            reveal.opacity = 1
            shellExpanded = false
            syncChrome(animated: false)
            return
        }
        reveal.animates = true
        reveal.collapsing = true
        reveal.opacity = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + LayoutMetrics.contentFadeOutDuration) { [weak self] in
            guard let self, self.motionGeneration == generation else { return }
            self.shellExpanded = false
            let duration = self.preferences.movementDuration(LayoutMetrics.collapseDuration)
            self.syncChrome(
                animated: true,
                expanding: false,
                duration: duration
            )
        }
    }

    private func setAnchor(
        _ placement: PanelPlacement,
        persist: Bool,
        animated: Bool = false
    ) {
        anchorPlacement = placement
        if persist {
            PlacementStore.upsert(placement.stored)
        }
        syncChrome(animated: animated)
    }

    private func syncChrome(
        animated: Bool,
        expanding: Bool = true,
        duration: TimeInterval = LayoutMetrics.expandDuration
    ) {
        guard let anchor = anchorPlacement else { return }
        let framePlacement = displayedPlacement(anchor: anchor, expanded: shellExpanded)
        panel.alphaValue = shellExpanded ? preferences.snapshot.panelOpacity : 1
        panel.hasShadow = shellExpanded
        positionManager.apply(
            framePlacement,
            to: panel,
            animated: animated,
            expanding: expanding,
            duration: duration
        )
        if animated {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.finishFrameAnimation()
            }
        } else {
            finishFrameAnimation()
        }
        refreshPresentedContent()
        if DebugFlags.showAnchorGeometry, let expansion = currentExpansion {
            print(
                "[Anchor] offset=\(anchor.offset) point=\(expansion.anchorPoint) panel=\(expansion.panelFrame) handle=\(expansion.handleAttachmentPoint) clamped=\(expansion.wasClamped)"
            )
        }
        if hover.engine.phase != .editing {
            panel.allowsKey = false
        }
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private var presentedPhase: PeekMeowCore.HoverPhase {
        if hover.engine.phase == .editing { return .editing }
        if hover.engine.phase == .pinned { return shellExpanded ? .pinned : .collapsed }
        return shellExpanded ? .expanded : .collapsed
    }

    private func refreshPresentedContent() {
        guard let anchor = anchorPlacement else { return }
        installContent(
            edge: anchor.edge,
            phase: presentedPhase
        )
        hostView.dragHandleRect = dragHandleRect(
            in: hostView.bounds,
            edge: anchor.edge,
            expanded: shellExpanded
        )
    }

    private func finishFrameAnimation() {
        hostView.dragHandleRect = dragHandleRect(
            in: hostView.bounds,
            edge: anchorPlacement?.edge ?? .right,
            expanded: shellExpanded
        )
        hostView.installTrackingArea()
        evaluatePointer()
    }

    private func displayedPlacement(anchor: PanelPlacement, expanded: Bool) -> PanelPlacement {
        guard expanded, let screen = screenForAnchor(anchor) else {
            return anchor
        }
        let layout = ExpansionGeometry.layout(
            anchor: EdgeAnchor.from(anchor.stored),
            screen: screen,
            panelSize: previewSize,
            stackLength: positionManager.stackLength,
            inset: ScreenAdjacency.clearance(
                edge: anchor.edge,
                screen: screen,
                screens: ScreenManager.allSnapshots()
            )
        )
        currentExpansion = layout
        var expanded = anchor
        expanded.frame = layout.panelFrame
        return expanded
    }

    private func installContent(
        edge: ScreenEdge,
        phase: PeekMeowCore.HoverPhase
    ) {
        let emphasized = hover.engine.phase == .hovering
        let root = PeekRootView(
            edge: edge,
            phase: phase,
            appearance: preferences.snapshot,
            backgroundImage: shellExpanded ? preferences.currentBackgroundImage() : nil,
            accent: .accent,
            tabColor: preferences.resolvedEdgeTabColor(),
            tabThickness: preferences.snapshot.edgeTabThickness,
            tabOpacity: AppearancePreferences.displayedEdgeTabOpacity(
                base: preferences.snapshot.edgeTabOpacity,
                emphasized: emphasized
            ),
            showHitRegions: DebugFlags.showHitRegions,
            showInteractionRegions: DebugFlags.showInteractionRegions,
            reveal: reveal,
            appState: appState,
            onBeginEdit: { [weak self] in self?.hover.enterEditing() },
            onEndEdit: { [weak self] in self?.hover.exitEditing() },
            onInteractionBegan: { [weak self] in self?.beginTemporaryInteraction() },
            onInteractionEnded: { [weak self] in self?.endTemporaryInteraction() },
            onEditorFrameChange: { [weak self] rect in
                self?.editorScreenRect = rect
                self?.publishInteractionLog(at: NSEvent.mouseLocation)
            },
            onResizeBegan: { [weak self] in self?.beginPanelResize() },
            onResizeChanged: { [weak self] in self?.updatePanelResize() },
            onResizeEnded: { [weak self] in self?.endPanelResize() },
            handleOffsetInsidePanel: currentExpansion?.handleOffsetInsidePanel ?? 0,
            stackLength: positionManager.stackLength
        )
        if let hostingView {
            hostingView.rootView = root
            hostingView.frame = hostView.bounds
            return
        }
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []
        hosting.clipsToBounds = false
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height] as NSView.AutoresizingMask
        hosting.frame = hostView.bounds
        hostView.addSubview(hosting, positioned: .below, relativeTo: nil)
        hostView.clipsToBounds = false
        hostingView = hosting
    }

    private func beginPanelResize() {
        guard shellExpanded, !resizeHolding else { return }
        resizeHolding = true
        resizeStartMouse = NSEvent.mouseLocation
        resizeStartSize = displayedContentSize()
        hover.beginInteraction()
        resizeMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleResizeEvent(event)
            }
            return event
        }
    }

    private func handleResizeEvent(_ event: NSEvent) {
        if event.type == .leftMouseUp {
            endPanelResize()
            return
        }
        updatePanelResize()
    }

    private func updatePanelResize() {
        guard resizeHolding,
              let origin = resizeStartMouse,
              let start = resizeStartSize,
              let edge = anchorPlacement?.edge
        else { return }
        let mouse = NSEvent.mouseLocation
        let translation = CGSize(width: mouse.x - origin.x, height: origin.y - mouse.y)
        let visible = anchorPlacement.flatMap { screenForAnchor($0)?.visibleFrame.size }
            ?? CGSize(width: 1440, height: 900)
        let next = PanelResizeGeometry.resizedContent(
            start: start,
            translation: translation,
            edge: edge,
            visible: visible
        )
        preferences.applyLivePanelSize(width: next.width, height: next.height)
    }

    private func endPanelResize() {
        guard resizeHolding else { return }
        resizeHolding = false
        if let resizeMonitor {
            NSEvent.removeMonitor(resizeMonitor)
        }
        resizeMonitor = nil
        resizeStartMouse = nil
        resizeStartSize = nil
        preferences.commitPanelSize()
        hover.endInteraction()
    }

    private func displayedContentSize() -> PanelContentSize {
        let edge = anchorPlacement?.edge ?? .right
        let visible = anchorPlacement.flatMap { screenForAnchor($0)?.visibleFrame.size }
            ?? CGSize(width: 1440, height: 900)
        return preferences.snapshot.displayContentSize(visible: visible, edgeIsVertical: edge.isVertical)
    }

    private func dragHandleRect(in bounds: CGRect, edge: ScreenEdge, expanded: Bool) -> CGRect? {
        guard expanded else { return nil }
        return DragHandleGeometry.rect(in: bounds, edge: edge)
    }

    private func pointerHits(at point: CGPoint) -> HoverPointerHits {
        let edge = anchorPlacement?.frame ?? .null
        let panelFrame: CGRect? = shellExpanded ? panel.frame : nil
        let visibleEdge = shellExpanded ? edge : panel.frame
        return HoverRegion.hits(point, edge: visibleEdge, panel: panelFrame)
    }

    private func pointerIsInsideHoverRegion() -> Bool {
        pointerHits(at: NSEvent.mouseLocation).inside
    }

    private func evaluatePointer() {
        guard !hover.isDragging else { return }
        let point = NSEvent.mouseLocation
        let hits = pointerHits(at: point)
        if hits.inside {
            if !hover.engine.pointerInside || hover.isExitGracePending {
                hover.pointerEntered()
            }
        } else if hover.engine.pointerInside, !hover.isExitGracePending {
            hover.pointerExited()
        }
        publishInteractionLog(at: point, hits: hits)
    }

    private func beginTemporaryInteraction() {
        hover.beginInteraction()
        enterKeyMode()
    }

    private func endTemporaryInteraction() {
        hover.endInteraction()
        if !appState.isEditing, hover.engine.phase != .editing {
            exitKeyMode()
        }
        evaluatePointer()
    }

    private func startOutsideMonitor() {
        guard outsideMoveMonitor == nil else { return }
        outsideMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.evaluatePointer()
                }
            }
        }
    }

    private func stopOutsideMonitor() {
        if let outsideMoveMonitor {
            NSEvent.removeMonitor(outsideMoveMonitor)
            self.outsideMoveMonitor = nil
        }
    }

    private func screenForAnchor(_ placement: PanelPlacement) -> ScreenGeometry? {
        let screens = ScreenManager.allSnapshots()
        return screens.first(where: { $0.identifier == placement.displayIdentifier })
            ?? ScreenManager.mainSnapshot()
    }

    private func restoredPlacement(_ stored: DisplayPlacement, on screen: ScreenGeometry) -> PanelPlacement {
        EdgeGeometry.placement(
            from: stored,
            screen: screen,
            stackLength: positionManager.stackLength,
            screens: ScreenManager.allSnapshots()
        )
    }

    private func screen(for point: CGPoint) -> ScreenGeometry? {
        ScreenMigration.screenContaining(
            point: point,
            screens: ScreenManager.allSnapshots(),
            preferring: anchorPlacement?.displayIdentifier
        ) ?? ScreenManager.mainSnapshot()
    }

    private func enterKeyMode() {
        panel.allowsKey = true
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        publishInteractionLog(at: NSEvent.mouseLocation)
    }

    private func exitKeyMode() {
        panel.allowsKey = false
        if panel.firstResponder is NSTextView || panel.firstResponder is NSTextField {
            panel.makeFirstResponder(nil)
        }
        if panel.isKeyWindow {
            panel.resignKey()
        }
        panel.invalidateCursorRects(for: hostView)
        if let hostingView {
            panel.invalidateCursorRects(for: hostingView)
        }
        panel.orderFrontRegardless()
        publishInteractionLog(at: NSEvent.mouseLocation)
    }

    private func publishInteractionLog(at point: CGPoint, hits: HoverPointerHits? = nil) {
        #if DEBUG
        let resolved = hits ?? pointerHits(at: point)
        let insideEditor = editorScreenRect?.contains(point) ?? false
        let key = InteractionLogKey(
            hoverState: hover.engine.phase,
            editingItemID: appState.editingItemID,
            isComposing: appState.isComposing,
            isKeyWindow: panel.isKeyWindow,
            allowsKey: panel.allowsKey,
            isPinned: hover.engine.isPinned,
            interactionHoldCount: hover.engine.interactionHoldCount,
            mouseInsideEdge: resolved.insideEdge,
            mouseInsidePanel: resolved.insidePanel,
            insideEditor: insideEditor
        )
        guard key != lastInteractionLog else { return }
        lastInteractionLog = key
        let editing = appState.editingItemID?.uuidString ?? "nil"
        print(
            "[Hover] mouse=(\(point.x),\(point.y)) insideEdge=\(resolved.insideEdge) insidePanel=\(resolved.insidePanel) insideEditor=\(insideEditor) state=\(hover.engine.phase.rawValue)"
        )
        print(
            "[Interaction] hoverState=\(hover.engine.phase.rawValue) editingItemID=\(editing) isKeyWindow=\(panel.isKeyWindow) allowsKey=\(panel.allowsKey) isPinned=\(hover.engine.isPinned) interactionHoldCount=\(hover.engine.interactionHoldCount) mouseInsideEdge=\(resolved.insideEdge) mouseInsidePanel=\(resolved.insidePanel)"
        )
        #endif
    }

    private func observeScreenChanges() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reposition()
            }
        }
    }
}
