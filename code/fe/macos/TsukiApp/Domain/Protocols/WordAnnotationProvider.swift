import Foundation

protocol WordAnnotationProvider {
    func annotate(result: TranslationResult) -> TranslationResult
}
