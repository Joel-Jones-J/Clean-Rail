import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:animate_do/animate_do.dart'; // Import animate_do package
// import 'package:intl/intl.dart'; // No longer directly used in DashboardPage
// import 'package:google_fonts/google_fonts.dart'; // No longer directly used in DashboardPage

// Assuming LoginPage exists in your project structure for logout navigation
import 'login_page.dart';
// Assuming UploadTrainDataPage exists in your project structure for drawer navigation
import 'upload_train_data.dart';
// Import the new inspection page
import 'train_inspection_interior.dart';
// Import the PlatformPage for station navigation
import 'platform_page.dart';
// Import the new PdfPage
import 'pdf_page.dart';


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _trainNumberController = TextEditingController();

  Map<String, dynamic>? _trainData; // To store train name fetched from 'Train' collection
  bool _isLoadingData = false; // Combined loading state for fetching and navigating
  String? _errorMessage;

  // Define the sections and their parameters, similar to train_inspection_interior.dart
  // This is kept here to initialize _inspectionParameters with all possible fields.
  final Map<String, List<String>> _sections = {
    'Train Details': ['trainNumber', 'inspectionCoach', 'inspectionDate'],
    'Interior Cleanliness & Condition': [
      'Interior Cleanliness (Floor, Walls, Ceiling)',
      'Seating Condition (Cleanliness, Damage)',
      'Window Cleanliness & Condition',
      'Light Fixtures Functionality & Cleanliness',
      'Fan/AC Functionality & Cleanliness',
      'Toilet Cleanliness & Water Availability',
      'Dustbins Cleanliness & Availability in Coach',
      'Door Functionality & Cleanliness',
      'Emergency Equipment (First Aid, Fire Extinguisher)',
      'Information Displays/Signage Clarity',
    ],
    'Exterior Condition': [
      'Exterior Cleanliness (Walls, Roof)',
      'Window Exterior Cleanliness',
      'Undergear Cleanliness',
      'Coupling Condition',
      'Brake System Visual Check',
    ],
    'Safety Features': [
      'Emergency Exit Accessibility',
      'Fire Extinguisher Presence & Expiry',
      'First Aid Kit Presence & Contents',
      'Emergency Chain/Alarm Functionality',
    ],
    'Passenger Amenities': [
      'Water Cooler Functionality & Cleanliness',
      'Charging Points Functionality',
      'Luggage Rack Condition',
      'Aisle Clearances',
    ],
    'Staff Performance': [
      'Staff Uniform & Grooming',
      'Staff Courtesy & Responsiveness',
      'Staff Knowledge & Assistance',
    ],
  };

  // Local state for inspection parameters, mimicking Firestore structure
  // Key: parameter name (String), Value: Map with 'marks' (int) and 'remarks' (String)
  final Map<String, Map<String, dynamic>> _inspectionParameters = {};

  @override
  void initState() {
    super.initState();
    _initializeParameters(); // Initialize parameters with default values (0 marks, empty remarks)
  }

  // Helper function to initialize all inspection parameters with default values
  void _initializeParameters() {
    _inspectionParameters.clear(); // Ensure clean slate
    for (var section in _sections.keys) {
      if (section != 'Train Details') { // 'Train Details' are handled by controllers/date picker
        for (var paramName in _sections[section]!) {
          _inspectionParameters[paramName] = {
            'name': paramName,
            'marks': 0,
            'remarks': '',
          };
        }
      }
    }
  }

  @override
  void dispose() {
    _trainNumberController.dispose();
    super.dispose();
  }

  // Function to handle user logout
  void logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } catch (e) {
      print("Error during logout: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to log out. Please try again.')),
      );
    }
  }

  // Function to fetch train data and navigate to the inspection page
  Future<void> _fetchTrainDataAndNavigate() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _errorMessage = 'Please enter the Train Number.';
      });
      return;
    }

    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
    });

    String trainNumber = _trainNumberController.text.trim();

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      DocumentSnapshot trainDoc = await firestore.collection('Train').doc(trainNumber).get();
      DocumentSnapshot inspectionDoc = await firestore.collection('trainInspections').doc(trainNumber).get();

      if (trainDoc.exists) {
        _trainData = trainDoc.data() as Map<String, dynamic>;
        String trainName = _trainData!['trainName'] ?? 'N/A';

        // Prepare parameters to pass to the new page
        Map<String, Map<String, dynamic>> parametersToPass = {};
        String initialCoachNumber = ''; // Default empty coach number
        DateTime initialInspectionDate = DateTime.now(); // Default current date

        if (inspectionDoc.exists) {
          // Load existing inspection data if available
          Map<String, dynamic> existingInspectionData = inspectionDoc.data() as Map<String, dynamic>;

          initialCoachNumber = existingInspectionData['inspectionCoach'] ?? '';
          initialInspectionDate = (existingInspectionData['inspectionDate'] as Timestamp?)?.toDate() ?? DateTime.now();

          _initializeParameters(); // Reset to defaults before loading
          if (existingInspectionData['parameters'] is List) {
            for (var param in existingInspectionData['parameters']) {
              if (param is Map<String, dynamic> && param.containsKey('name')) {
                parametersToPass[param['name']] = {
                  'name': param['name'],
                  'marks': param['marks'] ?? 0,
                  'remarks': param['remarks'] ?? '',
                };
              }
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loaded existing inspection data for Train "$trainNumber".')),
          );
        } else {
          // No existing inspection, initialize with default empty values
          _initializeParameters(); // Ensure all parameters are reset to 0/empty
          parametersToPass = Map.from(_inspectionParameters); // Copy the initialized defaults
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No existing inspection data found for Train "$trainNumber". Starting new inspection.')),
          );
        }

        // Navigate to the new inspection page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrainInspectionInteriorPage(
              trainNumber: trainNumber,
              trainName: trainName, // Pass the fetched train name
              initialCoachNumber: initialCoachNumber,
              initialInspectionDate: initialInspectionDate,
              initialParameters: parametersToPass,
            ),
          ),
        ).then((_) {
          // This block executes when returning from TrainInspectionInteriorPage
          // Reset the input fields and state to allow new train entry
          setState(() {
            _trainNumberController.clear();
            _trainData = null;
            _errorMessage = null;
            _isLoadingData = false;
            _initializeParameters(); // Reset parameters for next entry
          });
        });

      } else {
        setState(() {
          _errorMessage = 'Train number "$trainNumber" not found. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching train data: $e';
      });
      print("Error fetching train data: $e");
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // final user = FirebaseAuth.instance.currentUser; // Get the current authenticated user

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Train Inspection Dashboard',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)], // Blue gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => logout(context),
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueAccent, Colors.lightBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Text(
                'Train App Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.directions_railway, color: Colors.blueGrey),
              title: const Text(
                'Train Interior Inspection',
                style: TextStyle(fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                // Navigate to DashboardPage (which is this page itself, resetting it)
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const DashboardPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.alt_route, color: Colors.blueGrey),
              title: const Text(
                'Station Management',
                style: TextStyle(fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PlatformPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.blueGrey), // PDF icon
              title: const Text(
                'PDF Reports',
                style: TextStyle(fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PdfPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload, color: Colors.blueGrey),
              title: const Text(
                'Upload Train Data',
                style: TextStyle(fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UploadTrainDataPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.blueGrey),
              title: const Text(
                'Logout',
                style: TextStyle(fontSize: 16),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: Container( // Initial screen for Train Number input
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF42A5F5)], // Deep blue to light blue gradient
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView( // Added SingleChildScrollView here
          child: ConstrainedBox( // Use ConstrainedBox to ensure minimum height
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - AppBar().preferredSize.height - MediaQuery.of(context).padding.top,
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon for visual appeal
                    FadeInDown(
                      duration: const Duration(milliseconds: 800),
                      child: Icon(
                        Icons.train,
                        size: 120,
                        color: Colors.white.withOpacity(0.9),
                        shadows: const [
                          Shadow(
                            blurRadius: 15.0,
                            color: Colors.black54,
                            offset: Offset(3.0, 3.0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Main title
                    FadeInLeft(
                      duration: const Duration(milliseconds: 1000),
                      child: const Text(
                        'Welcome to Indian Railways',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 10.0,
                              color: Colors.black54,
                              offset: Offset(2.0, 2.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Subtitle/Instruction
                    FadeInRight(
                      duration: const Duration(milliseconds: 1200),
                      child: const Text(
                        'Please enter the Train Number to begin your inspection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Input field container for Train Number
                    FadeInUp(
                      duration: const Duration(milliseconds: 1400),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              spreadRadius: 3,
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _trainNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Train Number',
                            hintText: 'e.g., 12345',
                            border: InputBorder.none, // Remove default border
                            labelStyle: TextStyle(color: Colors.blueGrey),
                            hintStyle: TextStyle(color: Colors.grey),
                            prefixIcon: Icon(Icons.numbers, color: Colors.blueAccent),
                          ),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 18, color: Colors.black87),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Train Number is required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    if (_errorMessage != null)
                      FadeInUp(
                        duration: const Duration(milliseconds: 1600),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    const SizedBox(height: 40),
                    // Proceed to Inspection Button
                    FadeInUp(
                      duration: const Duration(milliseconds: 1700),
                      child: _isLoadingData
                          ? const CircularProgressIndicator(color: Colors.white)
                          : ElevatedButton.icon(
                              onPressed: _fetchTrainDataAndNavigate, // Call function to fetch and navigate
                              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                              label: const Text(
                                'Proceed to Inspection',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30), // Pill-shaped button
                                ),
                                backgroundColor: const Color(0xFFFFC107), // Amber color
                                foregroundColor: Colors.white,
                                elevation: 10, // More pronounced shadow
                                shadowColor: Colors.black.withOpacity(0.4),
                                animationDuration: const Duration(milliseconds: 300),
                              ),
                            ),
                    ),
                    const SizedBox(height: 50), // Add some bottom padding
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}