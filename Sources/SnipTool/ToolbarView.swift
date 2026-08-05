import AppKit

class EditorToolbar: NSView {
    var onToolChanged: ((ToolType) -> Void)?
    var onColorChanged: ((NSColor) -> Void)?
    var onLineWidthChanged: ((CGFloat) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?

    private var toolButtons: [(tool: ToolType, button: NSButton)] = []
    private var selectedTool: ToolType = .arrow

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    func selectTool(_ tool: ToolType) {
        selectedTool = tool
        onToolChanged?(tool)
        updateButtonStates()
    }

    // MARK: Setup

    private func setupUI() {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let tools: [(ToolType, String, String)] = [
            (.arrow,     "arrow.up.right",    "A"),
            (.rectangle, "rectangle",         "R"),
            (.ellipse,   "circle",            "E"),
            (.line,      "line.diagonal",     "L"),
            (.text,      "textformat",        "T"),
            (.highlight, "highlighter",       "H"),
            (.blur,      "rectangle.dashed",  "B"),
            (.pen,       "pencil.tip",        "P"),
            (.counter,   "number",            "N"),
        ]
        for (tool, symbol, key) in tools {
            let btn = makeButton(symbol: symbol, tip: "\(tool.rawValue) (\(key))")
            btn.target = self
            btn.action = #selector(toolClicked(_:))
            toolButtons.append((tool, btn))
            stack.addArrangedSubview(btn)
        }

        stack.addArrangedSubview(separator())

        // Color
        let cw = NSColorWell(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        cw.color = .systemRed
        cw.target = self
        cw.action = #selector(colorPicked(_:))
        cw.translatesAutoresizingMaskIntoConstraints = false
        cw.widthAnchor.constraint(equalToConstant: 28).isActive = true
        cw.heightAnchor.constraint(equalToConstant: 28).isActive = true
        stack.addArrangedSubview(cw)

        // Width
        let slider = NSSlider(value: 3, minValue: 1, maxValue: 12,
                              target: self, action: #selector(widthChanged(_:)))
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 80).isActive = true
        slider.controlSize = .small
        stack.addArrangedSubview(slider)

        stack.addArrangedSubview(separator())

        // Undo / Redo
        let undo = makeButton(symbol: "arrow.uturn.backward", tip: "Undo (\u{2318}Z)")
        undo.target = self; undo.action = #selector(undoClicked)
        stack.addArrangedSubview(undo)

        let redo = makeButton(symbol: "arrow.uturn.forward", tip: "Redo (\u{2318}\u{21e7}Z)")
        redo.target = self; redo.action = #selector(redoClicked)
        stack.addArrangedSubview(redo)

        stack.addArrangedSubview(separator())

        // Copy / Save
        let copy = makeButton(symbol: "doc.on.doc", tip: "Copy (\u{2318}C)")
        copy.target = self; copy.action = #selector(copyClicked)
        stack.addArrangedSubview(copy)

        let save = makeButton(symbol: "square.and.arrow.down", tip: "Save (\u{2318}S)")
        save.target = self; save.action = #selector(saveClicked)
        stack.addArrangedSubview(save)

        // Spacer
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)

        updateButtonStates()
    }

    // MARK: Factories

    private func makeButton(symbol: String, tip: String) -> NSButton {
        let b = NSButton(frame: NSRect(x: 0, y: 0, width: 32, height: 28))
        b.bezelStyle = .recessed
        b.setButtonType(.pushOnPushOff)
        b.isBordered = true
        b.toolTip = tip
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
        b.imagePosition = .imageOnly
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 32).isActive = true
        b.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return b
    }

    private func separator() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.separatorColor.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: 1).isActive = true
        v.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return v
    }

    // MARK: State

    private func updateButtonStates() {
        for (tool, btn) in toolButtons {
            btn.state = (tool == selectedTool) ? .on : .off
        }
    }

    // MARK: Actions

    @objc private func toolClicked(_ sender: NSButton) {
        for (tool, btn) in toolButtons where btn === sender {
            selectTool(tool)
            return
        }
    }

    @objc private func colorPicked(_ sender: NSColorWell) {
        onColorChanged?(sender.color)
    }

    @objc private func widthChanged(_ sender: NSSlider) {
        onLineWidthChanged?(CGFloat(sender.doubleValue))
    }

    @objc private func undoClicked()  { onUndo?() }
    @objc private func redoClicked() { onRedo?() }
    @objc private func copyClicked() { onCopy?() }
    @objc private func saveClicked() { onSave?() }
}
