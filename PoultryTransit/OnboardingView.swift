//
//  OnboardingView.swift
//  PoultryTransit
//
//  4-screen onboarding. Each screen has a unique illustrated scene and a
//  distinct interactive element: tap-burst, drag-to-load, tilt parallax,
//  press-and-hold. Choices persist to AppPreferences. iOS 14 page TabView.
//

import SwiftUI
import Combine
import CoreMotion

// MARK: - Motion (parallax) manager

final class MotionManager: ObservableObject {
    private let manager = CMMotionManager()
    @Published var roll: Double = 0
    @Published var pitch: Double = 0

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let d = data else { return }
            self?.roll = d.attitude.roll
            self?.pitch = d.attitude.pitch
        }
    }
    func stop() { manager.stopDeviceMotionUpdates() }
}

// MARK: - Container

struct OnboardingView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var prefs: AppPreferences
    @AppStorage("hasCompletedOnboarding") private var done = false

    @State private var page = 0
    @State private var toast: String?
    @State private var wantsSample = false

    private let lastPage = 3

    var body: some View {
        ZStack {
            PT.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Step \(page + 1) of 4")
                        .font(PTFont.caption).foregroundColor(PT.inkSoft)
                    Spacer()
                    Button("Skip") { finish(loadSample: false) }
                        .font(PTFont.callout).foregroundColor(PT.inkSoft)
                }
                .padding(.horizontal, 24).padding(.top, 14)

                TabView(selection: $page) {
                    PurposePage().tag(0)
                    SamplePage(toast: $toast, wantsSample: $wantsSample).tag(1)
                    MetricsPage().tag(2)
                    FinishPage(wantsSample: $wantsSample).tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? PT.primary : PT.stroke)
                            .frame(width: i == page ? 22 : 8, height: 8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: page)
                    }
                }
                .padding(.bottom, 14)

                Button(action: advance) {
                    Text(ctaTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
            }
        }
        .environmentObject(store)
        .environmentObject(prefs)
        .toast($toast)
    }

    private var ctaTitle: String {
        switch page {
        case 0: return "Continue"
        case 1: return "Continue"
        case 2: return "Choose Metrics"
        default: return wantsSample ? "Open with Sample Data" : "Start Empty Workspace"
        }
    }

    private func advance() {
        switch page {
        case lastPage:
            finish(loadSample: wantsSample)
        default:
            withAnimation { page += 1 }
        }
    }

    private func finish(loadSample: Bool) {
        if loadSample { store.loadSampleData() }
        if prefs.notificationsEnabled {
            NotificationManager.shared.requestAuthorization { granted in
                if granted { NotificationManager.shared.resyncAll(store.reminders, enabled: true) }
            }
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { done = true }
    }
}

// MARK: - Page 1 — Purpose (tap to burst particles + scenario choice)

private struct PurposePage: View {
    @EnvironmentObject var prefs: AppPreferences
    @State private var burst = false
    @State private var pulse = false

    private let scenarios: [(String, String, String)] = [
        ("planning", "Planning", "calendar"),
        ("inventory", "Inventory", "shippingbox.fill"),
        ("movement", "Movement", "arrow.left.arrow.right"),
        ("observation", "Observation", "eye.fill")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .stroke(PT.primary.opacity(0.25), lineWidth: 2)
                        .frame(width: 150, height: 150)
                        .scaleEffect(pulse ? 1.12 : 0.9)
                        .opacity(pulse ? 0 : 0.8)

                    // burst particles
                    ForEach(0..<10, id: \.self) { i in
                        Circle()
                            .fill(i % 2 == 0 ? PT.amber : PT.primary)
                            .frame(width: 10, height: 10)
                            .offset(x: burst ? cos(angle(i)) * 96 : 0,
                                    y: burst ? sin(angle(i)) * 96 : 0)
                            .opacity(burst ? 0 : 1)
                    }

                    Circle().fill(PT.heroGradient).frame(width: 116, height: 116)
                        .shadow(color: PT.primary.opacity(0.4), radius: 14, y: 8)
                    Image(systemName: "house.fill")
                        .font(.system(size: 46, weight: .bold)).foregroundColor(.white)
                }
                .padding(.top, 10)
                .onTapGesture { triggerBurst() }

                Text("Tap the coop to begin")
                    .font(PTFont.caption).foregroundColor(PT.inkFaint)

                VStack(spacing: 6) {
                    Text("Build a farm routine that fits")
                        .font(PTFont.title).foregroundColor(PT.ink)
                        .multilineTextAlignment(.center)
                    Text("Pick the main scenario you want Poultry Transit to help with.")
                        .font(PTFont.subhead).foregroundColor(PT.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(scenarios, id: \.0) { s in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                prefs.primaryScenario = s.0
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: s.2).font(.system(size: 22, weight: .semibold))
                                Text(s.1).font(PTFont.callout)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 18)
                            .foregroundColor(prefs.primaryScenario == s.0 ? .white : PT.ink)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(prefs.primaryScenario == s.0 ? PT.primary : PT.subtle)
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
        }
        .onDisappear {
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { pulse = false; burst = false }
        }
    }

    private func angle(_ i: Int) -> Double { Double(i) / 10 * 2 * .pi }
    private func triggerBurst() {
        burst = false
        withAnimation(.easeOut(duration: 0.6)) { burst = true }
    }
}

// MARK: - Page 2 — Sample (drag a crate into the truck)

private struct SamplePage: View {
    @Binding var toast: String?
    @Binding var wantsSample: Bool
    @State private var drag = CGSize.zero
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Try the transport flow")
                        .font(PTFont.title).foregroundColor(PT.ink)
                    Text("Drag the crate onto the truck to see how interactive elements work across the app.")
                        .font(PTFont.subhead).foregroundColor(PT.inkSoft)
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                }
                .padding(.top, 16)

                ZStack {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(loaded ? PT.success.opacity(0.2) : PT.subtle)
                            .frame(width: 120, height: 90)
                            .overlay(
                                Image(systemName: loaded ? "checkmark" : "shippingbox")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(loaded ? PT.success : PT.inkFaint)
                            )
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(PT.primary).frame(width: 70, height: 60)
                            Image(systemName: "car.fill").foregroundColor(.white)
                        }
                        .offset(y: 14)
                    }
                    .offset(x: 40, y: 70)

                    HStack(spacing: 120) {
                        Circle().fill(PT.ink).frame(width: 22, height: 22)
                        Circle().fill(PT.ink).frame(width: 22, height: 22)
                    }
                    .offset(x: 30, y: 130)

                    CrateShape()
                        .stroke(PT.clay, lineWidth: 3)
                        .background(CrateShape().fill(PT.amber.opacity(0.25)))
                        .frame(width: 64, height: 50)
                        .offset(x: -90 + drag.width, y: -40 + drag.height)
                        .gesture(
                            DragGesture()
                                .onChanged { v in drag = v.translation }
                                .onEnded { v in
                                    if v.translation.width > 90 && v.translation.height > 80 {
                                        withAnimation(.spring()) {
                                            loaded = true
                                            drag = CGSize(width: 130, height: 110)
                                        }
                                        toast = "Crate loaded"
                                    } else {
                                        withAnimation(.spring()) { drag = .zero }
                                    }
                                }
                        )
                }
                .frame(height: 230)

                StatusChip(text: loaded ? "Crate ready" : "Drag to load",
                           color: loaded ? PT.success : PT.inkSoft, filled: loaded,
                           icon: loaded ? "checkmark" : "hand.draw.fill")

                VStack(spacing: 10) {
                    Text("How do you want to start?")
                        .font(PTFont.headline).foregroundColor(PT.ink)

                    Button {
                        withAnimation { wantsSample = false }
                    } label: {
                        HStack {
                            Image(systemName: "square.dashed").foregroundColor(!wantsSample ? .white : PT.primary)
                            Text("Start with an empty workspace")
                            Spacer()
                            if !wantsSample { Image(systemName: "checkmark.circle.fill").foregroundColor(.white) }
                        }
                        .font(PTFont.callout)
                        .foregroundColor(!wantsSample ? .white : PT.ink)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(!wantsSample ? PT.primary : PT.subtle))
                    }

                    Button {
                        withAnimation { wantsSample = true }
                    } label: {
                        HStack {
                            Image(systemName: "tray.full.fill").foregroundColor(wantsSample ? .white : PT.amber)
                            Text("Explore sample workspace")
                            Spacer()
                            if wantsSample { Image(systemName: "checkmark.circle.fill").foregroundColor(.white) }
                        }
                        .font(PTFont.callout)
                        .foregroundColor(wantsSample ? .white : PT.ink)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(wantsSample ? PT.amber : PT.subtle))
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Page 3 — Metrics (tilt parallax + metric choice)

private struct MetricsPage: View {
    @EnvironmentObject var prefs: AppPreferences
    @StateObject private var motion = MotionManager()

    private let metricsInfo: [(String, String)] = [
        ("Care activity", "chart.bar.fill"),
        ("Care consistency", "checkmark.seal.fill"),
        ("Cost", "dollarsign.circle.fill"),
        ("Route time", "clock.fill")
    ]

    var body: some View {
        VStack(spacing: 20) {
            parallaxScene
                .padding(.horizontal, 24).padding(.top, 16)
                .clipped()

            Text("Tilt your phone to preview")
                .font(PTFont.caption).foregroundColor(PT.inkFaint)

            VStack(spacing: 6) {
                Text("See trends, not noise")
                    .font(PTFont.title).foregroundColor(PT.ink)
                Text("Choose which metrics shape your Dashboard and Analytics.")
                    .font(PTFont.subhead).foregroundColor(PT.inkSoft)
                    .multilineTextAlignment(.center).padding(.horizontal, 24)
            }

            VStack(spacing: 10) {
                ForEach(metricsInfo, id: \.0) { m in
                    let on = prefs.selectedMetrics.contains(m.0)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { toggle(m.0) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: m.1).foregroundColor(on ? PT.primary : PT.inkFaint).frame(width: 24)
                            Text(m.0).font(PTFont.callout).foregroundColor(PT.ink)
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(on ? PT.primary : PT.stroke)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(on ? PT.primary.opacity(0.08) : PT.subtle))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(on ? PT.primary.opacity(0.4) : Color.clear, lineWidth: 1.5))
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }

    // Parallax scene extracted to keep the type-checker fast
    private var parallaxScene: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(PT.heroGradient).frame(height: 150)
                .offset(x: CGFloat(motion.roll) * 8, y: CGFloat(motion.pitch) * 6)
            ForEach(0..<3, id: \.self) { i in
                bar(i)
            }
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 30, weight: .bold)).foregroundColor(.white)
                .offset(x: 70 + CGFloat(motion.roll) * 22, y: -36)
        }
    }

    private func bar(_ i: Int) -> some View {
        let height = CGFloat(40 + i * 22)
        let baseX = CGFloat(i * 34 - 34)
        let dx = baseX + CGFloat(motion.roll) * CGFloat(16 + i * 8)
        let dy = CGFloat(30) - CGFloat(motion.pitch) * CGFloat(10 + i * 6)
        return RoundedRectangle(cornerRadius: 4)
            .fill(Color.white.opacity(0.85))
            .frame(width: 26, height: height)
            .offset(x: dx, y: dy)
    }

    private func toggle(_ metric: String) {
        if let i = prefs.selectedMetrics.firstIndex(of: metric) {
            if prefs.selectedMetrics.count > 1 { prefs.selectedMetrics.remove(at: i) }
        } else {
            prefs.selectedMetrics.append(metric)
        }
    }
}

// MARK: - Page 4 — Finish (press & hold to open the coop)

private struct FinishPage: View {
    @Binding var wantsSample: Bool
    @State private var progress: CGFloat = 0
    @State private var open = false
    @State private var holdTimer: Timer?

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            coopScene

            Text(open ? "Workspace ready" : "Press & hold the coop to open")
                .font(PTFont.caption).foregroundColor(PT.inkFaint)

            VStack(spacing: 6) {
                Text("Open your farm workspace")
                    .font(PTFont.title).foregroundColor(PT.ink)
                Text(wantsSample
                     ? "You'll start with sample data to explore every feature."
                     : "You'll start with a clean workspace — add your own data.")
                    .font(PTFont.subhead).foregroundColor(PT.inkSoft)
                    .multilineTextAlignment(.center).padding(.horizontal, 28)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .gesture(
            LongPressGesture(minimumDuration: 0.01)
                .onChanged { _ in startHold() }
                .onEnded { _ in }
                .simultaneously(with: DragGesture(minimumDistance: 0).onEnded { _ in endHold() })
        )
        .onDisappear { holdTimer?.invalidate(); holdTimer = nil }
    }

    private var coopScene: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PT.subtle).frame(width: 180, height: 150)
            Triangle().fill(PT.clay).frame(width: 210, height: 56).offset(y: -100)

            RoundedRectangle(cornerRadius: 8)
                .fill(PT.primary)
                .frame(width: 74, height: 104)
                .rotation3DEffect(.degrees(open ? -82 : 0), axis: (x: 0, y: 1, z: 0), anchor: .leading)
                .offset(x: -2, y: 16)
                .overlay(
                    Circle().fill(PT.amber).frame(width: 9, height: 9)
                        .offset(x: 22, y: 16).opacity(open ? 0 : 1)
                )

            if open {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 30)).foregroundColor(PT.amber)
                    .offset(y: 14).transition(.scale)
            }

            Circle()
                .trim(from: 0, to: progress)
                .stroke(PT.amber, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .opacity(open ? 0 : 1)
        }
    }

    private func startHold() {
        guard holdTimer == nil, !open else { return }
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { t in
            progress += 0.02 / 0.9
            if progress >= 1 {
                t.invalidate(); holdTimer = nil
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { open = true }
            }
        }
    }
    private func endHold() {
        holdTimer?.invalidate(); holdTimer = nil
        if !open { withAnimation(.easeOut(duration: 0.3)) { progress = 0 } }
    }
}

// Simple triangle for the roof
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
