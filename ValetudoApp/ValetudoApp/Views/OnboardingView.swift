import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "house.fill",
            iconColor: .blue,
            title: String(localized: "onboarding.welcome.title"),
            subtitle: String(localized: "onboarding.welcome.subtitle"),
            features: []
        ),
        OnboardingPage(
            icon: "map.fill",
            iconColor: .green,
            title: String(localized: "onboarding.map.title"),
            subtitle: String(localized: "onboarding.map.subtitle"),
            features: [
                OnboardingFeature(icon: "square.split.2x2", text: String(localized: "onboarding.map.feature1")),
                OnboardingFeature(icon: "rectangle.dashed", text: String(localized: "onboarding.map.feature2")),
                OnboardingFeature(icon: "star.fill", text: String(localized: "onboarding.map.feature3"))
            ]
        ),
        OnboardingPage(
            icon: "bell.fill",
            iconColor: .orange,
            title: String(localized: "onboarding.notifications.title"),
            subtitle: String(localized: "onboarding.notifications.subtitle"),
            features: [
                OnboardingFeature(icon: "checkmark.circle", text: String(localized: "onboarding.notifications.feature1")),
                OnboardingFeature(icon: "exclamationmark.triangle", text: String(localized: "onboarding.notifications.feature2")),
                OnboardingFeature(icon: "arrow.down.circle", text: String(localized: "onboarding.notifications.feature3"))
            ]
        ),
        OnboardingPage(
            icon: "plus.circle.fill",
            iconColor: .purple,
            title: String(localized: "onboarding.start.title"),
            subtitle: String(localized: "onboarding.start.subtitle"),
            features: []
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 20)

            // Button
            Button {
                if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    hasCompletedOnboarding = true
                }
            } label: {
                Text(currentPage < pages.count - 1 ? String(localized: "onboarding.next") : String(localized: "onboarding.start_button"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // Skip button (not on last page)
            if currentPage < pages.count - 1 {
                Button {
                    hasCompletedOnboarding = true
                } label: {
                    Text(String(localized: "onboarding.skip"))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 24)
            } else {
                Spacer()
                    .frame(height: 44)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let features: [OnboardingFeature]
}

struct OnboardingFeature {
    let icon: String
    let text: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundStyle(page.iconColor)
                .padding(.bottom, 8)

            // Title
            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Subtitle
            Text(page.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Features list
            if !page.features.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(page.features, id: \.text) { feature in
                        HStack(spacing: 12) {
                            Image(systemName: feature.icon)
                                .font(.title3)
                                .foregroundStyle(page.iconColor)
                                .frame(width: 28)

                            Text(feature.text)
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 16)
            }

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
