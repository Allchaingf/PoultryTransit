//
//  DesignSystem.swift
//  PoultryTransit
//
//  Central visual language: colors, typography, reusable components,
//  poultry / transport themed shapes. iOS 14+ compatible.
//

import SwiftUI

// MARK: - Color from hex

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.replacingOccurrences(of: "#", with: ""))
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

private func dynamicColor(light: String, dark: String) -> Color {
    let l = UIColor(hexString: light)
    let d = UIColor(hexString: dark)
    return Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? d : l
    })
}

private extension UIColor {
    convenience init(hexString: String) {
        let scanner = Scanner(string: hexString.replacingOccurrences(of: "#", with: ""))
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}

// MARK: - Palette

enum PT {
    // Brand
    static let primary = dynamicColor(light: "3E8E7E", dark: "57B3A1")   // transport sage-teal
    static let primaryDeep = dynamicColor(light: "2C6B5E", dark: "3E8E7E")
    static let amber = dynamicColor(light: "F2A93B", dark: "F6BF63")     // straw / feed
    static let clay = dynamicColor(light: "C76B4A", dark: "DD8163")      // warm crate clay

    // Surfaces
    static let background = dynamicColor(light: "FBF7EF", dark: "121417")
    static let card = dynamicColor(light: "FFFFFF", dark: "1E2227")
    static let cardRaised = dynamicColor(light: "FFFFFF", dark: "262B31")
    static let subtle = dynamicColor(light: "F1ECE0", dark: "2A2F36")
    static let stroke = dynamicColor(light: "E7E0D2", dark: "343A42")

    // Text
    static let ink = dynamicColor(light: "27302E", dark: "F2F4F3")
    static let inkSoft = dynamicColor(light: "6B7672", dark: "A7B0AD")
    static let inkFaint = dynamicColor(light: "9AA29E", dark: "767E7B")

    // Status
    static let success = dynamicColor(light: "3FA776", dark: "5BC795")
    static let warning = dynamicColor(light: "E29A2E", dark: "F2B652")
    static let danger = dynamicColor(light: "D9594C", dark: "EE7468")
    static let info = dynamicColor(light: "4F86C6", dark: "6FA3DD")
    static let neutral = dynamicColor(light: "8C948F", dark: "9AA29E")

    // Gradients
    static var heroGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [primary, primaryDeep]),
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var amberGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [amber, clay]),
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var splashGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [Color(hex: "2C6B5E"), Color(hex: "3E8E7E"), Color(hex: "57B3A1")]),
                       startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Typography

enum PTFont {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static let largeTitle = rounded(30, .bold)
    static let title = rounded(24, .bold)
    static let title2 = rounded(20, .semibold)
    static let headline = rounded(17, .semibold)
    static let body = rounded(16, .regular)
    static let callout = rounded(15, .medium)
    static let subhead = rounded(14, .regular)
    static let caption = rounded(12, .medium)
    static let captionBold = rounded(12, .semibold)
}

// MARK: - Status chip

struct StatusChip: View {
    let text: String
    var color: Color = PT.primary
    var filled: Bool = false
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
            }
            Text(text).font(PTFont.captionBold)
        }
        .foregroundColor(filled ? .white : color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(filled ? color : color.opacity(0.14))
        )
    }
}

// MARK: - Card container

struct PTCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PT.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PT.stroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }
}

extension View {
    func ptCardStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PT.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PT.stroke, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }

    func ptScreenBackground() -> some View {
        self.background(PT.background.ignoresSafeArea())
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = PT.heroGradient
    var fullWidth: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PTFont.headline)
            .foregroundColor(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 15)
            .padding(.horizontal, fullWidth ? 0 : 22)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: PT.primary.opacity(0.35), radius: 10, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    var tint: Color = PT.primary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PTFont.headline)
            .foregroundColor(tint)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 15)
            .padding(.horizontal, fullWidth ? 0 : 22)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ChipButtonStyle: ButtonStyle {
    var isSelected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PTFont.callout)
            .foregroundColor(isSelected ? .white : PT.ink)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(CapsuleFill(selected: isSelected))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Concrete capsule background — avoids iOS 16's AnyShapeStyle erasure.
struct CapsuleFill: View {
    var selected: Bool
    var body: some View {
        Group {
            if selected { Capsule().fill(PT.heroGradient) }
            else { Capsule().fill(PT.subtle) }
        }
    }
}

// MARK: - Text field

struct PTTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let icon = icon {
                Image(systemName: icon).foregroundColor(PT.inkSoft).frame(width: 18)
            }
            TextField(placeholder, text: $text)
                .font(PTFont.body)
                .keyboardType(keyboard)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .background(PT.subtle)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(PT.stroke, lineWidth: 1))
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var action: (() -> Void)? = nil
    var actionLabel: String = "See all"

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(PTFont.title2).foregroundColor(PT.ink)
                if let subtitle = subtitle {
                    Text(subtitle).font(PTFont.caption).foregroundColor(PT.inkSoft)
                }
            }
            Spacer()
            if let action = action {
                Button(action: action) {
                    Text(actionLabel).font(PTFont.callout).foregroundColor(PT.primary)
                }
            }
        }
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(PT.primary.opacity(0.12)).frame(width: 88, height: 88)
                IconGlyph(name: icon, size: 30, color: PT.primary)
            }
            Text(title).font(PTFont.headline).foregroundColor(PT.ink)
            Text(message)
                .font(PTFont.subhead).foregroundColor(PT.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle(fullWidth: false))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

// MARK: - Icon glyph (SF Symbol, or the custom hen for the "chicken" sentinel)

/// There is no poultry SF Symbol before iOS 16, so bird/group icons pass the
/// `"chicken"` sentinel and render the app's own ChickenSilhouette instead.
struct IconGlyph: View {
    let name: String
    var size: CGFloat = 18
    var weight: Font.Weight = .semibold
    var color: Color = PT.primary

    var body: some View {
        if name == "chicken" {
            ChickenSilhouette().fill(color)
                .frame(width: size * 1.18, height: size)
        } else {
            Image(systemName: name)
                .font(.system(size: size, weight: weight))
                .foregroundColor(color)
        }
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    var tint: Color = PT.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 38, height: 38)
                IconGlyph(name: icon, size: 18, color: tint)
            }
            Text(value).font(PTFont.title).foregroundColor(PT.ink)
            Text(label).font(PTFont.caption).foregroundColor(PT.inkSoft).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(PT.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PT.stroke, lineWidth: 1))
    }
}

// MARK: - Perch line decoration

struct PerchLine: View {
    var color: Color = PT.stroke
    var pegCount: Int = 5
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Rectangle().fill(color).frame(height: 3)
                HStack(spacing: 0) {
                    ForEach(0..<pegCount, id: \.self) { _ in
                        Spacer()
                        Capsule().fill(color).frame(width: 3, height: 10)
                        Spacer()
                    }
                }
            }
            .frame(width: geo.size.width)
        }
        .frame(height: 13)
    }
}

// MARK: - Chicken silhouette shape (simple hen)

struct ChickenSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        // body
        p.addEllipse(in: CGRect(x: w*0.18, y: h*0.40, width: w*0.62, height: h*0.46))
        // head
        p.addEllipse(in: CGRect(x: w*0.60, y: h*0.18, width: w*0.26, height: h*0.30))
        // tail
        p.move(to: CGPoint(x: w*0.20, y: h*0.55))
        p.addQuadCurve(to: CGPoint(x: w*0.04, y: h*0.30),
                       control: CGPoint(x: w*0.02, y: h*0.52))
        p.addQuadCurve(to: CGPoint(x: w*0.26, y: h*0.50),
                       control: CGPoint(x: w*0.16, y: h*0.40))
        // beak
        p.move(to: CGPoint(x: w*0.85, y: h*0.30))
        p.addLine(to: CGPoint(x: w*0.98, y: h*0.34))
        p.addLine(to: CGPoint(x: w*0.85, y: h*0.40))
        p.closeSubpath()
        // legs
        p.addRect(CGRect(x: w*0.42, y: h*0.84, width: w*0.03, height: h*0.14))
        p.addRect(CGRect(x: w*0.56, y: h*0.84, width: w*0.03, height: h*0.14))
        return p
    }
}

// MARK: - Crate (transport box) shape

struct CrateShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 6
        p.addRoundedRect(in: rect, cornerSize: CGSize(width: r, height: r))
        // slats
        let slatCount = 3
        for i in 1...slatCount {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(slatCount + 1)
            p.move(to: CGPoint(x: x, y: rect.minY + 4))
            p.addLine(to: CGPoint(x: x, y: rect.maxY - 4))
        }
        let y = rect.midY
        p.move(to: CGPoint(x: rect.minX + 4, y: y))
        p.addLine(to: CGPoint(x: rect.maxX - 4, y: y))
        return p
    }
}

// MARK: - Labeled icon row

struct IconLabelRow: View {
    let icon: String
    let title: String
    var detail: String? = nil
    var tint: Color = PT.primary

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.15)).frame(width: 34, height: 34)
                Image(systemName: icon).foregroundColor(tint).font(.system(size: 15, weight: .semibold))
            }
            Text(title).font(PTFont.callout).foregroundColor(PT.ink)
            Spacer()
            if let detail = detail {
                Text(detail).font(PTFont.callout).foregroundColor(PT.inkSoft)
            }
        }
    }
}

// MARK: - Scale-on-tap modifier

struct PressableModifier: ViewModifier {
    @State private var pressed = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressed = true }
                    .onEnded { _ in pressed = false }
            )
    }
}

extension View {
    func pressable() -> some View { modifier(PressableModifier()) }
}

// MARK: - Toast / confirmation banner

struct ConfirmationBanner: View {
    let message: String
    var icon: String = "checkmark.circle.fill"
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(.white)
            Text(message).font(PTFont.callout).foregroundColor(.white)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(Capsule().fill(PT.success))
        .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
    }
}

// Host that shows a transient banner
struct ToastHost: ViewModifier {
    @Binding var message: String?
    func body(content: Content) -> some View {
        ZStack {
            content
            if let message = message {
                VStack {
                    Spacer()
                    ConfirmationBanner(message: message)
                        .padding(.bottom, 28)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View { modifier(ToastHost(message: message)) }
}
