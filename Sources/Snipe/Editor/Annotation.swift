import AppKit

enum Tool: Int, CaseIterable, Identifiable {
    case select, pen, arrow, line, rect, ellipse, text, number, highlight, blur, pixelate

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .select: return "Select / Move"
        case .pen: return "Pen"
        case .arrow: return "Arrow"
        case .line: return "Line"
        case .rect: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .text: return "Text"
        case .number: return "Number"
        case .highlight: return "Highlight"
        case .blur: return "Blur"
        case .pixelate: return "Pixelate"
        }
    }

    var symbolName: String {
        switch self {
        case .select: return "cursorarrow"
        case .pen: return "pencil.tip"
        case .arrow: return "arrow.up.right"
        case .line: return "line.diagonal"
        case .rect: return "rectangle"
        case .ellipse: return "circle"
        case .text: return "textformat"
        case .number: return "number"
        case .highlight: return "highlighter"
        case .blur: return "drop.halffull"
        case .pixelate: return "square.grid.3x3.square"
        }
    }
}

struct Annotation {
    var type: Tool
    var rect: CGRect
    var points: [CGPoint] = []
    var color: NSColor = .systemRed
    var strokeWidth: CGFloat = 3
    var fill: Bool = false
    var text: String = ""
    var number: Int = 1
    var textSize: CGFloat = 24

    init(type: Tool, rect: CGRect, points: [CGPoint] = [], color: NSColor = .systemRed,
         strokeWidth: CGFloat = 3, fill: Bool = false, text: String = "",
         number: Int = 1, textSize: CGFloat = 24) {
        self.type = type
        self.rect = rect
        self.points = points
        self.color = color
        self.strokeWidth = strokeWidth
        self.fill = fill
        self.text = text
        self.number = number
        self.textSize = textSize
    }
}

/// Cropped source image plus its display size in points.
struct EditorImage {
    let cgImage: CGImage
    let pointSize: CGSize
    var scale: CGFloat { CGFloat(cgImage.width) / pointSize.width }
}
