// CalendarManager.swift
// Voice Mind Calendar Integration

import EventKit
import Foundation

@MainActor
class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var lastError: String?
    
    private init() {
        checkAuthorization()
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            }
            return granted
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
            }
            return false
        }
    }
    
    // MARK: - Add Event
    
    func addEvent(
        title: String,
        notes: String?,
        startDate: Date,
        endDate: Date? = nil,
        location: String? = nil
    ) async -> Result<String, CalendarError> {
        
        // Check authorization first
        guard authorizationStatus == .fullAccess || authorizationStatus == .authorized else {
            let granted = await requestAccess()
            if !granted {
                return .failure(.accessDenied)
            }
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.notes = notes
        event.startDate = startDate
        event.endDate = endDate ?? startDate.addingTimeInterval(3600) // Default 1 hour
        event.location = location
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Add an alert 15 minutes before
        let alarm = EKAlarm(relativeOffset: -15 * 60)
        event.addAlarm(alarm)
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return .success(event.eventIdentifier)
        } catch {
            return .failure(.saveFailed(error.localizedDescription))
        }
    }
}

// MARK: - Calendar Errors

enum CalendarError: Error, LocalizedError {
    case accessDenied
    case saveFailed(String)
    case noDefaultCalendar
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access was denied. Please enable in Settings."
        case .saveFailed(let reason):
            return "Failed to save event: \(reason)"
        case .noDefaultCalendar:
            return "No default calendar available."
        }
    }
}
