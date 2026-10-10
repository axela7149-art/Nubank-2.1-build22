import SwiftUI

/// Tela principal da edição BYPASS7 TEXTURAS.
/// Mantém somente a identidade solicitada após a autenticação.
struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("bypass7.darkTheme") private var isDarkMode = true

    var body: some View {
        ZStack {
            AppTheme.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("BY BYPASS7 - DAVI - MACIEL")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .tracking(0.4)

                Text("BYPASS7 TEXTURAS")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}
