import Foundation

final class InstitutionDetector {
    private let signatureDetector: SignatureInstitutionDetector

    init(signatureDetector: SignatureInstitutionDetector = SignatureInstitutionDetector()) {
        self.signatureDetector = signatureDetector
    }

    func detect(from text: String) -> DocumentMetadata {
        signatureDetector.detect(from: text).metadata
    }

    func detectWithReasons(from text: String) -> InstitutionDetectionResult {
        signatureDetector.detect(from: text)
    }
}
