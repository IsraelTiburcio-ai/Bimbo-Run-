import SwiftUI

struct SplashView: View {
    @State private var truckX: CGFloat     = UIScreen.main.bounds.width + 300
    @State private var logoScale: CGFloat  = 0.78
    @State private var logoOpacity: Double = 0
    @State private var isActive: Bool      = false

    var body: some View {
        if isActive {
            MainTabView()
                .transition(.opacity)
        } else {
            splashContent
                .transition(.opacity)
        }
    }

    private var splashContent: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Fondo
                LinearGradient(
                    colors: [Color(white: 0.97), Color(white: 0.93)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                // Barra superior azul
                AppTheme.deepBlue
                    .frame(maxWidth: .infinity).frame(height: 6)
                    .ignoresSafeArea(edges: .top)
                    .frame(maxHeight: .infinity, alignment: .top)

                // Logo desde Assets
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 230)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .position(x: w / 2, y: h * 0.40)

                // Carretera
                Color(white: 0.76)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .position(x: w / 2, y: h * 0.795)

                // Línea discontinua central
                Path { p in
                    p.move(to:    CGPoint(x: 0, y: h * 0.795))
                    p.addLine(to: CGPoint(x: w, y: h * 0.795))
                }
                .stroke(Color.white,
                        style: StrokeStyle(lineWidth: 2.5, dash: [20, 16]))

                // Borde superior carretera
                Color(white: 0.60)
                    .frame(maxWidth: .infinity).frame(height: 2)
                    .position(x: w / 2, y: h * 0.767)

                // Camión desde Assets — entra de derecha a izquierda
                Image("CamionBimbo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 260)
                    .scaleEffect(x: -1, y: 1) // flip horizontal para que mire hacia la izquierda
                    .position(x: truckX, y: h * 0.768)

                // Barra inferior azul
                AppTheme.deepBlue
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .ignoresSafeArea(edges: .bottom)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                Text("Alimentamos un mundo mejor.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.90))
                    .position(x: w / 2, y: h - 32)
            }
        }
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        // Logo: fade + scale spring
        withAnimation(.spring(response: 0.85, dampingFraction: 0.68).delay(0.15)) {
            logoScale   = 1.0
            logoOpacity = 1.0
        }

        // Camión entra de derecha a izquierda
        withAnimation(.easeInOut(duration: 2.5).delay(0.35)) {
            truckX = -300
        }

        // Pasar a la app principal al terminar el splash
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            withAnimation(.easeInOut(duration: 0.45)) {
                isActive = true
            }
        }
    }
}

#Preview {
    SplashView()
}
