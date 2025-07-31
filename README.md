# Real Time Bus Tracking System

## 🌞 Fusion Hacks 2: Where Ideas Bloom and Shine

A Month-Long Celebration of Summer & Innovation

---

## 🚍 The Challenge: Real-Time Bus Tracking System

Can technology transform the daily chaos of public transport into a seamless experience?

Every day, students and commuters struggle with uncertainty: missed buses, overcrowded vehicles, and no real way to know what's happening on the road. Outdated systems leave passengers in the dark, while admins and drivers work in silos.

**Real-Time Bus Tracking System** is our answer — a smart, integrated platform that connects students, drivers, and administrators in real time. It brings clarity, coordination, and control to public transportation using mobile GPS, IoT sensors, and role-based dashboards.

---

A smart solution for tracking buses in real time for students, drivers, and administrators.

---

## 🧠 How It Works

### 🎫 Signup & Verification
Users submit personal details and payment proof. Admins review and approve or reject each request, ensuring secure access control.

### 👨‍✈️ Driver Portal
Drivers can view assigned buses, check their routes, and start/stop live tracking by beginning or ending their shift. As soon as a shift starts, the driver's GPS location is shared in real time with students.

### 🚌 Student Portal
Students view a live list of active buses, including route, stops, and real-time seat availability — powered by pressure sensors installed in bus seats. As users sit or stand, the seat count updates instantly.

### 🧑‍💼 Admin Dashboard
Admins manage buses, assign drivers, handle users, and review feedback. The system ensures centralized control and seamless driver-bus-student coordination.

### 🧾 Additional Features
- Profile management (photo/password updates) for students and drivers
- Real-time feedback system to improve service quality

---

## 🚍 Overview

**Real Time Bus Tracking System** is a cross-platform application designed to provide live bus tracking, route management, and notifications for students, drivers, and admins. Built with Flutter and Firebase, it ensures seamless communication and efficient transport management for educational institutions.

---

## 🎯 Key Features

- **Live Bus Tracking:** Real-time location updates for students and admins.
- **Driver Dashboard:** Route assignments, profile management, and notifications.
- **Admin Panel:** Add/edit buses, drivers, and manage users.
- **Student Dashboard:** View bus location, estimated arrival, and receive alerts.
- **Push Notifications:** Instant alerts for arrivals, delays, and emergencies.
- **Secure Authentication:** Role-based login for students, drivers, and admins.

---

## 🏗️ System Architecture

### 🎯 Key Architectural Principles

- **Real-Time Communication:** Live GPS tracking and instant notifications
- **Role-Based Access Control:** Secure authentication for students, drivers, and admins
- **IoT Integration:** Pressure sensors for seat availability monitoring
- **Modular Design:** Separate modules for different user roles and functionalities
- **Scalable Backend:** Cloud-based infrastructure for handling multiple buses and users

### 🔄 Data Flow Summary

1. **Authentication Phase:** User login with role-based access control
2. **Location Tracking Phase:** Driver GPS coordinates shared in real-time
3. **Data Processing Phase:** Seat availability and route information updates
4. **Notification Phase:** Instant alerts for arrivals, delays, and emergencies
5. **Management Phase:** Admin oversight and system configuration

### 🏗️ Technical Stack

- **Frontend:** Flutter (Android, iOS, Web, Desktop)
- **Backend:** Firebase (Firestore, Auth, Cloud Messaging, Realtime Database)
- **Notifications:** Firebase Cloud Messaging
- **Maps:** Google Maps API
- **IoT Sensors:** Pressure sensors for seat monitoring
- **Real-time Database:** Firebase Realtime Database for live location and seat data
- **Document Database:** Firestore for user data and route information

---

## 🔄 Data Flow

1. **User Authentication:** Secure login for all roles.
2. **Location Updates:** Drivers share live location; students and admins view on map.
3. **Notifications:** System sends alerts for arrivals, delays, and emergencies.
4. **Admin Management:** Admins manage buses, drivers, and users.

---

## 📱 Screenshots

Below are screenshots of the Real Time Bus Tracking System, covering all major features and user roles (Admin, Driver, Student):

---

### Signup Screen
![Signup Screen](assets/images/signup%20screen.jpg)
**Description:**  
New users (students) register by providing their details and uploading a payment receipt. The signup request is sent to the admin for approval.

---

### Login Screen
![Login Screen](assets/images/login%20screen.jpg)
**Description:**  
Registered users log in to access their respective dashboards based on their role.

---

### Admin Dashboard
![Admin Dashboard](assets/images/Admin%20Dashboard.jpg)
**Description:**  
The admin reviews signup requests, cross-checks payment receipts, and approves or denies access. The dashboard also allows the admin to manage buses,manage drivers assign drivers, manage users, and review feedback.

---

### Add Buses
![Add Buses](assets/images/add%20buses.jpg)
**Description:**  
Admins can add new buses to the system, specifying details such as route, stops, and seat capacity.

---

### Add Drivers
![Add Drivers](assets/images/add%20drivers.jpg)
**Description:**  
Admins can add new drivers, assigning them to specific buses and routes.

---

### Bus Details
![Bus Details](assets/images/bus%20details%20.jpg)
**Description:**  
Drivers and students can view detailed information about each bus, including route, stops, and seat capacity.

---


### Driver Dashboard
![Driver Dashboard](assets/images/driver%20dashboard.jpg)
**Description:**  
Drivers can view their assigned bus and route, start or end their shift, and share their live location with students.

---

### Feedback Screen
![Feedback Screen](assets/images/feedback%20screen.jpg)
**Description:**  
Users can submit feedback about the service, which is reviewed by the admin to improve quality.

---


### Manage Buses
![Manage Buses](assets/images/manage%20buses.jpg)
**Description:**  
Admins can view, edit, or remove buses, and assign drivers to each bus.

---

### Manage Drivers
![Manage Drivers](assets/images/manage%20driver.jpg)
**Description:**  
Admins can view, edit, or remove drivers from the system.

---

### Manage Feedbacks
![Manage Feedbacks](assets/images/manage%20feedbacks.jpg)
**Description:**  
Admins can view and manage feedback submitted by users.

---

### Manage Users
![Manage Users](assets/images/manage%20users.jpg)
**Description:**  
Admins can view, approve, or deny user registration requests, ensuring only verified users access the system.

---

### Profile Screen
![Profile Screen](assets/images/profile%20screen.jpg)
**Description:**  
Both students and drivers can view and update their profile, including changing their picture and password.

---

### Student Dashboard
![Student Dashboard](assets/images/student%20dashboard.jpg)
**Description:**  
Students can view a list of active buses, check bus details, and see live seat availability (powered by pressure sensors in the seats).

---

### Track Bus (Driver is Online)
![Track Bus Driver is Online](assets/images/track%20bus%20driver%20is%20online.jpg)
**Description:**  
When a driver starts their shift, their live location is shared with students in real time.

---

## 📖 Usage Guide

1. **Login:** Choose your role and sign in.
2. **For Students:** View your assigned bus, track its location, and receive notifications.
3. **For Drivers:** Update your location, view assigned routes, and receive instructions.
4. **For Admins:** Manage buses, drivers, and users from the dashboard.

---

## 💻 Tech Stack

- **Flutter**: Cross-platform UI framework
- **Firebase**: Authentication, Firestore, Cloud Messaging, Realtime Database
- **Google Maps API**: Real-time map integration
- **IoT Sensors**: Pressure sensors for seat monitoring
- **GPS Services**: Real-time location tracking

---

## 🚀 Installation & Setup

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Android Studio / Xcode (for mobile development)
- Firebase account & project
- Google Maps API Key
- Git

### Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/real-time-bus-tracking-system.git
cd bus_tracking_system

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Firebase Setup

1. **Create Firebase Project:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project or select existing one

2. **Configure Authentication:**
   - Enable Email/Password authentication
   - Set up user roles (Student, Driver, Admin)

3. **Setup Firestore Database:**
   - Create Firestore database in test mode
   - Configure security rules for role-based access

4. **Setup Realtime Database:**
   - Create Realtime Database for live location tracking
   - Configure database rules for location and seat occupancy data
   - Set up data structure for:
     - `locations/{busId}`: Real-time GPS coordinates
     - `seatOccupancy/{busId}`: Live seat availability status

5. **Configure Cloud Messaging:**
   - Enable Firebase Cloud Messaging
   - Add your app to FCM project

6. **Add Configuration Files:**
   - Download `google-services.json` for Android
   - Download `GoogleService-Info.plist` for iOS
   - Place them in `android/app/` and `ios/Runner/` respectively

### Google Maps API Setup

1. **Get API Key:**
   - Visit [Google Cloud Console](https://console.cloud.google.com/)
   - Enable Maps SDK for Android/iOS
   - Create API key with appropriate restrictions

2. **Configure API Key:**
   - Add to `android/app/src/main/AndroidManifest.xml`
   - Add to `ios/Runner/AppDelegate.swift`

### IoT Sensor Setup (Optional)

- Install pressure sensors in bus seats
- Configure sensor data integration with Firebase
- Set up real-time seat availability monitoring

---

## 📁 Project Structure

```
bus_tracking_system/
├── 📄 lib/                           # Main Flutter application code
│   ├── 📄 main.dart                  # Application entry point
│   ├── 📄 Admin/                     # Admin panel modules
│   │   ├── 📄 admin_dashboard.dart   # Admin main dashboard
│   │   ├── 📄 bus_management.dart    # Bus CRUD operations
│   │   ├── 📄 driver_management.dart # Driver assignment & management
│   │   └── 📄 user_management.dart   # User approval & management
│   │
│   ├── 📄 Auth/                      # Authentication modules
│   │   ├── 📄 login_screen.dart      # Login interface
│   │   ├── 📄 signup_screen.dart     # User registration
│   │   └── 📄 auth_service.dart      # Firebase auth integration
│   │
│   ├── 📄 Driver/                    # Driver portal modules
│   │   ├── 📄 driver_dashboard.dart  # Driver main interface
│   │   ├── 📄 route_view.dart        # Route information display
│   │   ├── 📄 tracking_service.dart  # GPS tracking functionality
│   │   └── 📄 shift_management.dart  # Start/stop shift controls
│   │
│   ├── 📄 Student/                   # Student portal modules
│   │   ├── 📄 student_dashboard.dart # Student main interface
│   │   ├── 📄 bus_tracking.dart      # Real-time bus location
│   │   ├── 📄 seat_availability.dart # Seat monitoring display
│   │   └── 📄 notifications.dart     # Push notification handling
│   │
│   ├── 📄 Services/                  # Backend services
│   │   ├── 📄 firebase_service.dart  # Firebase integration
│   │   ├── 📄 location_service.dart  # GPS & location services
│   │   ├── 📄 notification_service.dart # FCM integration
│   │   └── 📄 iot_service.dart       # IoT sensor integration
│   │
│   ├── 📄 models/                    # Data models
│   │   ├── 📄 user_model.dart        # User data structure
│   │   ├── 📄 bus_model.dart         # Bus information model
│   │   ├── 📄 route_model.dart       # Route data structure
│   │   └── 📄 notification_model.dart # Notification data model
│   │
│   ├── 📄 Screens/                   # UI screens
│   │   ├── 📄 splash_screen.dart     # Loading screen
│   │   ├── 📄 home_screen.dart       # Main navigation
│   │   └── 📄 profile_screen.dart    # User profile management
│   │
│   └── 📄 theme/                     # UI theme & styling
│       ├── 📄 app_theme.dart         # Main theme configuration
│       ├── 📄 colors.dart            # Color palette definitions
│       ├── 📄 text_styles.dart       # Typography styles
│       └── 📄 widgets.dart           # Custom reusable widgets
│
├── 🎨 assets/                        # Static assets
│   ├── 🖼️ images/                    # Image resources
│   │   ├── 🖼️ bus-icon.png          # Bus icon (15KB)
│   │   ├── 🖼️ Logo.png              # Application logo (25KB)
│   │   ├── 🖼️ driver-avatar.png     # Default driver avatar (12KB)
│   │   └── 🖼️ student-avatar.png    # Default student avatar (10KB)
│   │
│   ├── 📄 fonts/                     # Custom fonts
│   │   └── 📄 poppins/               # Poppins font family
│   │
│   └── 📄 icons/                     # Custom icons
│       ├── 📄 bus_icons.dart         # Bus-related icons
│       └── 📄 navigation_icons.dart  # Navigation icons
│
├── 📱 android/                       # Android platform files
│   ├── 📄 app/                       # Android app configuration
│   │   ├── 📄 src/main/              # Main Android source
│   │   │   ├── 📄 AndroidManifest.xml # Android permissions & config
│   │   │   └── 📄 google-services.json # Firebase Android config
│   │   └── 📄 build.gradle           # Android build configuration
│   └── 📄 gradle/                    # Gradle wrapper files
│
├── 🍎 ios/                           # iOS platform files
│   ├── 📄 Runner/                    # iOS app configuration
│   │   ├── 📄 Info.plist             # iOS app permissions
│   │   ├── 📄 GoogleService-Info.plist # Firebase iOS config
│   │   └── 📄 AppDelegate.swift      # iOS app delegate
│   └── 📄 Podfile                    # iOS dependencies
│
├── 🌐 web/                           # Web platform files
│   ├── 📄 index.html                 # Web entry point
│   └── 📄 web_manifest.json          # Web app manifest
│
├── 🧪 test/                          # Test files
│   ├── 📄 widget_test.dart           # Widget tests
│   ├── 📄 integration_test.dart      # Integration tests
│   └── 📄 unit_test.dart             # Unit tests
│
├── 📄 pubspec.yaml                   # Flutter dependencies & configuration
├── 📄 pubspec.lock                   # Locked dependency versions
├── 📄 analysis_options.yaml          # Dart analysis configuration
├── 📄 .gitignore                     # Git ignore patterns
└── 📄 README.md                      # Project documentation
```

### Key Files Description:

- **main.dart**: Application entry point with Firebase initialization and theme setup
- **pubspec.yaml**: Flutter dependencies including Firebase, Google Maps, and location services
- **theme/**: Complete UI theming system with colors, typography, and custom widgets
- **Services/**: Backend integration modules for Firebase, GPS, notifications, and IoT sensors
- **Admin/Driver/Student/**: Role-specific modules with dedicated dashboards and functionalities
- **assets/**: Static resources including images, fonts, and custom icons
- **android/ios/web/**: Platform-specific configurations and Firebase setup files
- **test/**: Comprehensive testing suite for widgets, integration, and unit tests

---

## 🏅 Why Use This System?

- **Efficient Transport Management**
- **Real-Time Updates**
- **Role-Based Access**
- **Cross-Platform Support**
- **Easy to Deploy and Maintain**

---

## 👨‍💻 Contributors

- SYED ATIF SHAH (aatifshah15@gmail.com)

---

## 📢 Contact

For queries, contact [aatifshah15@gmail.com](mailto:aatifshah15@gmail.com)

---

## 🏷️ Topics

flutter, firebase, realtime, bus-tracking, google-maps, notifications
