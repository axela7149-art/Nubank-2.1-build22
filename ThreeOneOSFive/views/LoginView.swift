import SwiftUI
import UIKit

struct LoginView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @FocusState private var isKeyFieldFocused: Bool
    @State private var contentVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var titleColorPhase = 0.0

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer(minLength: 80)

                    VStack(spacing: 0) {
                        VStack(spacing: 12) {
                            Text("MACIELFILZA")
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    AngularGradient(
                                        colors: [.white, .cyan, .blue, .purple, .pink, .white],
                                        center: .center,
                                        angle: .degrees(titleColorPhase * 360)
                                    )
                                )
                                .onAppear {
                                    guard !reduceMotion else { return }
                                    withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                                        titleColorPhase = 1
                                    }
                                }

                            Text("EXTERNAL FEITO TOTALMENTE POR MIM MACIEL\nQUALQUER CÓPIA É FAKE E NÃO TERÁ ATUALIZAÇÕES,\nPRODUTO 100% SAFE**")
                                .font(.system(size: 13.5, weight: .medium))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .foregroundStyle(Color.white.opacity(0.86))
                                .padding(.horizontal, 8)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 22)
                        .padding(.bottom, 18)

                        SecureField("Digite sua key", text: $viewModel.enteredKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isKeyFieldFocused)
                            .submitLabel(.go)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.white)
                            .tint(Color.blue)
                            .padding(.horizontal, 15)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        isKeyFieldFocused ? Color.blue.opacity(0.9) : Color.white.opacity(0.28),
                                        lineWidth: 1
                                    )
                            }
                            .padding(.horizontal, 24)
                            .onSubmit { submit() }

                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 1)
                            .padding(.top, 14)

                        HStack(spacing: 0) {
                            Button {
                                submit()
                            } label: {
                                Text("Injetar")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.blue)
                                .frame(maxWidth: .infinity, minHeight: 52)
                            }
                            .disabled(viewModel.isLoading || viewModel.isRevalidating)
                            .buttonStyle(LoginActionButtonStyle())

                            Rectangle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 1, height: 52)

                            Button {
                                viewModel.enteredKey = ""
                                viewModel.showError = false
                                isKeyFieldFocused = false
                            } label: {
                                Text("Cancelar")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.red.opacity(0.92))
                                    .frame(maxWidth: .infinity, minHeight: 52)
                            }
                            .buttonStyle(LoginActionButtonStyle())
                        }
                    }
                    .background(Color(red: 0.105, green: 0.105, blue: 0.115), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.65), radius: 28, y: 12)
                    .frame(maxWidth: 320)

                    if viewModel.isLoading || viewModel.isRevalidating {
                        VStack(spacing: 10) {
                            ProgressView()
                                .tint(Color.white.opacity(0.72))
                                .scaleEffect(1.0)
                            Text(viewModel.isRevalidating ? "Revalidando sua licença..." : "Validando sua key...")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.52))
                        }
                        .padding(.top, 4)
                    }

                    if viewModel.showError {
                        Text(viewModel.errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 26)
                    }

                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 24)
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

private struct LoginActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1.0)
            .background(configuration.isPressed ? Color.white.opacity(0.06) : Color.clear)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
