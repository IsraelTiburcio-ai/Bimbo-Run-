import SwiftUI

// MARK: - Wave Shape (replica de las ondas del logo BR)
struct FlagWave: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: 0, y: h * 0.65))
        p.addCurve(
            to:       CGPoint(x: w,        y: h * 0.10),
            control1: CGPoint(x: w * 0.30, y: h * 1.15),
            control2: CGPoint(x: w * 0.65, y: h * -0.25)
        )
        return p
    }
}

// MARK: - Doble onda (arriba y abajo del logo)
struct DoubleFlagWave: View {
    var flipped: Bool = false

    var body: some View {
        VStack(spacing: 7) {
            FlagWave()
                .stroke(AppTheme.deepBlue,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .frame(width: 210, height: 28)
            FlagWave()
                .stroke(AppTheme.deepBlue,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .frame(width: 210, height: 28)
        }
        .scaleEffect(y: flipped ? -1 : 1)
    }
}

// MARK: - Logo BR
struct BRLogoView: View {
    var body: some View {
        VStack(spacing: 2) {
            DoubleFlagWave()

            Text("BR")
                .font(.system(size: 108, weight: .heavy, design: .default))
                .foregroundColor(AppTheme.bimboRed)
                .kerning(-3)
                .padding(.vertical, -12)

            DoubleFlagWave(flipped: true)
        }
    }
}

// MARK: - Rueda del camión
struct SplashTruckWheel: View {
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            Circle().fill(Color(white: 0.12)).frame(width: size, height: size)
            Circle().fill(Color(white: 0.45)).frame(width: size * 0.42, height: size * 0.42)
            Circle().fill(Color(white: 0.12)).frame(width: size * 0.18, height: size * 0.18)
        }
    }
}

// MARK: - Camión de reparto
struct SplashTruck: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {

            // Caja de carga
            RoundedRectangle(cornerRadius: 6)
                .fill(AppTheme.bimboRed)
                .frame(width: 148, height: 60)
                .offset(x: 52, y: -18)

            // Línea de onda en la caja
            FlagWave()
                .stroke(Color.white.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: 105, height: 18)
                .offset(x: 70, y: -26)

            // Texto BR en la caja
            Text("BR")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .offset(x: 112, y: -38)

            // Línea divisoria trasera (detalle puerta)
            Rectangle()
                .fill(Color.white.opacity(0.30))
                .frame(width: 1.5, height: 54)
                .offset(x: 60, y: -18)

            // Cabina
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.deepBlue)
                .frame(width: 62, height: 52)
                .offset(x: 0, y: -18)

            // Parabrisas
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(white: 0.88).opacity(0.9))
                .frame(width: 34, height: 26)
                .offset(x: 10, y: -32)

            // Faro delantero
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.yellow.opacity(0.95))
                .frame(width: 9, height: 7)
                .offset(x: 1, y: -20)

            // Defensa frontal
            Rectangle()
                .fill(Color.gray.opacity(0.50))
                .frame(width: 7, height: 14)
                .offset(x: -4, y: -16)

            // Ruedas
            SplashTruckWheel().offset(x: 16,  y: 0)
            SplashTruckWheel().offset(x: 94,  y: 0)
            SplashTruckWheel().offset(x: 170, y: 0)
        }
        .frame(width: 215, height: 86)
    }
}

// MARK: - Líneas de velocidad
struct SpeedLines: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(AppTheme.deepBlue.opacity(0.15 - Double(i) * 0.04))
                    .frame(width: CGFloat(60 - i * 12), height: 2.5)
            }
        }
    }
}

// MARK: - Splash Screen
struct SplashView: View {
    @State private var truckX: CGFloat      = -260
    @State private var logoScale: CGFloat   = 0.78
    @State private var logoOpacity: Double  = 0
    @State private var speedOpacity: Double = 0
    @State private var isActive: Bool       = false

    var body: some View {
        if isActive {
            MainTabView()
                .transition(.opacity)
        } else {
            splashContent
                .transition(.opacity)
        }
    }

    // MARK: Contenido del splash
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

                // Logo BR
                BRLogoView()
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .position(x: w / 2, y: h * 0.38)

                // Tagline
                Text("App del Distribuidor")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.deepBlue.opacity(0.65))
                    .opacity(logoOpacity)
                    .position(x: w / 2, y: h * 0.62)

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

                // Líneas de velocidad (delante del camión)
                SpeedLines()
                    .opacity(speedOpacity)
                    .position(x: truckX - 60, y: h * 0.777)

                // Camión
                SplashTruck()
                    .position(x: truckX, y: h * 0.773)

                // Barra inferior azul
                AppTheme.deepBlue
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .ignoresSafeArea(edges: .bottom)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                Text("Distribución  •  Rutas  •  Pedidos")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .position(x: w / 2, y: h - 32)
            }
        }
        .onAppear { startAnimations() }
    }

    // MARK: Animaciones
    private func startAnimations() {
        // Logo: fade + scale spring
        withAnimation(.spring(response: 0.85, dampingFraction: 0.68).delay(0.15)) {
            logoScale   = 1.0
            logoOpacity = 1.0
        }

        // Líneas de velocidad aparecen con el camión
        withAnimation(.easeIn(duration: 0.3).delay(0.35)) {
            speedOpacity = 1
        }

        // Camión cruza la pantalla de izquierda a derecha
        withAnimation(.easeInOut(duration: 2.5).delay(0.35)) {
            truckX = UIScreen.main.bounds.width + 260
        }

        // Líneas de velocidad se desvanecen al final
        withAnimation(.easeOut(duration: 0.5).delay(2.4)) {
            speedOpacity = 0
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
