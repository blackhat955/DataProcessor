import Foundation
import CoreML
import NaturalLanguage

enum AIAnalysisType: String, Sendable {
    case sentiment = "Sentiment Analysis"
    case entityRecognition = "Entity Extraction"
    case languageIdentification = "Language ID"
    case smartClassification = "Smart Type Detection"
}

struct AISuggestion: Identifiable, Sendable {
    let id = UUID()
    let type: AIAnalysisType
    let confidence: Double
    let reason: String
    let columnName: String
}

actor SmartSuggester {
    // Shared NLTagger instance (expensive to create)
    private let tagger = NLTagger(tagSchemes: [.sentimentScore, .nameType, .language])
    
    func analyze(profile: DatasetProfile, sampleRows: [Row]) async -> [AISuggestion] {
        var suggestions: [AISuggestion] = []
        
        for column in profile.columnProfiles {
            // Handle Numeric Columns for Smart Classification
            if column.type == .integer || column.type == .double {
                // If numeric but low cardinality, it's likely a Category (e.g. 0/1 for Sex, 1-5 for Rating)
                if column.cardinality == .low {
                    suggestions.append(AISuggestion(
                        type: .smartClassification,
                        confidence: 0.8,
                        reason: "Low unique count detected. This numeric column likely represents a Category.",
                        columnName: column.columnName
                    ))
                }
                continue
            }
            
            guard column.type == .string else { continue }
            
            // Collect sample values for this column
            let colIndex = profile.columnProfiles.firstIndex(where: { $0.columnName == column.columnName }) ?? -1
            guard colIndex >= 0 else { continue }
            
            let samples = sampleRows.compactMap { row -> String? in
                guard row.values.indices.contains(colIndex) else { return nil }
                if case .string(let s) = row.values[colIndex] { return s }
                return nil
            }.prefix(10) // Analyze first 10 non-empty values
            
            if samples.isEmpty { continue }
            
            // 1. Language Identification
            if let languageSuggestion = analyzeLanguage(samples: Array(samples), columnName: column.columnName) {
                suggestions.append(languageSuggestion)
            }
            
            // 2. Sentiment Analysis Potential
            // If text is long enough and likely English/text, suggest Sentiment
            let avgLength = Double(samples.reduce(0) { $0 + $1.count }) / Double(samples.count)
            if avgLength > 30 { // Arbitrary threshold for "sentence-like"
                suggestions.append(AISuggestion(
                    type: .sentiment,
                    confidence: 0.85,
                    reason: "Column contains long text suitable for sentiment analysis.",
                    columnName: column.columnName
                ))
            }
            
            // 3. Entity Recognition (People, Places, Orgs)
            if let entitySuggestion = analyzeEntities(samples: Array(samples), columnName: column.columnName) {
                suggestions.append(entitySuggestion)
            }
        }
        
        return suggestions
    }
    
    private func analyzeLanguage(samples: [String], columnName: String) -> AISuggestion? {
        let text = samples.joined(separator: " ")
        tagger.string = text
        
        if let language = tagger.dominantLanguage {
            return AISuggestion(
                type: .languageIdentification,
                confidence: 0.9,
                reason: "Detected dominant language: \(language.rawValue)",
                columnName: columnName
            )
        }
        return nil
    }
    
    private func analyzeEntities(samples: [String], columnName: String) -> AISuggestion? {
        // Simple heuristic: check if we find names/places in samples
        var personCount = 0
        var placeCount = 0
        var orgCount = 0
        
        for sample in samples {
            tagger.string = sample
            tagger.enumerateTags(in: sample.startIndex..<sample.endIndex, unit: .word, scheme: .nameType, options: [.omitPunctuation, .omitWhitespace]) { tag, _ in
                if let tag = tag {
                    switch tag {
                    case .personalName: personCount += 1
                    case .placeName: placeCount += 1
                    case .organizationName: orgCount += 1
                    default: break
                    }
                }
                return true
            }
        }
        
        if personCount > 3 {
            return AISuggestion(type: .entityRecognition, confidence: 0.8, reason: "Contains Personal Names", columnName: columnName)
        }
        if placeCount > 3 {
            return AISuggestion(type: .entityRecognition, confidence: 0.8, reason: "Contains Location Data", columnName: columnName)
        }
        if orgCount > 3 {
            return AISuggestion(type: .entityRecognition, confidence: 0.8, reason: "Contains Organization Names", columnName: columnName)
        }
        
        return nil
    }
}
