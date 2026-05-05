import AVFoundation
import SwiftUI
import UIKit

struct QRScannerView: UIViewRepresentable {
    var onCodeDetected: (String) -> Void

    func makeUIView(context: Context) -> ScannerPreviewView {
        let view = ScannerPreviewView()
        context.coordinator.configure(in: view)
        return view
    }

    func updateUIView(_ uiView: ScannerPreviewView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeDetected: onCodeDetected)
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let onCodeDetected: (String) -> Void
        private let session = AVCaptureSession()
        private weak var metadataOutput: AVCaptureMetadataOutput?
        private var detectedPayloads = Set<String>()

        init(onCodeDetected: @escaping (String) -> Void) {
            self.onCodeDetected = onCodeDetected
        }

        func configure(in view: ScannerPreviewView) {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                setupSession(in: view)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self, weak view] granted in
                    guard granted, let self, let view else { return }
                    DispatchQueue.main.async {
                        self.setupSession(in: view)
                    }
                }
            default:
                return
            }
        }

        private func setupSession(in view: ScannerPreviewView) {
            guard session.inputs.isEmpty else { return }
            session.sessionPreset = .high

            guard let device = Self.preferredBackCamera(),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                return
            }
            configureFocus(for: device)
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]
            metadataOutput = output

            view.previewLayer.session = session
            view.previewLayer.videoGravity = .resizeAspectFill
            view.onLayout = { [weak self, weak view] in
                guard let self, let view, let metadataOutput = self.metadataOutput else { return }
                let guideRect = view.bounds.insetBy(dx: view.bounds.width * 0.16, dy: view.bounds.height * 0.24)
                metadataOutput.rectOfInterest = view.previewLayer.metadataOutputRectConverted(fromLayerRect: guideRect)
            }

            DispatchQueue.global(qos: .userInitiated).async { [session] in
                session.startRunning()
            }
        }

        private static func preferredBackCamera() -> AVCaptureDevice? {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .back
            )
            return discovery.devices.first ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        }

        private func configureFocus(for device: AVCaptureDevice) {
            var didLock = false
            do {
                try device.lockForConfiguration()
                didLock = true

                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                } else if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }

                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                }

                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }

                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
                }

                let zoom = min(max(device.minAvailableVideoZoomFactor, 1.35), device.maxAvailableVideoZoomFactor)
                device.videoZoomFactor = zoom

                device.unlockForConfiguration()
            } catch {
                if didLock {
                    device.unlockForConfiguration()
                }
            }
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                  let payload = object.stringValue,
                  !detectedPayloads.contains(payload) else {
                return
            }

            detectedPayloads.insert(payload)
            onCodeDetected(payload)
        }
    }
}

final class ScannerPreviewView: UIView {
    var onLayout: (() -> Void)?

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}
