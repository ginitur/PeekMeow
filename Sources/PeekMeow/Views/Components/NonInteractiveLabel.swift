import AppKit
import SwiftUI

/// Static label. Not selectable, not editable, and it does not install an I-beam cursor rect.
struct NonInteractiveLabel: NSViewRepresentable {
    var text: String
    var font: NSFont
    var color: NSColor = .labelColor
    var strikethrough: Bool = false
    var alignment: NSTextAlignment = .left
    /// When set, this label is the click target and does not forward hits.
    var onClick: (() -> Void)?

    func makeNSView(context: Context) -> LabelField {
        let field = LabelField(frame: .zero)
        let cell = CenteredLabelCell(textCell: text)
        cell.font = font
        cell.lineBreakMode = .byTruncatingTail
        cell.usesSingleLineMode = true
        cell.isEditable = false
        cell.isSelectable = false
        field.cell = cell
        field.stringValue = text
        field.maximumNumberOfLines = 1
        field.lineBreakMode = .byTruncatingTail
        field.drawsBackground = false
        field.isBezeled = false
        field.isBordered = false
        field.isEditable = false
        field.isSelectable = false
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setContentHuggingPriority(.defaultLow, for: .vertical)
        return field
    }

    func updateNSView(_ field: LabelField, context: Context) {
        field.onClick = onClick
        field.font = font
        field.alignment = alignment
        field.textColor = color
        if strikethrough {
            field.attributedStringValue = NSAttributedString(
                string: text,
                attributes: [
                    .font: font,
                    .foregroundColor: color,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                ]
            )
        } else {
            field.attributedStringValue = NSAttributedString(
                string: text,
                attributes: [
                    .font: font,
                    .foregroundColor: color,
                ]
            )
        }
        field.isEditable = false
        field.isSelectable = false
        field.invalidateIntrinsicContentSize()
    }
}

/// Label field that never becomes first responder and never claims the I-beam.
final class LabelField: NSTextField {
    var onClick: (() -> Void)?

    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        // Leave the arrow cursor alone. Selectable text fields are what paint the I-beam.
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard onClick != nil else { return nil }
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {}

    override func rightMouseDown(with event: NSEvent) {
        superview?.rightMouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        guard bounds.contains(local) else { return }
        onClick?()
    }
}

/// Keeps a one-line title centered when the row is taller than the glyphs.
final class CenteredLabelCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var titleRect = super.drawingRect(forBounds: rect)
        let textHeight = (font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)).boundingRectForFont.height
        guard titleRect.height > textHeight else { return titleRect }
        titleRect.origin.y += (titleRect.height - textHeight) / 2
        titleRect.size.height = textHeight
        return titleRect
    }
}

/// Reports the receiver's screen frame. Used so hover logs can tell editor hits from panel hits.
struct ScreenFrameReader: NSViewRepresentable {
    var onChange: (CGRect) -> Void

    func makeNSView(context: Context) -> ScreenFrameReaderView {
        let view = ScreenFrameReaderView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: ScreenFrameReaderView, context: Context) {
        view.onChange = onChange
        view.reportIfNeeded()
    }
}

final class ScreenFrameReaderView: NSView {
    var onChange: ((CGRect) -> Void)?
    private var last: CGRect = .null

    override func layout() {
        super.layout()
        reportIfNeeded()
    }

    func reportIfNeeded() {
        guard let window else { return }
        let rect = window.convertToScreen(convert(bounds, to: nil))
        guard rect.integral != last.integral else { return }
        last = rect.integral
        onChange?(rect)
    }
}
