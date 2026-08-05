import AppKit

/// Two-row toolbar: tools on top, styling + actions below.
final class ToolbarView: NSView {

    var onToolChanged: ((Tool) -> Void)?
    var onColorChanged: ((NSColor) -> Void)?
    var onWidthChanged: ((CGFloat) -> Void)?
    var onFillChanged: ((Bool) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?
    var onZoomIn: (() -> Void)?
    var onZoomOut: (() -> Void)?
    var onFit: (() -> Void)?

    private let toolControl = NSSegmentedControl()
    private let widthSlider = NSSlider(value: 3, minValue: 1, maxValue: 24, target: nil, action: nil)
    private let widthLabel = NSTextField(labelWithString: "3")
    private let fillCheckbox = NSButton(checkboxWithTitle: "Fill", target: nil, action: nil)

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        // Row 1: tools
        for tool in Tool.allCases {
            let image = NSImage(systemSymbolName: tool.symbolName, accessibilityDescription: tool.displayName)
            toolControl.segmentCount += 1
            let idx = toolControl.segmentCount - 1
            toolControl.setImage(image, forSegment: idx)
            toolControl.setToolTip(tool.displayName, forSegment: idx)
            toolControl.setWidth(30, forSegment: idx)
        }
        toolControl.trackingMode = .selectOne
        toolControl.selectedSegment = 0
        toolControl.target = self
        toolControl.action = #selector(toolChanged(_:))

        // Row 2 controls
        let colorWell = NSColorWell()
        colorWell.color = .systemRed
        colorWell.target = self
        colorWell.action = #selector(colorChanged(_:))
        colorWell.toolTip = "Color"

        widthSlider.isContinuous = true
        widthSlider.target = self
        widthSlider.action = #selector(widthChanged(_:))
        widthSlider.toolTip = "Stroke width"
        widthLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        widthLabel.alignment = .center
        widthLabel.widthAnchor.constraint(equalToConstant: 20).isActive = true

        fillCheckbox.target = self
        fillCheckbox.action = #selector(fillChanged(_:))
        fillCheckbox.toolTip = "Fill shapes"

        let undo = makeButton("arrow.uturn.backward", "Undo (⌘Z)", #selector(undoAction))
        let redo = makeButton("arrow.uturn.forward", "Redo (⇧⌘Z)", #selector(redoAction))
        let zoomIn = makeButton("plus.magnifyingglass", "Zoom in (⌘=)", #selector(zoomInAction))
        let zoomOut = makeButton("minus.magnifyingglass", "Zoom out (⌘-)", #selector(zoomOutAction))
        let fit = makeButton("arrow.up.left.and.arrow.down.right", "Fit to window (⌘0)", #selector(fitAction))
        let copy = makeButton("doc.on.clipboard", "Copy & close (⏎)", #selector(copyAction))
        let save = makeButton("square.and.arrow.down", "Save As…", #selector(saveAction))
        let cancel = makeButton("xmark", "Cancel (Esc)", #selector(cancelAction))
        copy.bezelColor = .controlAccentColor
        save.bezelColor = .controlAccentColor

        let row1 = NSStackView(views: [toolControl])
        row1.orientation = .horizontal
        row1.spacing = 4

        let row2 = NSStackView(views: [
            colorWell, widthSlider, widthLabel, fillCheckbox,
            separator(), undo, redo,
            separator(), zoomOut, zoomIn, fit,
            NSView(), // flexible spacer
            copy, save, cancel
        ])
        row2.orientation = .horizontal
        row2.spacing = 6

        let stack = NSStackView(views: [row1, row2])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    private func separator() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.separatorColor.cgColor
        v.widthAnchor.constraint(equalToConstant: 1).isActive = true
        v.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return v
    }

    private func makeButton(_ symbol: String, _ tip: String, _ action: Selector) -> NSButton {
        let b = NSButton()
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
        b.imagePosition = .imageOnly
        b.bezelStyle = .texturedRounded
        b.toolTip = tip
        b.target = self
        b.action = action
        return b
    }

    // MARK: Actions

    @objc private func toolChanged(_ sender: NSSegmentedControl) {
        if let tool = Tool(rawValue: sender.selectedSegment) {
            onToolChanged?(tool)
        }
    }

    @objc private func colorChanged(_ sender: NSColorWell) {
        onColorChanged?(sender.color)
    }

    @objc private func widthChanged(_ sender: NSSlider) {
        widthLabel.stringValue = "\(Int(sender.doubleValue.rounded()))"
        onWidthChanged?(CGFloat(sender.doubleValue))
    }

    @objc private func fillChanged(_ sender: NSButton) {
        onFillChanged?(sender.state == .on)
    }

    @objc private func undoAction() { onUndo?() }
    @objc private func redoAction() { onRedo?() }
    @objc private func zoomInAction() { onZoomIn?() }
    @objc private func zoomOutAction() { onZoomOut?() }
    @objc private func fitAction() { onFit?() }
    @objc private func copyAction() { onCopy?() }
    @objc private func saveAction() { onSave?() }
    @objc private func cancelAction() { onCancel?() }
}
