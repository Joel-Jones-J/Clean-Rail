# 🚆 Indian Railways Inspection Portal

This Flutter application serves as a comprehensive portal for managing **train** and **platform inspections** within the Indian Railways system. It provides functionalities for conducting detailed inspections, uploading train data, generating PDF reports, and managing user authentication.

---

## 🔧 Features

### ✅ User Authentication
- Secure login and logout using **Firebase Authentication**.

### 🏠 Dashboard
- Centralized hub for accessing all inspection and data upload modules.

---

### 🚆 Train Interior Inspection
- Input/load **Train Number**, **Coach Number**, and **Inspection Date**.
- Inspect key parameters:
  - Cleanliness
  - Seating
  - Windows
  - Lights
  - Fans/AC
  - Toilets
  - Dustbins
  - Doors
  - Emergency Equipment
  - Information Displays
- Rate each parameter (0–10) via sliders.
- Add remarks for each inspection.
- **Firestore** persistence – load past inspections for a given train.

---

### 🛤️ Platform Management
- Input/load **Station Name** and **Inspection Date**.
- Inspect key parameters:
  - Platform Cleanliness
  - Drainage
  - Seating
  - Dustbins
  - Signage
  - Urinals/Toilets
  - Water Booths
  - Waiting Rooms
  - Subways/FOBs
  - Station Approach
- Rate each parameter (0–10) and add remarks.
- Data saved to **Firestore**.

---

### 📤 Upload Train Data
- Add new train details:
  - Train Number & Name
  - Train Type: **Passenger** or **Express**
- Passenger:
  - Enter number of coaches (e.g., C1, C2…)
- Express:
  - Define **Unreserved (UR)** and **Reserved** coaches (e.g., A1, S1, B1…)
- Prevents duplicate entries.
- View uploaded train data (from Firestore).

---

### 📄 PDF Reports
- Generate reports for:
  - **Station Inspections**
  - **Train Interior Inspections**
- Input required identifier (Station Name or Train Number).
- Generates detailed PDF including:
  - Inspection Parameters
  - Marks
  - Remarks
  - Metadata (date, time, etc.)
- **Auto-download and open** PDFs on mobile and desktop.

---

### 📱 UI/UX
- Fully **Responsive** design.
- Smooth transitions using:
  - `animate_do`
  - `lottie`

---

## 🛠️ Technologies Used

- **Flutter** – Cross-platform UI toolkit  
- **Dart** – Programming language  
- **Firebase**
  - Firestore – Cloud NoSQL DB
  - Firebase Auth – Secure login

### 📦 Dependencies
- `animate_do` – UI animations  
- `intl` – Date/time formatting  
- `lottie` – Animated loaders  
- `pdf` – PDF generation  
- `path_provider` – Access device storage  
- `permission_handler` – Manage permissions  
- `open_filex` – Open generated PDFs  
- `collection` – Utilities like `firstWhereOrNull`  
- `google_fonts` – Custom fonts  

---

## ⚙️ Setup & Installation

### 1. Clone the Repository
```bash
git clone https://github.com/Joel-Jones-J/Train_Station_Evaluation_Project.git
cd Train_Station_Evaluation_Project


2. Install Flutter
Follow the Flutter installation guide if not already installed.

3. Install Dependencies
bash
Copy
Edit
flutter pub get
4. Firebase Setup
Go to Firebase Console

Create a new project

Add Android/iOS/Web apps and download:

google-services.json (Android) → Place in android/app/

GoogleService-Info.plist (iOS) → Place in ios/Runner/

Enable:

Firestore Database

Email/Password Authentication

🖼️ Assets Setup
Place the following inside the assets/ folder:


assets/
├── app_logo.png
├── background.png
├── light-1.png
├── light-2.png
├── clock.png
├── loading_login.json
├── platform_view.png
├── train_interior.png
Update pubspec.yaml:


flutter:
  uses-material-design: true
  assets:
    - assets/
▶️ Run the Application

flutter run
🧑‍💻 Usage Instructions
🔐 Login
Use your Firebase-authenticated email & password.

🏠 Dashboard Navigation
Train Operations – Inspect train interiors.

Platform Management – Inspect stations.

PDF Reports – Generate reports.

Upload Train Data – Add train info.

📝 Inspections
Enter Train Number/Station Name, Coach Number, and Date.

Rate each parameter (0–10) and add remarks.

Submit – data is saved to Firestore.

📤 Upload Train Data
Enter train info and type.

Input coach data (custom names for Express).

Submit to Firestore.

📄 Generate PDF
Select inspection type.

Enter identifier (Train No. or Station Name).

Auto-generate and open PDF.

📁 File Structure

lib/
├── main.dart
├── login_page.dart
├── home_page.dart
├── dashboard_page.dart
├── platform_page.dart
├── train_inspection_interior.dart
├── upload_train_data.dart
├── pdf_page.dart
├── activity_rating_page.dart (if used)
assets/
🤝 Contributing
Contributions are welcome!
Please open an Issue or submit a Pull Request.

📝 License
This project is licensed under the MIT License – see the LICENSE file for details.

📬 Contact
Joel Jones J
📱 +91 8438697642
📧 Feel free to reach out for suggestions or collaborations.










