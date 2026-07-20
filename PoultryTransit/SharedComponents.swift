//
//  SharedComponents.swift
//  PoultryTransit
//
//  Reusable cross-screen building blocks: hub cards, charts (bar / line /
//  donut), selectable chips, image picker, share sheet, PDF report builder.
//  All iOS 14 compatible (custom-drawn charts, UIKit interop).
//

import SwiftUI
import UIKit

// MARK: - Hub navigation card

struct HubLinkCard<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    var tint: Color = PT.primary
    var badge: String? = nil
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tint.opacity(0.16)).frame(width: 44, height: 44)
                        IconGlyph(name: icon, size: 20, color: tint)
                    }
                    Spacer()
                    if let badge = badge {
                        Text(badge).font(PTFont.captionBold).foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(PT.danger))
                    } else {
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(PT.inkFaint)
                    }
                }
                Text(title).font(PTFont.headline).foregroundColor(PT.ink)
                Text(subtitle).font(PTFont.caption).foregroundColor(PT.inkSoft).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background(PT.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PT.stroke, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Two-column hub grid.
struct HubGrid<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            content()
        }
    }
}

// MARK: - Screen scaffold with title + actions

struct ScreenScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if let subtitle = subtitle {
                    Text(subtitle).font(PTFont.subhead).foregroundColor(PT.inkSoft)
                }
                content()
                Color.clear.frame(height: 90)   // tab bar clearance
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .navigationBarTitle(title, displayMode: .inline)
        .ptScreenBackground()
    }
}

// MARK: - Selectable chips (horizontal scroll)

struct SegChips: View {
    let options: [String]
    @Binding var selection: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { opt in
                    Button { selection = opt } label: { Text(opt) }
                        .buttonStyle(ChipButtonStyle(isSelected: selection == opt))
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Toolbar action button (for nav bar trailing)

struct CircleIconButton: View {
    let icon: String
    var tint: Color = PT.primary
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint.opacity(0.15)))
        }
    }
}

// MARK: - Dual action bar (two primary CTAs per screen spec)

struct DualActionBar: View {
    let primaryTitle: String
    let primaryIcon: String
    let primaryAction: () -> Void
    let secondaryTitle: String
    let secondaryIcon: String
    let secondaryAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: primaryAction) {
                Label(primaryTitle, systemImage: primaryIcon)
            }
            .buttonStyle(PrimaryButtonStyle())
            Button(action: secondaryAction) {
                Label(secondaryTitle, systemImage: secondaryIcon)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}

// MARK: - Bar chart

struct BarChartView: View {
    let values: [(label: String, value: Double)]
    var tint: Color = PT.primary
    var plotHeight: CGFloat = 130
    var unitPrefix: String = ""

    var body: some View {
        let maxV = max(values.map { $0.value }.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(values.indices, id: \.self) { i in
                VStack(spacing: 6) {
                    Text(values[i].value > 0 ? "\(unitPrefix)\(FarmStore.num(values[i].value))" : "")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(PT.inkSoft)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(LinearGradient(gradient: Gradient(colors: [tint, tint.opacity(0.6)]),
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: max(4, CGFloat(values[i].value / maxV) * plotHeight))
                    Text(values[i].label)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(PT.inkFaint).lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: plotHeight + 38, alignment: .bottom)
    }
}

// MARK: - Line chart

struct LineChartView: View {
    let points: [Double]
    let labels: [String]
    var tint: Color = PT.primary
    var plotHeight: CGFloat = 130

    var body: some View {
        let maxV = max(points.max() ?? 1, 1)
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let stepX = points.count > 1 ? w / CGFloat(points.count - 1) : w
                ZStack {
                    // area
                    Path { p in
                        guard !points.isEmpty else { return }
                        p.move(to: CGPoint(x: 0, y: h))
                        for (i, v) in points.enumerated() {
                            p.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: h - CGFloat(v / maxV) * h))
                        }
                        p.addLine(to: CGPoint(x: CGFloat(points.count - 1) * stepX, y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(gradient: Gradient(colors: [tint.opacity(0.30), tint.opacity(0.02)]),
                                         startPoint: .top, endPoint: .bottom))
                    // line
                    Path { p in
                        guard !points.isEmpty else { return }
                        p.move(to: CGPoint(x: 0, y: h - CGFloat(points[0] / maxV) * h))
                        for (i, v) in points.enumerated() {
                            p.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: h - CGFloat(v / maxV) * h))
                        }
                    }
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    // dots
                    ForEach(points.indices, id: \.self) { i in
                        Circle().fill(tint).frame(width: 7, height: 7)
                            .position(x: CGFloat(i) * stepX, y: h - CGFloat(points[i] / maxV) * h)
                    }
                }
            }
            .frame(height: plotHeight)
            HStack(spacing: 0) {
                ForEach(labels.indices, id: \.self) { i in
                    Text(labels[i]).font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(PT.inkFaint).frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Donut chart

struct DonutChartView: View {
    let segments: [(label: String, value: Double, color: Color)]
    var body: some View {
        let total = max(segments.reduce(0) { $0 + $1.value }, 0.0001)
        HStack(spacing: 18) {
            ZStack {
                ForEach(segments.indices, id: \.self) { i in
                    let start = segments[..<i].reduce(0.0) { $0 + $1.value } / total
                    let end = start + segments[i].value / total
                    Circle()
                        .trim(from: CGFloat(start), to: CGFloat(end))
                        .stroke(segments[i].color, style: StrokeStyle(lineWidth: 18, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
                VStack(spacing: 0) {
                    Text(FarmStore.num(total)).font(PTFont.headline).foregroundColor(PT.ink)
                    Text("total").font(.system(size: 9, design: .rounded)).foregroundColor(PT.inkFaint)
                }
            }
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(segments.indices, id: \.self) { i in
                    HStack(spacing: 8) {
                        Circle().fill(segments[i].color).frame(width: 10, height: 10)
                        Text(segments[i].label).font(PTFont.caption).foregroundColor(PT.ink)
                        Spacer()
                        Text(FarmStore.num(segments[i].value)).font(PTFont.captionBold).foregroundColor(PT.inkSoft)
                    }
                }
            }
        }
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    let progress: Double      // 0...1
    var tint: Color = PT.primary
    var size: CGFloat = 76
    var label: String? = nil
    var body: some View {
        ZStack {
            Circle().stroke(PT.stroke, lineWidth: 9)
            Circle().trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            Text(label ?? "\(Int(progress * 100))%")
                .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                .foregroundColor(PT.ink)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Image picker (UIKit)

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    var onPicked: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onPicked(img) }
            parent.presentationMode.wrappedValue.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Share sheet (UIKit)

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - PDF report builder

enum PDFReportBuilder {
    static func build(title: String, sections: [(heading: String, lines: [String])]) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @72dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PoultryTransit-Report.pdf")

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                var y: CGFloat = 48
                let margin: CGFloat = 40

                // Title block
                let titleAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 26, weight: .bold),
                    .foregroundColor: UIColor(red: 0.17, green: 0.42, blue: 0.37, alpha: 1)
                ]
                title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttr)
                y += 38
                let df = DateFormatter(); df.dateStyle = .long; df.timeStyle = .short
                "Poultry Transit • " .appending(df.string(from: Date())).draw(
                    at: CGPoint(x: margin, y: y),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 11),
                                     .foregroundColor: UIColor.gray])
                y += 30

                for section in sections {
                    if y > pageRect.height - 90 { ctx.beginPage(); y = 48 }
                    let headAttr: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                        .foregroundColor: UIColor.darkGray]
                    section.heading.draw(at: CGPoint(x: margin, y: y), withAttributes: headAttr)
                    y += 24
                    // divider
                    let path = UIBezierPath()
                    path.move(to: CGPoint(x: margin, y: y))
                    path.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
                    UIColor(white: 0.85, alpha: 1).setStroke()
                    path.lineWidth = 1; path.stroke()
                    y += 12

                    for line in section.lines {
                        if y > pageRect.height - 70 { ctx.beginPage(); y = 48 }
                        line.draw(at: CGPoint(x: margin + 6, y: y),
                                  withAttributes: [.font: UIFont.systemFont(ofSize: 12),
                                                   .foregroundColor: UIColor.black])
                        y += 19
                    }
                    y += 18
                }
            }
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Editor presentation wrapper

/// Wraps an optional record for `.sheet(item:)`-driven editors. `value == nil`
/// means "create new"; a non-nil value means "edit this record". Lets one sheet
/// serve both Add and Edit without stacking multiple `.sheet` modifiers.
struct EditorItem<T>: Identifiable {
    let id = UUID()
    let value: T?
    static func new() -> EditorItem<T> { EditorItem(value: nil) }
    static func edit(_ v: T) -> EditorItem<T> { EditorItem(value: v) }
}

// MARK: - Labeled field row for forms

struct FormRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(PT.inkSoft)
            content()
        }
    }
}

// MARK: - Stepper field

struct StepperField: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...9999
    var step: Int = 1
    var body: some View {
        HStack {
            Text(label).font(PTFont.callout).foregroundColor(PT.ink)
            Spacer()
            HStack(spacing: 0) {
                stepButton("minus") { if value - step >= range.lowerBound { value -= step } }
                Text("\(value)").font(PTFont.headline).foregroundColor(PT.ink)
                    .frame(minWidth: 48)
                stepButton("plus") { if value + step <= range.upperBound { value += step } }
            }
            .background(PT.subtle)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    private func stepButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold))
                .foregroundColor(PT.primary).frame(width: 40, height: 38)
        }
    }
}

// MARK: - Row card (list item container)

struct RowCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PT.card)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(PT.stroke, lineWidth: 1))
    }
}
