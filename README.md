# Voice Mind 🧠🎙️

**Voice Mind** is an intelligent, AI-powered personal assistant designed to transform unstructured voice recordings into structured, actionable productivity data. Built natively for iOS, it leverages Google's Gemini LLM to analyze speech, categorize intent, and automatically schedule events or tasks.

---

## 🎯 Project Theme
**Category:** Productivity & AI Assistant
This project addresses the friction of manual note-taking. By combining **Core Audio** with **Generative AI**, Voice Mind allows users to "dump" thoughts verbally and trust the system to organize them into:
* 📅 **Events:** Auto-scheduled to the native iOS Calendar.
* ✅ **Tasks:** Action items extracted to lists and Apple Reminders.
* 📝 **Notes:** Summarized thoughts with sentiment analysis.

---

## ✨ Key Features

### 🎙️ Advanced Audio Capture
* **Hybrid Audio Pipeline:** Custom implementation using `AVAudioEngine` and `AVAudioFile` to ensure high-fidelity recording while simultaneously streaming buffers to the speech recognizer.
* **Real-time Transcription:** Uses `SFSpeechRecognizer` for on-device, instant text feedback.
* **Audio Visualization:** Live pulsing animations indicating recording status.

### 🧠 AI Analysis (Google Gemini)
* **Smart Summarization:** Converts long rambles into concise, first-person summaries.
* **Entity Extraction:** Automatically detects dates (e.g., "Lunch next Friday"), locations, and keywords.
* **Sentiment & Categorization:** Classifies notes by mood (Positive/Neutral/Negative) and domain (Work, Personal, Health, etc.).
* **Multilingual Support:** Supports English, Portuguese, Spanish, French, and German via user selection.

### 📱 Native Integrations
* **Calendar Sync:** Deep integration with `EventKit` to create calendar events directly.
* **Apple Reminders:** One-tap export of extracted "Action Items" to the native Reminders app.
* **Smart In-App Search:** Notes are indexed and searchable.

### 📊 Insights Dashboard
* **Visual Analytics:** Interactive charts (using Swift Charts) showing mood trends, weekly activity, and note type distribution.
* **Quantified Self:** Tracks productivity metrics over time.

---

## 🏗️ Technical Architecture

* **Pattern:** MVVM (Model-View-ViewModel) for clean separation of logic and UI.
* **Storage:** **SwiftData** for modern, type-safe local persistence.
* **UI Framework:** **SwiftUI** with complex animations and custom transitions.
* **Concurrency:** Extensive use of Swift 5.5 `async/await` and actors.

### Tech Stack
| Component | Technology |
| :--- | :--- |
| **Language** | Swift 5.9+ |
| **Minimum OS** | iOS 17.0 |
| **AI Model** | Google Gemini 2.5 Flash |
| **Database** | SwiftData |
| **Audio** | AVFoundation, Speech |
| **Integrations** | EventKit (Calendar & Reminders) |

---

## 🛠️ Installation & Setup

⚠️ **IMPORTANT:** This project requires a Google Gemini API Key to function.

1.  **Clone the Repository**
    ```bash
    git clone [https://github.com/your-repo/voice-mind.git](https://github.com/your-repo/voice-mind.git)
    cd voice-mind
    ```

2.  **Configure API Keys**
    * The project uses a `Secrets.xcconfig` file to secure API keys (excluded from Git).
    * **Action:** Create a file named `Secrets.xcconfig` in the `FirstApp/` folder (same level as `Info.plist`).
    * Add your key to the file:
        ```properties
        GEMINI_API_KEY = your_google_api_key_here
        ```
    * *Note: If you do not have a key, you can get one for free at [Google AI Studio](https://aistudio.google.com/).*

3.  **Build & Run**
    * Open `FirstApp.xcodeproj` in Xcode 15+.
    * Select your target device (Physical iPhone recommended).
    * Press **Cmd + R**.

### 📱 Permissions
Upon first launch, the app will request:
* 🎤 **Microphone:** To record voice notes.
* 🗣️ **Speech Recognition:** To transcribe audio to text.
* 📅 **Calendar:** To auto-save detected events.
* ✅ **Reminders:** To save extracted tasks.

---

## 🐛 Known Issues (Simulator)
* **Audio Static:** Due to hardware virtualization latency, running this app in the **iOS Simulator (especially inside a VM)** may result in audio static or failed transcriptions.
* **Recommendation:** For the best experience, please test on a **physical iPhone**.
* **Debug Mode:** A simulation mode is available in the code to test AI logic without microphone hardware if needed.

---

## 📄 License
[MIT License](LICENSE) - Copyright (c) 2025 Afonso Fernandes