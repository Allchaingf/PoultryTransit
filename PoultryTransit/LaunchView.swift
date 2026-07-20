//
//  LaunchView.swift
//  PoultryTransit
//
//  Thematic splash: crates sliding along a perch-line (transport), a bobbing
//  hen, drifting feathers, and a spring logo entrance. Three+ animated layers,
//  a single coordinator timer, designed exit, and full cleanup on disappear.
//

import SwiftUI

struct LaunchView: View {
    var onFinished: () -> Void

    // Animation flags (reset on disappear to avoid background leaks)
    @State private var isVisible = true
    @State private var bgPulse = false        // Layer 1 — background gradient bokeh
    @State private var cratesPhase: CGFloat = 0   // Layer 2 — sliding crates
    @State private var henBob = false             // Layer 2 — hen
    @State private var feathersDrift = false      // Layer 2 — feathers
    @State private var logoIn = false             // Layer 3 — logo entrance
    @State private var titleIn = false            // Layer 3 — title entrance
    @State private var exiting = false

    // Single coordinator timer
    @State private var timer: Timer?
    @State private var elapsed: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ---- Layer 1: shifting gradient background + bokeh ----
                PT.splashGradient.ignoresSafeArea()

                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: CGFloat(60 + i * 26), height: CGFloat(60 + i * 26))
                        .offset(x: bgPulse ? CGFloat(i) * 30 - 90 : CGFloat(i) * -20 + 60,
                                y: bgPulse ? CGFloat(i) * -34 + 120 : CGFloat(i) * 28 - 90)
                        .blur(radius: 2)
                }

                // ---- Layer 2: perch line + sliding crates + hen + feathers ----
                VStack(spacing: 0) {
                    Spacer()

                    ZStack {
                        // drifting feathers
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: "leaf.fill")
                                .font(.system(size: CGFloat(10 + i * 3)))
                                .foregroundColor(.white.opacity(0.22))
                                .rotationEffect(.degrees(feathersDrift ? 40 : -30))
                                .offset(x: CGFloat(i) * 58 - 130,
                                        y: feathersDrift ? -70 - CGFloat(i) * 16 : 40)
                                .opacity(feathersDrift ? 0.0 : 0.7)
                        }

                        // sliding crates band (transport motif)
                        HStack(spacing: 26) {
                            ForEach(0..<5, id: \.self) { _ in
                                CrateShape()
                                    .stroke(Color.white.opacity(0.85), lineWidth: 2)
                                    .frame(width: 46, height: 34)
                            }
                        }
                        .offset(x: cratesPhase)

                        // bobbing hen on the perch
                        ChickenSilhouette()
                            .fill(Color.white)
                            .frame(width: 64, height: 56)
                            .offset(y: henBob ? -8 : 0)
                            .shadow(color: .black.opacity(0.2), radius: 6, y: 4)
                    }
                    .frame(height: 90)

                    // perch line
                    PerchLine(color: .white.opacity(0.9), pegCount: 6)
                        .frame(width: geo.size.width * 0.7)
                        .padding(.top, 4)

                    Spacer()
                }

                // ---- Layer 3: logo + title entrance ----
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 104, height: 104)
                            .shadow(color: .black.opacity(0.25), radius: 16, y: 10)
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(PT.primaryDeep)
                        ChickenSilhouette()
                            .fill(PT.amber)
                            .frame(width: 30, height: 26)
                            .offset(x: 22, y: -26)
                    }
                    .scaleEffect(logoIn ? 1 : 0.4)
                    .opacity(logoIn ? 1 : 0)

                    VStack(spacing: 6) {
                        Text("Poultry Transit")
                            .font(PTFont.rounded(30, .heavy))
                            .foregroundColor(.white)
                        Text("Prep • Move • Log")
                            .font(PTFont.rounded(14, .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .tracking(2)
                    }
                    .opacity(titleIn ? 1 : 0)
                    .offset(y: titleIn ? 0 : 16)
                }
                .offset(y: -10)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .opacity(exiting ? 0 : 1)
        .scaleEffect(exiting ? 1.18 : 1)
        .onAppear { start() }
        .onDisappear { stopAnimations() }
    }

    // MARK: - Lifecycle

    private func start() {
        isVisible = true
        // Layer 1 loop
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            bgPulse = true
        }
        // Layer 2 loops
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            cratesPhase = -260
        }
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            henBob = true
        }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            feathersDrift = true
        }
        // initialise crates to start off-screen right
        cratesPhase = 220
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            cratesPhase = -300
        }
        runCoordinator()
    }

    /// Single coordinator timer advances staged entrance & triggers exit.
    private func runCoordinator() {
        timer?.invalidate()
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { t in
            elapsed += 0.05
            // phase 3 (1.4s): logo spring entrance
            if elapsed >= 0.6 && !logoIn {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { logoIn = true }
            }
            // title entrance
            if elapsed >= 1.4 && !titleIn {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { titleIn = true }
            }
            // phase 4 (2.5s): designed exit
            if elapsed >= 2.5 && !exiting {
                withAnimation(.easeIn(duration: 0.45)) { exiting = true }
            }
            // finish & hand off
            if elapsed >= 2.95 {
                t.invalidate()
                stopAnimations()
                onFinished()
            }
        }
    }

    /// Stop every looping animation and reset state so nothing leaks into the app.
    private func stopAnimations() {
        timer?.invalidate()
        timer = nil
        isVisible = false
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            bgPulse = false
            cratesPhase = 0
            henBob = false
            feathersDrift = false
        }
    }
}

struct LaunchView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchView(onFinished: {})
    }
}
