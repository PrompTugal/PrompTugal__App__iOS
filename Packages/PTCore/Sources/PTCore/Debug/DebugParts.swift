import SwiftUI

/// A horizontal bar showing a duration against the slowest in view.
public struct TimingBar: View {
    public let value: Double
    public let maxValue: Double
    public var color: Color = Palette.blue

    public init(value: Double, maxValue: Double, color: Color = Palette.blue) {
        self.value = value
        self.maxValue = maxValue
        self.color = color
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.rule.opacity(0.4))
                Capsule().fill(color)
                    .frame(width: max(2, geo.size.width * CGFloat(min(value / max(maxValue, 0.001), 1))))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

/// A chip that toggles a filter.
public struct FilterChip: View {
    public let title: String
    public let isOn: Bool
    public var color: Color = Palette.red
    public let action: () -> Void

    public init(title: String, isOn: Bool, color: Color = Palette.red, action: @escaping () -> Void) {
        self.title = title
        self.isOn = isOn
        self.color = color
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(isOn ? Color.white : color)
                .background(isOn ? color : color.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
