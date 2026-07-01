# Medication Reminder 💊
A simple, intuitive, and effective Flutter application to help users remember to take their daily medications on time.
## 🚀 Features
- **Set Reminders**: Easily schedule reminders for specific medications by specifying the name, dose, and time.
- **Local Notifications**: Receive high-priority local push notifications exactly when it's time to take your medication.
- **Persistent Storage**: All reminders are saved locally using **Hive**, ensuring you won't lose your schedule even if you close or restart the app.
- **Timezone Support**: Accurate notification scheduling tailored to your local timezone.
- **Manage Schedule**: View your list of active reminders and delete them when they are no longer needed.
## 🛠️ Tech Stack & Packages
- **Framework**: [Flutter](https://flutter.dev/)
- **Local Storage**: `hive`, `hive_flutter`
- **Notifications**: `awesome_notifications`
- **Time Management**: `timezone`, `flutter_timezone`
## ⚙️ Getting Started
Follow these steps to run the project locally on your machine.
### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed on your machine.
- An IDE such as Android Studio, VS Code, or IntelliJ IDEA.
- For Android: Android SDK and an emulator or physical device.
- For iOS: Xcode and a simulator or physical device (macOS required).
### Installation
1. **Clone the repository:**
   ```bash
   git clone https://github.com/Bijay-Gurung/Medication-Reminder.git
   ```
2. **Navigate to the project directory:**
   ```bash
   cd Medication-Reminder
   ```
3. **Install the dependencies:**
   ```bash
   flutter pub get
   ```
4. **Run the app:**
   ```bash
   flutter run
   ```
## 📝 Usage
1. Open the app and tap on **"Set Reminder"** on the home screen.
2. Enter the **Medicine Name**, **Number of Doses**, and pick a **Time** using the time picker.
3. Tap **SET REMINDER** to save.
4. You will receive a push notification at the scheduled time reminding you to take your medication.
5. You can view or delete your saved reminders at the bottom of the "Set Reminder" screen.
