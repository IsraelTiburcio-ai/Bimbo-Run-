import SwiftUI

// MARK: - Brand Colors
extension Color {
    static let brRed  = Color(red: 0.847, green: 0.286, blue: 0.161) // #D84929
    static let brNavy = Color(red: 0.110, green: 0.235, blue: 0.533) // #1C3C88
}

// MARK: - Wave Line Shape (replica of logo waves)
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

// MARK: - Double Wave Banner
struct DoubleFlagWave: View {
    var flipped: Bool = false

    var body: some View {
        VStack(spacing: 7) {
            FlagWave()
                .stroke(Color.brNavy,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .frame(width: 210, height: 28)
            FlagWave()
                .stroke(Color.brNavy,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .frame(width: 210, height: 28)
        }
        .scaleEffect(y: flipped ? -1 : 1)
    }
}

// MARK: - BR Logo
struct BRLogo: View {
    var body: some View {
        VStack(spacing: 2) {
            DoubleFlagWave()

            Text("BR")
                .font(.system(size: 108, weight: .heavy, design: .default))
                .foregroundColor(Color.brRed)
                .kerning(-3)
                .padding(.vertical, -12)

            DoubleFlagWave(flipped: true)
        }
    }
}

// MARK: - Wheel
struct TruckWheel: View {
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            Circle().fill(Color(white: 0.12)).frame(width: size, height: size)
            Circle().fill(Color(white: 0.45)).frame(width: size * 0.42, height: size * 0.42)
            Circle().fill(Color(white: 0.12)).frame(width: size * 0.18, height: size * 0.18)
        }
    }
}

// MARK: - Delivery Truck
struct DeliveryTruck: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {

            // ── Cargo box ──────────────────────────────────────
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.brRed)
                .frame(width: 148, height: 60)
                .offset(x: 52, y: -18)

            // Wave stripe on box side
            FlagWave()
                .stroke(Color.white.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: 105, height: 18)
                .offset(x: 70, y: -26)

            // BR on box
            Text("BR")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .offset(x: 112, y: -38)

            // Vertical divider line (rear door detail)
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 1.5, height: 54)
                .offset(x: 60, y: -18)

            // ── Cab ────────────────────────────────────────────
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.brNavy)
                .frame(width: 62, height: 52)
                .offset(x: 0, y: -18)

            // Windshield
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(white: 0.88).opacity(0.9))
                .frame(width: 34, height: 26)
                .offset(x: 10, y: -32)

            // Headlight
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.yellow.opacity(0.95))
                .frame(width: 9, height: 7)
                .offset(x: 1, y: -20)

            // Front bumper / grille
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 7, height: 16)
                .offset(x: -4, y: -18)

            // ── Wheels ─────────────────────────────────────────
            TruckWheel().offset(x: 16,  y: 0)
            TruckWheel().offset(x: 94,  y: 0)
            TruckWheel().offset(x: 170, y: 0)

            // Axle lines
            Rectangle().fill(Color(white: 0.3)).frame(width: 2, height: 14).offset(x: 28, y: -7)
            Rectangle().fill(Color(white: 0.3)).frame(width: 2, height: 14).offset(x: 106, y: -7)
            Rectangle().fill(Color(white: 0.3)).frame(width: 2, height: 14).offset(x: 182, y: -7)
        }
        .frame(width: 215, height: 86)
    }
}

// MARK: - Speed Lines (motion effect)
struct SpeedLines: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Color.brNavy.opacity(0.15 - Double(i) * 0.04))
                    .frame(width: CGFloat(60 - i * 12), height: 2.5)
            }
        }
    }
}

// MARK: - Splash Screen
struct SplashView: View {
    @State private var truckX: CGFloat        = -260
    @State private var logoScale: CGFloat     = 0.78
    @State private var logoOpacity: Double    = 0
    @State private var speedOpacity: Double   = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {

                // ── Background ─────────────────────────────────
                LinearGradient(
                    colors: [Color(white: 0.97), Color(white: 0.93)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                // Top accent bar
                Color.brNavy
                    .frame(maxWidth: .infinity).frame(height: 6)
                    .ignoresSafeArea(edges: .top)
                    .frame(maxHeight: .infinity, alignment: .top)

                // ── Logo ───────────────────────────────────────
                BRLogo()
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .position(x: w / 2, y: h * 0.38)

                // Tagline under logo
                Text("App del Distribuidor")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.brNavy.opacity(0.7))
                    .opacity(logoOpacity)
                    .position(x: w / 2, y: h * 0.62)

                // ── Road ───────────────────────────────────────
                Color(white: 0.76)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .position(x: w / 2, y: h * 0.795)

                // Road center dashes
                Path { p in
                    p.move(to:    CGPoint(x: 0, y: h * 0.795))
                    p.addLine(to: CGPoint(x: w, y: h * 0.795))
                }
                .stroke(Color.white,
                        style: StrokeStyle(lineWidth: 2.5, dash: [20, 16]))

                // Road top edge
                Color(white: 0.60)
                    .frame(maxWidth: .infinity).frame(height: 2)
                    .position(x: w / 2, y: h * 0.767)

                // ── Speed Lines ────────────────────────────────
                SpeedLines()
                    .opacity(speedOpacity)
                    .position(x: truckX - 60, y: h * 0.777)

                // ── Truck ──────────────────────────────────────
                DeliveryTruck()
                    .position(x: truckX, y: h * 0.773)

                // ── Bottom bar ─────────────────────────────────
                Color.brNavy
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .ignoresSafeArea(edges: .bottom)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                Text("Distribución • Rutas • Pedidos")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .position(x: w / 2, y: h - 32)
            }
        }
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        // Logo fade + scale in
        withAnimation(.spring(response: 0.85, dampingFraction: 0.68).delay(0.15)) {
            logoScale   = 1.0
            logoOpacity = 1.0
        }

        // Speed lines appear with truck
        withAnimation(.easeIn(duration: 0.3).delay(0.35)) {
            speedOpacity = 1
        }

        // Truck drives across screen
        withAnimation(.easeInOut(duration: 2.5).delay(0.35)) {
            truckX = UIScreen.main.bounds.width + 260
        }

        // Speed lines fade out near the end
        withAnimation(.easeOut(duration: 0.5).delay(2.4)) {
            speedOpacity = 0
        }
    }
}

// MARK: - Preview
#Preview {
    SplashView()
}
