import SwiftUI
import UIKit

struct LoginView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @FocusState private var isKeyFieldFocused: Bool
    @State private var contentVisible = false

    private let accent = AppTheme.accent

    var body: some View {
        ZStack {
            LoginBackdrop(accent: accent)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 26) {
                    Spacer(minLength: 34)

                    VStack(spacing: 11) {
                        ZStack {
                            Circle()
                                .fill(accent.opacity(0.24))
                                .frame(width: 96, height: 96)
                                .blur(radius: 18)
                            AppLogo(size: 76)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                                }
                                .shadow(color: accent.opacity(0.34), radius: 14, y: 4)
                        }
                        .frame(height: 88)

                        Text("CapCut")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .tracking(0.4)
                            .foregroundStyle(.white)

                        Text("ACESSO À SUA CONTA")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2.1)
                            .foregroundStyle(accent)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("KEY DE ACESSO")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.3)
                                .foregroundStyle(accent)

                            SecureField("Digite sua key", text: $viewModel.enteredKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isKeyFieldFocused)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(Color.white.opacity(0.055))
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .strokeBorder(
                                            isKeyFieldFocused ? accent.opacity(0.95) : Color.white.opacity(0.13),
                                            lineWidth: 1
                                        )
                                }
                                .foregroundStyle(.black)
                                .tint(.black)
                                .onSubmit { submit() }
                        }

                        Button(action: submit) {
                            Group {
                                if viewModel.isLoading {
                                    HStack(spacing: 10) {
                                        ProgressView().tint(.white)
                                        Text("Validando...")
                                    }
                                } else if viewModel.isRevalidating {
                                    HStack(spacing: 10) {
                                        ProgressView().tint(.white)
                                        Text("Revalidando...")
                                    }
                                } else {
                                    Label("Entrar", systemImage: "arrow.right.circle.fill")
                                }
                            }
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                LinearGradient(
                                    colors: [Color.white, Color(red: 0.82, green: 0.82, blue: 0.84)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )
                            .shadow(color: Color.white.opacity(0.16), radius: 10, y: 4)
                        }
                        .disabled(viewModel.isLoading || viewModel.isRevalidating)
                        .buttonStyle(.plain)

                        if viewModel.showError {
                            Text(viewModel.errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.accent)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 2)
                        }
                    }
                    .padding(22)
                    .background(
                        Color.black,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.26), Color.clear, Color.white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.white.opacity(0.10), radius: 20, y: 8)
                    .frame(maxWidth: 420)

                    Spacer(minLength: 20)

                    Text("DIGITE SUA KEY PARA CONTINUAR")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(Color.white.opacity(0.42))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 8)
        }
        .preferredColorScheme(.dark)
        .onTapGesture {
            isKeyFieldFocused = false
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.24)) {
                contentVisible = true
            }
        }
    }

    private func submit() {
        guard !viewModel.isLoading else { return }
        Task { await viewModel.login() }
    }
}

private struct LoginBackdrop: View {
    let accent: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color(red: 0.025, green: 0.025, blue: 0.03), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [Color.white.opacity(0.12), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 380
                )

                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    path.move(to: CGPoint(x: 0, y: height * 0.18))
                    path.addLine(to: CGPoint(x: width * 0.27, y: height * 0.10))
                    path.addLine(to: CGPoint(x: width * 0.42, y: height * 0.21))
                    path.move(to: CGPoint(x: width, y: height * 0.72))
                    path.addLine(to: CGPoint(x: width * 0.76, y: height * 0.80))
                    path.addLine(to: CGPoint(x: width * 0.92, y: height * 0.92))
                }
                .stroke(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}


struct AuthenticatedRootView: View {
    @ObservedObject var viewModel: AuthenticationViewModel

    var body: some View {
        Group {
            if viewModel.isAuthenticated {
                ContentView()
            } else {
                LoginView(viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isAuthenticated)
    }
}
