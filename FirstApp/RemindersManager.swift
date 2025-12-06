// RemindersManager.swift
// Apple Reminders Integration

import EventKit
import Foundation

@MainActor
class RemindersManager: ObservableObject {
    static let shared = RemindersManager()
    
    private let eventStore = EKEventStore()
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var lastError: String?
    
    private init() {
        checkAuthorization()
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    }
    
    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToReminders()
                checkAuthorization()
                return granted
            } catch {
                lastError = error.localizedDescription
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, error in
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
    
    private var isAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }
    
    // MARK: - Add Reminder
    
    func addReminder(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil
    ) async -> Result<String, ReminderError> {
        
        // Check authorization
        if !isAuthorized {
            let granted = await requestAccess()
            if !granted {
                return .failure(.accessDenied)
            }
        }
        
        // Get default reminders list
        guard let calendar = eventStore.defaultCalendarForNewReminders() else {
            return .failure(.noDefaultList)
        }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = calendar
        
        // Set due date if provided
        if let dueDate = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
            
            // Add alarm 15 minutes before
            let alarm = EKAlarm(relativeOffset: -15 * 60)
            reminder.addAlarm(alarm)
        }
        
        do {
            try eventStore.save(reminder, commit: true)
            return .success(reminder.calendarItemIdentifier)
        } catch {
            return .failure(.saveFailed(error.localizedDescription))
        }
    }
}

// MARK: - Reminder Errors

enum ReminderError: Error, LocalizedError {
    case accessDenied
    case saveFailed(String)
    case noDefaultList
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Reminders access denied. Enable in Settings."
        case .saveFailed(let reason):
            return "Failed to save: \(reason)"
        case .noDefaultList:
            return "No default reminders list available."
        }
    }
}
