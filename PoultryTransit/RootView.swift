//
//  RootView.swift
//  PoultryTransit
//
//  Entry coordinator (Splash → Onboarding → Main) plus the custom tab bar
//  shell. Five hubs route to all 24 functional screens + Settings.
//

import SwiftUI

// MARK: - Coordinator

struct RootView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var prefs: AppPreferences
    @AppStorage("hasCompletedOnboarding") private var onboarded = false

    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                LaunchView { withAnimation(.easeInOut(duration: 0.4)) { showSplash = false } }
                    .transition(.opacity)
            } else if !onboarded {
                OnboardingView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Tabs

enum AppTab: Int, CaseIterable {
    case dashboard, groups, care, routes, more
    var title: String {
        switch self {
        case .dashboard: return "Today"
        case .groups: return "Groups"
        case .care: return "Care"
        case .routes: return "Transit"
        case .more: return "More"
        }
    }
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .groups: return "chicken"
        case .care: return "heart.text.square.fill"
        case .routes: return "shippingbox.fill"
        case .more: return "ellipsis.circle.fill"
        }
    }
}

struct MainTabView: View {
    @State private var tab: AppTab = .dashboard

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .dashboard: NavHost { DashboardView(switchTab: { tab = $0 }) }
                case .groups:    NavHost { GroupsHubView() }
                case .care:      NavHost { CareHubView() }
                case .routes:    NavHost { RoutesHubView() }
                case .more:      NavHost { MoreHubView() }
                }
            }
            .ptScreenBackground()

            CustomTabBar(selected: $tab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

/// Reusable navigation host (stack style for iPhone) with consistent chrome.
struct NavHost<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        NavigationView {
            content()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Custom tab bar

struct CustomTabBar: View {
    @Binding var selected: AppTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { item in
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { selected = item }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selected == item {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(PT.primary.opacity(0.16))
                                    .matchedGeometryEffect(id: "tabsel", in: ns)
                                    .frame(width: 46, height: 34)
                            }
                            IconGlyph(name: item.icon, size: 19,
                                      color: selected == item ? PT.primary : PT.inkFaint)
                                .scaleEffect(selected == item ? 1.05 : 1)
                        }
                        .frame(height: 34)
                        Text(item.title)
                            .font(.system(size: 10, weight: selected == item ? .semibold : .medium, design: .rounded))
                            .foregroundColor(selected == item ? PT.primary : PT.inkFaint)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .padding(.horizontal, 8)
        .background(
            PT.card
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.10), radius: 16, y: -2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(PT.stroke, lineWidth: 1)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }
}
