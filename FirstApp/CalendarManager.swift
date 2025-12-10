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
        // iOS 17+ uses requestFullAccessToEvents()
        if #available(iOS 17.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                checkAuthorization()
                return granted
            } catch {
                lastError = error.localizedDescription
                return false
            }
        } else {
            // Fallback for iOS 16 and earlier
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    Task { @MainActor in
                        if let error = error {
                            self.lastError = error.localizedDescription
                        }
                        self.checkAuthorization()
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
    
    // MARK: - Check if authorized
    private var isAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
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
        if !isAuthorized {
            let granted = await requestAccess()
            if !granted {
                return .failure(.accessDenied)
            }
        }
        
        // Verify we have a default calendar
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            return .failure(.noDefaultCalendar)
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.notes = notes
        event.startDate = startDate
        event.endDate = endDate ?? startDate.addingTimeInterval(3600) // Default 1 hour
        event.location = location
        event.calendar = calendar
        
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
    
    // MARK: - Delete Event
    
    func deleteEvent(identifier: String) async -> Result<Void, CalendarError> {
        // Check authorization
        if !isAuthorized {
            let granted = await requestAccess()
            if !granted {
                return .failure(.accessDenied)
            }
        }
        
        // Find the event by identifier
        guard let event = eventStore.event(withIdentifier: identifier) else {
            // Event not found - maybe already deleted or identifier invalid
            // Return success since the goal (event not existing) is achieved
            return .success(())
        }
        
        do {
            try eventStore.remove(event, span: .thisEvent)
            return .success(())
        } catch {
            return .failure(.deleteFailed(error.localizedDescription))
        }
    }
}

// MARK: - Calendar Errors

enum CalendarError: Error, LocalizedError {
    case accessDenied
    case saveFailed(String)
    case deleteFailed(String)
    case noDefaultCalendar
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access was denied. Please enable in Settings."
        case .saveFailed(let reason):
            return "Failed to save event: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete event: \(reason)"
        case .noDefaultCalendar:
            return "No default calendar available."
        }
    }
}