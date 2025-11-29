# 🚗 Car Booking System

A cross-platform mobile and web application built with Flutter that allows users to browse, select, and book vehicles. This system aims to provide a seamless and intuitive experience for managing car rentals or bookings.

## ✨ Features

This application includes key features necessary for a functional car booking system:

* **User Authentication:** Secure sign-up and sign-in functionality powered by Firebase.
* **Car Browsing:** View a list of available cars with details like model, price, and features.
* **Date Selection:** Intuitive interface for selecting pick-up and drop-off dates.
* **Booking Management:** Submit new bookings and view the status of current reservations.
* **Booking History:** Access a complete log of past car bookings.
* **Responsive UI:** A clean, modern interface designed to work well on mobile (iOS/Android) and web platforms.

## 💻 Technology Stack

This project is a full-stack application leveraging the following technologies:

| Category | Technology | Description |
| :--- | :--- | :--- |
| **Frontend** | **Flutter (Dart)** | Cross-platform framework for building the user interface. |
| **Backend** | **Firebase** | Used for real-time database, authentication, and other backend services (e.g., Firestore/Authentication). |

## 🚀 Getting Started

Follow these steps to set up the project locally.

### Prerequisites

* **Flutter SDK:** [Installation Guide](https://docs.flutter.dev/get-started/install)
* **Dart SDK:** Included with Flutter.
* **Firebase CLI:** For setting up and managing your Firebase project.
* **Code Editor:** VS Code or Android Studio (with Flutter plugin).

### Installation and Setup

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/WAIHONGGR/Car-Booking-System-.git](https://github.com/WAIHONGGR/Car-Booking-System-.git)
    cd Car-Booking-System-
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration (Critical Step):**
    * Create a new project in the [Firebase Console](https://console.firebase.google.com/).
    * Register your applications (Android, iOS, Web) with the Firebase project.
    * Follow the standard Firebase setup process (e.g., placing `google-services.json` for Android and `GoogleService-Info.plist` for iOS in the respective platform folders).
    * Run the FlutterFire CLI command to configure your files:
        ```bash
        flutterfire configure
        ```
    * *Note: Ensure you have initialized Firebase Authentication and Firestore/Realtime Database in your Firebase console.*

4.  **Run the application:**

    * To run on a connected device or emulator:
        ```bash
        flutter run
        ```
    * To run on the web:
        ```bash
        flutter run -d chrome
        ```

## 🛠 Usage

1.  **Launch the App:** Start the application on your preferred platform.
2.  **Sign Up/Log In:** Create a new account or log in with existing credentials.
3.  **Browse Cars:** Navigate the home screen to see the available fleet.
4.  **Select Dates:** Choose your desired pick-up and drop-off times.
5.  **Confirm Booking:** Review the details and finalize the reservation.
6.  **Manage:** Check your booking status and history via the user profile or dedicated history tab.

## 🤝 Contributing

Contributions are welcome! If you find a bug or have an idea for an enhancement, please follow these steps:

1.  **Fork** the repository.
2.  **Create a new branch:** `git checkout -b feature/your-feature-name`
3.  **Make your changes** and commit them: `git commit -m 'feat: add new feature for X'`
4.  **Push** to the branch: `git push origin feature/your-feature-name`
5.  **Open a Pull Request** to the `master` branch.

## 📄 License

*(Add your license here, e.g., MIT, Apache 2.0, etc. If you do not include one, you can use a placeholder like "Distributed under the [LICENSE NAME] License. See `LICENSE` for more information.")*
