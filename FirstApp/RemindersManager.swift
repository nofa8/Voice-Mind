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
    
    // MARK: - Delete Reminder
    
    func deleteReminder(identifier: String) async -> Result<Void, ReminderError> {
        // Check authorization
        if !isAuthorized {
            let granted = await requestAccess()
            if !granted {
                return .failure(.accessDenied)
            }
        }
        
        // Find the reminder by identifier
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            // Reminder not found - maybe already deleted or identifier invalid
            // Return success since the goal (reminder not existing) is achieved
            return .success(())
        }
        
        do {
            try eventStore.remove(reminder, commit: true)
            return .success(())
        } catch {
            return .failure(.deleteFailed(error.localizedDescription))
        }
    }
    
    // MARK: - Delete Multiple Reminders
    
    func deleteReminders(identifiers: [String]) async -> Result<Void, ReminderError> {
        // Check authorization
        if !isAuthorized {
            let granted = await requestAccess()
            if !granted {
                return .failure(.accessDenied)
            }
        }
        
        var hasError = false
        var lastError: String?
        
        for identifier in identifiers {
            if let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder {
                do {
                    try eventStore.remove(reminder, commit: false) // Don't commit yet
                } catch {
                    hasError = true
                    lastError = error.localizedDescription
                }
            }
        }
        
        // Commit all changes at once
        do {
            try eventStore.commit()
            if hasError, let error = lastError {
                return .failure(.deleteFailed(error))
            }
            return .success(())
        } catch {
            return .failure(.deleteFailed(error.localizedDescription))
        }
    }
}

// MARK: - Reminder Errors

enum ReminderError: Error, LocalizedError {
    case accessDenied
    case saveFailed(String)
    case deleteFailed(String)
    case noDefaultList
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Reminders access denied. Enable in Settings."
        case .saveFailed(let reason):
            return "Failed to save: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete: \(reason)"
        case .noDefaultList:
            return "No default reminders list available."
        }
    }
}