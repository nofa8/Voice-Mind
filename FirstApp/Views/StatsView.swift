// StatsView.swift
// Statistics Dashboard - Quantified Self Insights

import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query private var notes: [VoiceNote]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 1. Overview Cards
                    overviewCards
                    
                    // 2. Mood Breakdown (Pie Chart)
                    if !notes.isEmpty {
                        sentimentChart
                        
                        // 3. Focus Areas (Bar Chart)
                        categoryChart
                        
                        // 4. Weekly Activity
                        weeklyActivityChart
                        
                        // 5. Type Distribution
                        typeDistributionChart
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Insights")
        }
    }
    
    // MARK: - Overview Cards
    
    private var overviewCards: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Notes",
                    value: "\(notes.count)",
                    icon: "tray.full.fill",
                    color: Theme.primary
                )
                StatCard(
                    title: "Tasks",
                    value: "\(tasksCount)",
                    icon: "checklist",
                    color: .green
                )
            }
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Events",
                    value: "\(eventsCount)",
                    icon: "calendar",
                    color: .blue
                )
                StatCard(
                    title: "Completed",
                    value: "\(completedCount)",
                    icon: "checkmark.circle.fill",
                    color: .mint
                )
            }
        }
    }
    
    // MARK: - Sentiment Pie Chart
    
    private var sentimentChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "face.smiling")
                    .foregroundStyle(Theme.primary)
                Text("Mood Breakdown")
                    .font(.headline)
            }
            
            if sentimentData.isEmpty {
                Text("No sentiment data yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(sentimentData, id: \.key) { item in
                    SectorMark(
                        angle: .value("Count", item.value),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Sentiment", item.key))
                    .cornerRadius(4)
                }
                .frame(height: 200)
                .chartForegroundStyleScale([
                    "Positive": Color.green,
                    "Neutral": Color.blue,
                    "Negative": Color.red,
                    "Unknown": Color.secondary
                ])
                .chartLegend(position: .bottom)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    // MARK: - Category Bar Chart
    
    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Theme.primary)
                Text("Focus Areas")
                    .font(.headline)
            }
            
            if categoryData.isEmpty {
                Text("No category data yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(categoryData, id: \.key) { item in
                    BarMark(
                        x: .value("Count", item.value),
                        y: .value("Category", item.key)
                    )
                    .foregroundStyle(Theme.primary.gradient)
                    .cornerRadius(4)
                }
                .frame(height: CGFloat(categoryData.count * 40 + 20))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5))
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    // MARK: - Weekly Activity Chart
    
    private var weeklyActivityChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(Theme.primary)
                Text("This Week")
                    .font(.headline)
            }
            
            Chart(weeklyData, id: \.day) { item in
                BarMark(
                    x: .value("Day", item.day),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(Theme.accent.gradient)
                .cornerRadius(4)
            }
            .frame(height: 150)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    // MARK: - Type Distribution
    
    private var typeDistributionChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "square.stack.3d.up")
                    .foregroundStyle(Theme.primary)
                Text("Note Types")
                    .font(.headline)
            }
            
            HStack(spacing: 12) {
                TypeStatBadge(type: "Notes", count: notesOnlyCount, color: .orange, icon: "doc.text.fill")
                TypeStatBadge(type: "Tasks", count: tasksCount, color: .green, icon: "checklist")
                TypeStatBadge(type: "Events", count: eventsCount, color: .blue, icon: "calendar")
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    // MARK: - Computed Data
    
    var tasksCount: Int { notes.filter { $0.noteType == .task }.count }
    var eventsCount: Int { notes.filter { $0.noteType == .event }.count }
    var notesOnlyCount: Int { notes.filter { $0.noteType == .note }.count }
    var completedCount: Int { notes.filter { $0.isCompleted }.count }
    
    var sentimentData: [(key: String, value: Int)] {
        let grouped = Dictionary(grouping: notes) { $0.sentiment ?? "Unknown" }
        return grouped.map { ($0.key, $0.value.count) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }
    
    var categoryData: [(key: String, value: Int)] {
        let grouped = Dictionary(grouping: notes) { $0.category ?? "Uncategorized" }
        return grouped.map { ($0.key, $0.value.count) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }
    
    var weeklyData: [(day: String, count: Int)] {
        let calendar = Calendar.current
        let today = Date()
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        
        // Get start of week
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return []
        }
        
        return (0..<7).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return (days[offset], 0)
            }
            let dayNotes = notes.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            let weekday = calendar.component(.weekday, from: date) - 1
            return (days[weekday], dayNotes.count)
        }
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Type Stat Badge

struct TypeStatBadge: View {
    let type: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(type)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    StatsView()
        .modelContainer(for: VoiceNote.self)
}
