import SwiftUI

struct AuthView: View {
    @State private var showLogin = true
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            VStack(spacing: themeManager.theme.spacingMedium) {
                Picker("", selection: $showLogin) {
                    Text("Login").tag(true)
                    Text("Register").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(themeManager.theme.paddingMedium)

                if showLogin {
                    LoginView()
                        .background(Color.clear)
                } else {
                    RegisterView()
                        .background(Color.clear)
                }

                Spacer()
            }
            .padding(.horizontal, themeManager.theme.paddingMedium)
            .background(Color.clear)
            .navigationTitle(showLogin ? "Login" : "Register")
            .navigationBarTitleDisplayMode(.inline)
        }
        .background(Color.clear)
        .ignoresSafeArea(edges: .bottom)
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environmentObject(AuthViewModel())
            .environmentObject(ThemeManager())
    }
}

