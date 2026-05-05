import SwiftUI
import UIKit

// MARK: - Camera Picker Wrapper

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Shelf Camera Flow

struct ShelfCameraView: View {
    let store: Store
    let inventory: [TruckInventoryItem]
    @Environment(\.dismiss) private var dismiss

    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var isAnalyzing = false
    @State private var result: ShelfAnalysisResult?
    @State private var errorMessage: String?

    private let service = ShelfAnalysisService()

    var body: some View {
        NavigationStack {
            Group {
                if let result {
                    ShelfRecommendationView(result: result, storeName: store.name) {
                        self.result = nil
                        capturedImage = nil
                        showCamera = true
                    }
                } else if isAnalyzing {
                    analyzingView
                } else if let image = capturedImage {
                    previewView(image)
                } else {
                    promptView
                }
            }
            .navigationTitle("Análisis de Anaquel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(AppTheme.bimboRed)
                }
            }
        }
        .onAppear { showCamera = true }
        .fullScreenCover(isPresented: $showCamera) {
            ImagePickerView(image: $capturedImage)
                .ignoresSafeArea()
        }
    }

    // MARK: - States

    private var promptView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(AppTheme.deepBlue)
            Text("Fotografía el anaquel")
                .font(.title2.weight(.bold))
            Text("La IA detectará huecos y recomendará el acomodo óptimo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Abrir cámara") { showCamera = true }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.bimboRed)
            Spacer()
        }
    }

    private func previewView(_ image: UIImage) -> some View {
        VStack(spacing: 20) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
                .padding(.top)

            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            HStack(spacing: 14) {
                Button {
                    capturedImage = nil
                    errorMessage = nil
                    showCamera = true
                } label: {
                    Label("Repetir", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button {
                    analyzeShelf(image)
                } label: {
                    Label("Analizar anaquel", systemImage: "brain")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.bimboRed)
            }
            .padding(.bottom)
        }
    }

    private var analyzingView: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(AppTheme.bimboRed.opacity(0.15), lineWidth: 6)
                    .frame(width: 90, height: 90)
                ProgressView()
                    .scaleEffect(1.6)
                    .tint(AppTheme.bimboRed)
            }
            VStack(spacing: 6) {
                Text("Analizando anaquel...")
                    .font(.headline.weight(.bold))
                Text("La IA está detectando huecos y acomodo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Analysis

    private func analyzeShelf(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.72) else { return }
        isAnalyzing = true
        errorMessage = nil
        Task {
            do {
                let r = try await service.analyzeShelf(imageData: data, store: store, inventory: inventory)
                await MainActor.run {
                    result = r
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isAnalyzing = false
                }
            }
        }
    }
}
