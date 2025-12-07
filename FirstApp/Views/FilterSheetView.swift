// FilterSheetView.swift
// Advanced filtering options for the Library

import SwiftUI

// MARK: - Date Filter Options
enum DateFilter: String, CaseIterable, Identifiable {
    case all = "All Time"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "infinity"
        case .today: return "sun.max"
        case .thisWeek: return "calendar.badge.clock"
        case .thisMonth: return "calendar"
        }
    }
}

// MARK: - Filter State
class FilterState: ObservableObject {
    @Published var dateFilter: DateFilter = .all
    @Published var selectedCategories: Set<String> = []
    @Published var selectedPriorities: Set<String> = []
    @Published var selectedSentiment: String? = nil
    @Published var selectedKeywords: Set<String> = []
    @Published var showCompletedTasks: Bool = true
    @Published var onlyWithAudio: Bool = false
    
    var hasActiveFilters: Bool {
        dateFilter != .all ||
        !selectedCategories.isEmpty ||
        !selectedPriorities.isEmpty ||
        selectedSentiment != nil ||
        !selectedKeywords.isEmpty ||
        !showCompletedTasks ||
        onlyWithAudio
    }
    
    var activeFilterCount: Int {
        var count = 0
        if dateFilter != .all { count += 1 }
        count += selectedCategories.count
        count += selectedPriorities.count
        if selectedSentiment != nil { count += 1 }
        count += selectedKeywords.count
        if !showCompletedTasks { count += 1 }
        if onlyWithAudio { count += 1 }
        return count
    }
    
    func clearAll() {
        dateFilter = .all
        selectedCategories = []
        selectedPriorities = []
        selectedSentiment = nil
        selectedKeywords = []
        showCompletedTasks = true
        onlyWithAudio = false
    }
}

// MARK: - Filter Sheet View
struct FilterSheetView: View {
    @ObservedObject var filterState: FilterState
    @Environment(\.dismiss) private var dismiss
    
    let availableKeywords: [String]
    let availableCategories = ["Work", "Personal", "Health", "Finance", "Idea"]
    let availablePriorities = ["High", "Medium", "Low"]
    let availableSentiments = ["Positive", "Neutral", "Negative"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Date Filter
                    dateFilterSection
                    
                    Divider()
                    
                    // Category Filter
                    categorySection
                    
                    Divider()
                    
                    // Priority Filter
                    prioritySection
                    
                    Divider()
                    
                    // Sentiment Filter
                    sentimentSection
                    
                    Divider()
                    
                    // Keywords Filter
                    if !availableKeywords.isEmpty {
                        keywordsSection
                        Divider()
                    }
                    
                    // Toggle Filters
                    toggleSection
                    
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear All") {
                        filterState.clearAll()
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Date Filter Section
    private var dateFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Date Created", systemImage: "calendar")
                .font(.headline)
            
            HStack(spacing: 8) {
                ForEach(DateFilter.allCases) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: filterState.dateFilter == filter
                    ) {
                        filterState.dateFilter = filter
                    }
                }
            }
        }
    }
    
    // MARK: - Category Section
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Category", systemImage: "folder")
                .font(.headline)
            
            FlowLayout(spacing: 8) {
                ForEach(availableCategories, id: \.self) { category in
                    FilterChip(
                        title: category,
                        isSelected: filterState.selectedCategories.contains(category)
                    ) {
                        toggleSelection(category, in: &filterState.selectedCategories)
                    }
                }
            }
        }
    }
    
    // MARK: - Priority Section
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Priority", systemImage: "exclamationmark.triangle")
                .font(.headline)
            
            HStack(spacing: 8) {
                ForEach(availablePriorities, id: \.self) { priority in
                    FilterChip(
                        title: priority,
                        color: priorityColor(priority),
                        isSelected: filterState.selectedPriorities.contains(priority)
                    ) {
                        toggleSelection(priority, in: &filterState.selectedPriorities)
                    }
                }
            }
        }
    }
    
    // MARK: - Sentiment Section
    private var sentimentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sentiment", systemImage: "face.smiling")
                .font(.headline)
            
            HStack(spacing: 8) {
                ForEach(availableSentiments, id: \.self) { sentiment in
                    FilterChip(
                        title: sentiment,
                        icon: sentimentIcon(sentiment),
                        color: sentimentColor(sentiment),
                        isSelected: filterState.selectedSentiment == sentiment
                    ) {
                        if filterState.selectedSentiment == sentiment {
                            filterState.selectedSentiment = nil
                        } else {
                            filterState.selectedSentiment = sentiment
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Keywords Section
    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Keywords", systemImage: "tag")
                .font(.headline)
            
            FlowLayout(spacing: 8) {
                ForEach(availableKeywords.prefix(20), id: \.self) { keyword in
                    FilterChip(
                        title: "#\(keyword)",
                        isSelected: filterState.selectedKeywords.contains(keyword)
                    ) {
                        toggleSelection(keyword, in: &filterState.selectedKeywords)
                    }
                }
            }
        }
    }
    
    // MARK: - Toggle Section
    private var toggleSection: some View {
        VStack(spacing: 16) {
            Toggle(isOn: $filterState.showCompletedTasks) {
                Label("Show Completed Tasks", systemImage: "checkmark.circle")
            }
            
            Toggle(isOn: $filterState.onlyWithAudio) {
                Label("Only Notes with Audio", systemImage: "waveform")
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    // MARK: - Helpers
    private func toggleSelection(_ item: String, in set: inout Set<String>) {
        if set.contains(item) {
            set.remove(item)
        } else {
            set.insert(item)
        }
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        default: return .gray
        }
    }
    
    private func sentimentIcon(_ sentiment: String) -> String {
        switch sentiment.lowercased() {
        case "positive": return "face.smiling"
        case "negative": return "face.dashed"
        default: return "minus.circle"
        }
    }
    
    private func sentimentColor(_ sentiment: String) -> Color {
        switch sentiment.lowercased() {
        case "positive": return .green
        case "negative": return .red
        default: return .gray
        }
    }
}

// MARK: - Filter Chip Component
struct FilterChip: View {
    let title: String
    var icon: String? = nil
    var color: Color = Theme.primary
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color.clear)
            .foregroundStyle(isSelected ? .white : color)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color, lineWidth: 1)
            )
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}
