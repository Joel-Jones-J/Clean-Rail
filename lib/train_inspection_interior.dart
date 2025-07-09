import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart'; // Import for DateFormat
import 'package:google_fonts/google_fonts.dart'; // Import for GoogleFonts
import 'package:collection/collection.dart'; // Import for firstWhereOrNull
import 'package:lottie/lottie.dart'; // Import lottie package for animation

// Assuming LoginPage exists in your project structure for logout navigation
import 'login_page.dart';
// Assuming UploadTrainDataPage exists in your project structure for drawer navigation
import 'upload_train_data.dart';
import 'dashboard_page.dart'; // Import DashboardPage for navigation
import 'platform_page.dart'; // Import PlatformPage for navigation
import 'pdf_page.dart'; // Import PdfPage for navigation


// Helper class to define the structure of each page in the PageView
class PageInfo {
  final String type; // 'train_details', 'coach_section', 'general_section'
  final String? coachId; // e.g., 'C1' (null for train_details and general_section)
  final String sectionName; // e.g., 'Interior Cleanliness & Condition', 'Toilets'
  final String displayTitle; // Title to show in the header button

  PageInfo({
    required this.type,
    this.coachId,
    required this.sectionName,
    required this.displayTitle,
  });
}

class TrainInspectionInteriorPage extends StatefulWidget {
  final String trainNumber;
  final String trainName;
  final String initialCoachNumber; // This might be less relevant with per-coach inspection but kept for consistency
  final DateTime initialInspectionDate;
  final Map<String, Map<String, dynamic>> initialParameters; // Pre-filled parameters (flattened)

  const TrainInspectionInteriorPage({
    super.key,
    required this.trainNumber,
    required this.trainName,
    required this.initialCoachNumber,
    required this.initialInspectionDate,
    required this.initialParameters,
  });

  @override
  State<TrainInspectionInteriorPage> createState() => _TrainInspectionInteriorPageState();
}

class _TrainInspectionInteriorPageState extends State<TrainInspectionInteriorPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _coachNumberController; // For the overall inspection coach
  late DateTime _inspectionDate;
  // Flat map to store all inspection parameters with unique keys like "C1_Toilets_T1_Cleanliness"
  late Map<String, Map<String, dynamic>> _inspectionParameters;
  bool _isLoading = false;
  bool _showLottieLoading = false; // New state for Lottie animation

  final PageController _pageController = PageController(viewportFraction: 0.9); // Adjusted viewportFraction
  int _currentPage = 0; // To track the current page for indicators

  // Define the base inspection parameters for a single coach
  final Map<String, List<String>> _coachSpecificSections = {
    'Interior Cleanliness & Condition': [
      'Interior Cleanliness (Floor, Walls, Ceiling)',
      'Seating Condition (Cleanliness, Damage)',
      'Window Cleanliness & Condition',
      'Light Fixtures Functionality & Cleanliness',
      'Fan/AC Functionality & Cleanliness',
      'Dustbins Cleanliness & Availability in Coach', // Moved from general
      'Emergency Equipment (First Aid, Fire Extinguisher)', // Moved from general
      'Information Displays/Signage Clarity', // Moved from general
    ],
    'Toilets': [
      'T1 Cleanliness & Water Availability',
      'T2 Cleanliness & Water Availability',
      'T3 Cleanliness & Water Availability',
      'T4 Cleanliness & Water Availability',
    ],
    'Door Way Area': [
      'D1 Functionality & Cleanliness',
      'D2 Functionality & Cleanliness',
    ],
    'Vestibule Area': [
      'B1 Condition & Cleanliness',
      'B2 Condition & Cleanliness',
    ],
  };

  // Define general sections that apply to the whole train, not per coach
  final Map<String, List<String>> _generalSections = {
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

  // List to hold all page configurations for the PageView
  late List<PageInfo> _allPages;
  // Map to quickly find the starting index of a coach/section in _allPages
  final Map<String, int> _sectionPageIndexMap = {};
  // List to hold the items for the horizontal header selector
  late List<Map<String, dynamic>> _headerItems;


  @override
  void initState() {
    super.initState();
    _coachNumberController = TextEditingController(text: widget.initialCoachNumber);
    _inspectionDate = widget.initialInspectionDate;
    _inspectionParameters = {}; // Initialize as an empty map

    _initializeAllPagesAndParameters(); // Populate _allPages and _inspectionParameters and _sectionPageIndexMap

    // Load initial data from widget.initialParameters (flattened map from DashboardPage)
    widget.initialParameters.forEach((paramName, value) {
      if (value.containsKey('name') && value.containsKey('marks') && value.containsKey('remarks')) {
        String? matchingKey;
        matchingKey = _inspectionParameters.keys.firstWhereOrNull((key) {
          return _inspectionParameters[key]?['name'] == value['name'];
        });

        if (matchingKey != null) {
          _inspectionParameters[matchingKey] = {
            'name': value['name'],
            'marks': value['marks'] ?? 0,
            'remarks': value['remarks'] ?? '',
            'noFeedback': value['noFeedback'] ?? false,
          };
        }
      }
    });

    // If we are editing an existing inspection, load the data from Firestore
    _loadInitialDataFromFirestore();

    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
  }

  // Helper to initialize all possible pages and their parameters
  void _initializeAllPagesAndParameters() {
    _allPages = [];
    _inspectionParameters.clear();
    _sectionPageIndexMap.clear(); // Clear the map before populating
    _headerItems = []; // Initialize header items list

    int pageIndex = 0;

    // 1. Add Train Details page
    _allPages.add(PageInfo(type: 'train_details', sectionName: 'Train Details', displayTitle: 'Train Details'));
    _sectionPageIndexMap['Train Details'] = pageIndex;
    _headerItems.add({'title': 'Details', 'startIndex': pageIndex});
    pageIndex++;

    // 2. Add Coach-specific sections for C1 to C13
    for (int i = 1; i <= 13; i++) { // Assuming 13 coaches (C1 to C13)
      String coachId = 'C$i';
      // Store the index for the start of this coach's sections
      _sectionPageIndexMap[coachId] = pageIndex;
      _headerItems.add({'title': coachId, 'startIndex': pageIndex}); // Add coach to header items

      for (var entry in _coachSpecificSections.entries) {
        String sectionName = entry.key;
        String displayTitle = '$coachId: $sectionName';
        _allPages.add(PageInfo(type: 'coach_section', coachId: coachId, sectionName: sectionName, displayTitle: displayTitle));
        pageIndex++;

        // Initialize parameters for this coach and section
        for (String paramName in entry.value) {
          // Create a unique key for each parameter
          String fullParamKey = '${coachId}_${sectionName.replaceAll(' ', '_')}_${paramName.replaceAll(' ', '_')}';
          _inspectionParameters[fullParamKey] = {
            'name': paramName,
            'marks': 0,
            'remarks': '',
            'noFeedback': false,
          };
        }
      }
    }

    // 3. Add General sections
    _sectionPageIndexMap['General Sections'] = pageIndex; // Store index for general sections start
    _headerItems.add({'title': 'General', 'startIndex': pageIndex}); // Add General to header items
    for (var entry in _generalSections.entries) {
      String sectionName = entry.key;
      _allPages.add(PageInfo(type: 'general_section', sectionName: sectionName, displayTitle: sectionName));
      pageIndex++;

      // Initialize parameters for general sections
      for (String paramName in entry.value) {
        String fullParamKey = 'General_${sectionName.replaceAll(' ', '_')}_${paramName.replaceAll(' ', '_')}';
        _inspectionParameters[fullParamKey] = {
          'name': paramName,
          'marks': 0,
          'remarks': '',
          'noFeedback': false,
        };
      }
    }

    // Now, populate the 'endIndex' for each header item
    for (int i = 0; i < _headerItems.length; i++) {
      if (i < _headerItems.length - 1) {
        _headerItems[i]['endIndex'] = _headerItems[i + 1]['startIndex'];
      } else {
        _headerItems[i]['endIndex'] = _allPages.length; // Last item ends at the total page count
      }
    }
  }

  // Function to load existing inspection data from Firestore
  Future<void> _loadInitialDataFromFirestore() async {
    // Construct document ID as "trainNumber-trainName"
    String documentId = '${widget.trainNumber}-${widget.trainName.replaceAll(' ', '_')}';

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('Train Interior').doc(documentId).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        setState(() {
          _coachNumberController.text = data['inspectionCoach'] ?? ''; // Load overall coach
          _inspectionDate = (data['inspectionDate'] as Timestamp?)?.toDate() ?? DateTime.now();

          // Load coach-specific data
          if (data['coaches'] is Map) {
            Map<String, dynamic> coachesFromFirestore = data['coaches'];
            coachesFromFirestore.forEach((coachId, coachData) {
              if (coachData is Map) {
                coachData.forEach((sectionNameKey, sectionData) {
                  // Reconstruct original section name from key
                  // ignore: unused_local_variable
                  String originalSectionName = _coachSpecificSections.keys.firstWhereOrNull(
                    (k) => k.replaceAll(' ', '_') == sectionNameKey,
                  ) ?? sectionNameKey.replaceAll('_', ' '); // Fallback

                  if (sectionData is Map) {
                    sectionData.forEach((paramNameKey, paramDetails) {
                      if (paramDetails is Map) {
                        // Reconstruct original parameter name from key (if stored as key)
                        String originalParamName = paramDetails['name'] ?? paramNameKey.replaceAll('_', ' ');
                        String fullParamKey = '${coachId}_${sectionNameKey}_${paramNameKey}';

                        _inspectionParameters[fullParamKey] = {
                          'name': originalParamName,
                          'marks': paramDetails['marks'] ?? 0,
                          'remarks': paramDetails['remarks'] ?? '',
                          'noFeedback': paramDetails['noFeedback'] ?? false,
                        };
                      }
                    });
                  }
                });
              }
            });
          }

          // Load general sections data
          if (data['generalSections'] is Map) {
            Map<String, dynamic> generalSectionsFromFirestore = data['generalSections'];
            generalSectionsFromFirestore.forEach((sectionNameKey, sectionData) {
              // ignore: unused_local_variable
              String originalSectionName = _generalSections.keys.firstWhereOrNull(
                (k) => k.replaceAll(' ', '_') == sectionNameKey,
              ) ?? sectionNameKey.replaceAll('_', ' '); // Fallback

              if (sectionData is Map) {
                sectionData.forEach((paramNameKey, paramDetails) {
                  if (paramDetails is Map) {
                    String originalParamName = paramDetails['name'] ?? paramNameKey.replaceAll('_', ' ');
                    String fullParamKey = 'General_${sectionNameKey}_${paramNameKey}';

                    _inspectionParameters[fullParamKey] = {
                      'name': originalParamName,
                      'marks': paramDetails['marks'] ?? 0,
                      'remarks': paramDetails['remarks'] ?? '',
                      'noFeedback': paramDetails['noFeedback'] ?? false,
                    };
                  }
                });
              }
            });
          }
        });
      }
    } catch (e) {
      print('Error loading inspection data from Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load existing inspection data: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _coachNumberController.dispose();
    _pageController.dispose(); // Dispose the PageController
    super.dispose();
  }

  // Function to select inspection date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _inspectionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(), // Max date is today
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1976D2), // Consistent blue for header
              onPrimary: Colors.white, // Text on primary
              onSurface: Colors.black87, // Text on surface (dates)
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00BCD4), // Teal for buttons
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _inspectionDate = picked;
      });
    }
  }

  // Update methods for local state of parameters
  void _updateParameterMarks(String fullParamKey, int newMarks) {
    setState(() {
      _inspectionParameters[fullParamKey]?['marks'] = newMarks;
    });
  }

  void _updateParameterRemarks(String fullParamKey, String newRemarks) {
    setState(() {
      _inspectionParameters[fullParamKey]?['remarks'] = newRemarks;
    });
  }

  // New method to update noFeedback status
  void _updateParameterNoFeedback(String fullParamKey, bool noFeedback) {
    setState(() {
      _inspectionParameters[fullParamKey]?['noFeedback'] = noFeedback;
      if (noFeedback) {
        // If no feedback, reset marks and remarks
        _inspectionParameters[fullParamKey]?['marks'] = 0;
        _inspectionParameters[fullParamKey]?['remarks'] = 'No feedback provided';
      } else {
        // If feedback is enabled, clear default 'No feedback provided'
        if (_inspectionParameters[fullParamKey]?['remarks'] == 'No feedback provided') {
          _inspectionParameters[fullParamKey]?['remarks'] = '';
        }
      }
    });
  }

  // Function to submit the train inspection form to Firestore
  Future<void> _submitTrainInspection() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields before submitting.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _showLottieLoading = true; // Show Lottie on submit start
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Submitting inspection...')),
    );

    try {
      Map<String, Map<String, Map<String, dynamic>>> coachesData = {};
      Map<String, Map<String, Map<String, dynamic>>> generalSectionsData = {};

      // Iterate through the flat _inspectionParameters and build the nested structure for Firestore
      _inspectionParameters.forEach((fullParamKey, details) {
        List<String> parts = fullParamKey.split('_');
        String paramName = details['name']; // Original parameter name

        Map<String, dynamic> paramDetails = {
          'name': paramName, // Store original name for clarity
          'marks': details['marks'],
          'remarks': details['remarks'],
          'noFeedback': details['noFeedback'],
        };

        if (parts[0].startsWith('C') && parts[0].length > 1 && int.tryParse(parts[0].substring(1)) != null) {
          // Coach-specific parameter
          String coachId = parts[0];
          String sectionKey = parts[1]; // e.g., "Interior_Cleanliness_Condition"
          String paramKeyForFirestore = parts.sublist(2).join('_'); // Rejoin remaining parts for parameter key

          // Ensure nested maps exist
          coachesData.putIfAbsent(coachId, () => {});
          coachesData[coachId]!.putIfAbsent(sectionKey, () => {});
          coachesData[coachId]![sectionKey]![paramKeyForFirestore] = paramDetails;
        } else if (parts[0] == 'General') {
          // General section parameter
          String sectionKey = parts[1];
          String paramKeyForFirestore = parts.sublist(2).join('_'); // Rejoin remaining parts for parameter key

          // Ensure nested maps exist
          generalSectionsData.putIfAbsent(sectionKey, () => {});
          generalSectionsData[sectionKey]!.putIfAbsent(paramKeyForFirestore, () => {}); // Corrected: paramKeyForFirestore directly under sectionKey
          generalSectionsData[sectionKey]![paramKeyForFirestore] = paramDetails;
        }
      });

      Map<String, dynamic> inspectionData = {
        'trainNumber': widget.trainNumber,
        'trainName': widget.trainName,
        'inspectionCoach': _coachNumberController.text.trim(), // Still useful for overall coach context
        'inspectionDate': _inspectionDate,
        'coaches': coachesData,
        'generalSections': generalSectionsData,
        'timestamp': FieldValue.serverTimestamp(),
        'inspectorId': FirebaseAuth.instance.currentUser?.uid,
      };

      // Construct document ID as "trainNumber-trainName"
      String documentId = '${widget.trainNumber}-${widget.trainName.replaceAll(' ', '_')}'; // Replace spaces for valid ID

      // Save data to 'Train Interior' collection with custom document ID
      await FirebaseFirestore.instance.collection('Train Interior').doc(documentId).set(
        inspectionData,
        SetOptions(merge: true), // Use merge to update existing fields or create new document
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection submitted successfully!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context); // Go back to Dashboard after submission
    } catch (e) {
      print('Error submitting inspection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit inspection: $e'), backgroundColor: Colors.red),
      );
    } finally {
      // Ensure Lottie animation plays for a minimum duration
      await Future.delayed(const Duration(milliseconds: 1500)); // Adjust duration as needed
      setState(() {
        _isLoading = false;
        _showLottieLoading = false; // Hide Lottie after submission (or error)
      });
    }
  }

  // Helper function to get icon for section headers
  IconData _getSectionIcon(String sectionName) {
    switch (sectionName) {
      case 'Train Details': return Icons.info_outline;
      case 'Interior Cleanliness & Condition': return Icons.cleaning_services_outlined;
      case 'Toilets': return Icons.wc_outlined;
      case 'Door Way Area': return Icons.door_back_door; // Corrected icon
      case 'Vestibule Area': return Icons.train_outlined; // Or some other relevant icon
      case 'Exterior Condition': return Icons.directions_train_outlined;
      case 'Safety Features': return Icons.security_outlined;
      case 'Passenger Amenities': return Icons.chair_alt_outlined;
      case 'Staff Performance': return Icons.people_outline;
      default: return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Train Interior Inspection',
              style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Train: ${widget.trainNumber} - ${widget.trainName}', // Display fetched train name prominently
              style: GoogleFonts.roboto(fontSize: 14, color: Colors.white70),
            ),
          ],
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
      body: Stack( // Use Stack to layer content and loading overlay
        children: [
          Form(
            key: _formKey,
            child: Column( // Column to hold Header, PageView and submit button
              children: [
                // --- Header Selector for Coaches and Sections ---
                FadeInDown(
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    height: 60, // Fixed height for the header
                    color: Colors.blue.shade50, // Light background for the header
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemCount: _headerItems.length,
                      itemBuilder: (context, index) {
                        final headerItem = _headerItems[index];
                        final bool isSelected = (_currentPage >= headerItem['startIndex'] &&
                                                 _currentPage < headerItem['endIndex']);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0), // Reduced horizontal padding
                          child: ElevatedButton(
                            onPressed: () {
                              _pageController.animateToPage(
                                headerItem['startIndex'],
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected ? Colors.blueAccent : Colors.white,
                              foregroundColor: isSelected ? Colors.white : Colors.blueGrey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected ? Colors.blue.shade800 : Colors.blueGrey.shade200,
                                  width: 1.5,
                                ),
                              ),
                              elevation: isSelected ? 8 : 2,
                              shadowColor: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(horizontal: 8.0), // Reduced horizontal padding
                            ),
                            child: Text(
                              headerItem['title'], // Display the title from headerItems
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10), // Spacer below the header selector
                Expanded( // PageView takes available space
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _allPages.length, // Total number of pages
                    clipBehavior: Clip.none, // Allow children to draw outside bounds for shadows
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      PageInfo currentPageInfo = _allPages[index];
                      // Apply a scale transformation for the "jaw-dropping" effect
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double value = 1.0;
                          if (_pageController.position.haveDimensions) {
                            value = _pageController.page! - index;
                            value = (1 - (value.abs() * 0.2)).clamp(0.8, 1.0); // Scale factor
                          }
                          return Center(
                            child: SizedBox(
                              height: Curves.easeOut.transform(value) * MediaQuery.of(context).size.height * 0.7, // Adjust height
                              width: Curves.easeOut.transform(value) * MediaQuery.of(context).size.width * 0.9, // Adjust width
                              child: Transform.scale(
                                scale: value,
                                child: SingleChildScrollView( // Each page can scroll its content
                                  padding: const EdgeInsets.all(16.0),
                                  child: _buildSection(context, currentPageInfo),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                // Page indicators (now numbers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 80.0, top: 10.0), // Adjust padding for FAB
                  child: Text(
                    '${_currentPage + 1}/${_allPages.length}', // Display current page out of total
                    style: GoogleFonts.roboto(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Lottie Loading Overlay
          if (_showLottieLoading)
            Container(
              color: Colors.black54, // Semi-transparent black background
              child: Center(
                child: Lottie.asset(
                  'assets/done_train.json', // Your Lottie animation file
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  repeat: true, // Repeat animation while loading
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                onPressed: _submitTrainInspection,
                icon: const Icon(Icons.send, color: Colors.white),
                label: Text(
                  'Submit Inspection',
                  style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.white,
                  elevation: 10,
                  shadowColor: Colors.black.withOpacity(0.4),
                  animationDuration: const Duration(milliseconds: 300),
                ),
              ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, PageInfo pageInfo) {
    List<Widget> sectionWidgets = [];

    // Section Header
    sectionWidgets.add(
      FadeInDown( // Added FadeInDown animation
        duration: const Duration(milliseconds: 600),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
          margin: const EdgeInsets.only(bottom: 20.0, top: 10.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE0F2F7), Color(0xFFB3E5FC)], // Light blue gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withOpacity(0.4),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.blueAccent.shade100, width: 1),
          ),
          child: Row(
            children: [
              Icon(
                _getSectionIcon(pageInfo.sectionName),
                color: const Color(0xFF1A237E), // Deep blue icon
                size: 32,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  pageInfo.coachId != null
                      ? '${pageInfo.coachId}: ${pageInfo.sectionName}'
                      : pageInfo.sectionName,
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A237E), // Deep blue text
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (pageInfo.type == 'train_details') {
      // Display Train Name prominently here
      sectionWidgets.add(
        FadeInUp(
          duration: const Duration(milliseconds: 400),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            margin: const EdgeInsets.only(bottom: 16.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.train, color: Color(0xFF1976D2), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Train: ${widget.trainName}',
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A237E),
                        ),
                      ),
                      Text(
                        'Number: ${widget.trainNumber}',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      sectionWidgets.add(
        FadeInUp(
          duration: const Duration(milliseconds: 500),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            margin: const EdgeInsets.only(bottom: 16.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextFormField(
              controller: TextEditingController(text: widget.trainNumber), // Display from widget, read-only
              readOnly: true, // Train number is read-only here
              decoration: InputDecoration(
                labelText: 'Train Number',
                hintText: 'e.g., 12631',
                border: InputBorder.none,
                labelStyle: GoogleFonts.roboto(color: Colors.blueGrey),
                hintStyle: GoogleFonts.roboto(color: Colors.grey),
                prefixIcon: const Icon(Icons.numbers, color: Color(0xFF1976D2)),
              ),
              style: GoogleFonts.roboto(fontSize: 16, color: Colors.black87),
            ),
          ),
        ),
      );
      sectionWidgets.add(
        FadeInUp(
          duration: const Duration(milliseconds: 600),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            margin: const EdgeInsets.only(bottom: 16.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            // child: TextFormField(
            //   controller: _coachNumberController, // Coach number is editable here
            //   decoration: InputDecoration(
            //     labelText: 'Overall Inspection Coach Number *', // Clarified label
            //     hintText: 'e.g., S1, B3, A2 (for the coach being focused on)',
            //     border: InputBorder.none,
            //     labelStyle: GoogleFonts.roboto(color: Colors.blueGrey),
            //     hintStyle: GoogleFonts.roboto(color: Colors.grey),
            //     prefixIcon: const Icon(Icons.subtitles, color: Color(0xFF1976D2)),
            //   ),
            //   validator: (value) {
            //     if (value == null || value.isEmpty) {
            //       return 'Overall Inspection Coach Number is required';
            //     }
            //     return null;
            //   },
            //   style: GoogleFonts.roboto(fontSize: 16, color: Colors.black87),
            // ),
          ),
        ),
      );
      sectionWidgets.add(
        FadeInUp(
          duration: const Duration(milliseconds: 700),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            margin: const EdgeInsets.only(bottom: 16.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date of Inspection',
                  border: InputBorder.none,
                  labelStyle: GoogleFonts.roboto(color: Colors.blueGrey),
                  prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF1976D2)),
                ),
                baseStyle: GoogleFonts.roboto(fontSize: 16, color: Colors.black87),
                child: Text(
                  DateFormat('dd MMMMyyyy').format(_inspectionDate),
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else if (pageInfo.type == 'coach_section') {
      final String coachId = pageInfo.coachId!;
      final String sectionName = pageInfo.sectionName;
      final List<String> parameterNames = _coachSpecificSections[sectionName]!;

      for (var parameterName in parameterNames) {
        String fullParamKey = '${coachId}_${sectionName.replaceAll(' ', '_')}_${parameterName.replaceAll(' ', '_')}';
        final int currentMarks = _inspectionParameters[fullParamKey]?['marks'] ?? 0;
        final String currentRemarks = _inspectionParameters[fullParamKey]?['remarks'] ?? '';
        final bool noFeedback = _inspectionParameters[fullParamKey]?['noFeedback'] ?? false;

        sectionWidgets.add(
          _CustomScoreInputField(
            activityTitle: parameterName,
            initialMarks: currentMarks,
            initialRemarks: currentRemarks,
            initialNoFeedback: noFeedback,
            onMarksChanged: (newValue) => _updateParameterMarks(fullParamKey, newValue),
            onRemarksChanged: (newRemarks) => _updateParameterRemarks(fullParamKey, newRemarks),
            onNoFeedbackChanged: (value) => _updateParameterNoFeedback(fullParamKey, value),
          ),
        );
      }
    } else if (pageInfo.type == 'general_section') {
      final String sectionName = pageInfo.sectionName;
      final List<String> parameterNames = _generalSections[sectionName]!;

      for (var parameterName in parameterNames) {
        String fullParamKey = 'General_${sectionName.replaceAll(' ', '_')}_${parameterName.replaceAll(' ', '_')}';
        final int currentMarks = _inspectionParameters[fullParamKey]?['marks'] ?? 0;
        final String currentRemarks = _inspectionParameters[fullParamKey]?['remarks'] ?? '';
        final bool noFeedback = _inspectionParameters[fullParamKey]?['noFeedback'] ?? false;

        sectionWidgets.add(
          _CustomScoreInputField(
            activityTitle: parameterName,
            initialMarks: currentMarks,
            initialRemarks: currentRemarks,
            initialNoFeedback: noFeedback,
            onMarksChanged: (newValue) => _updateParameterMarks(fullParamKey, newValue),
            onRemarksChanged: (newRemarks) => _updateParameterRemarks(fullParamKey, newRemarks),
            onNoFeedbackChanged: (value) => _updateParameterNoFeedback(fullParamKey, value),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sectionWidgets,
    );
  }
}

// --- Start of _CustomScoreInputField ---
class _CustomScoreInputField extends StatefulWidget {
  final String activityTitle;
  final int initialMarks;
  final String initialRemarks;
  final bool initialNoFeedback; // New parameter for no feedback
  final ValueChanged<int> onMarksChanged;
  final ValueChanged<String> onRemarksChanged;
  final ValueChanged<bool> onNoFeedbackChanged; // New callback for no feedback

  const _CustomScoreInputField({
    required this.activityTitle,
    required this.initialMarks,
    required this.initialRemarks,
    required this.initialNoFeedback, // Required
    required this.onMarksChanged,
    required this.onRemarksChanged,
    required this.onNoFeedbackChanged, // Required
  });

  @override
  State<_CustomScoreInputField> createState() => _CustomScoreInputFieldState();
}

class _CustomScoreInputFieldState extends State<_CustomScoreInputField> {
  late int _currentMarks;
  late TextEditingController _remarksController;
  late bool _noFeedbackSelected; // State for the checkbox

  @override
  void initState() {
    super.initState();
    _currentMarks = widget.initialMarks;
    _remarksController = TextEditingController(text: widget.initialRemarks);
    _noFeedbackSelected = widget.initialNoFeedback; // Initialize from widget
  }

  @override
  void didUpdateWidget(covariant _CustomScoreInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMarks != oldWidget.initialMarks) {
      _currentMarks = widget.initialMarks;
    }
    if (widget.initialRemarks != oldWidget.initialRemarks) {
      _remarksController.text = widget.initialRemarks;
    }
    if (widget.initialNoFeedback != oldWidget.initialNoFeedback) {
      _noFeedbackSelected = widget.initialNoFeedback;
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      child: Card(
        elevation: 8,
        margin: const EdgeInsets.only(bottom: 20.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.activityTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 15),
                // No Feedback Checkbox
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'No Feedback',
                        style: GoogleFonts.roboto(fontSize: 16, color: Colors.blueGrey[700]),
                      ),
                    ),
                    Switch(
                      value: _noFeedbackSelected,
                      onChanged: (bool value) {
                        setState(() {
                          _noFeedbackSelected = value;
                          widget.onNoFeedbackChanged(value); // Notify parent
                          if (value) {
                            // If no feedback selected, reset marks and remarks
                            _currentMarks = 0;
                            _remarksController.text = 'No feedback provided';
                            widget.onMarksChanged(_currentMarks);
                            widget.onRemarksChanged(_remarksController.text);
                          } else {
                            // If no feedback deselected, clear remarks if it was "No feedback provided"
                            if (_remarksController.text == 'No feedback provided') {
                              _remarksController.clear();
                              widget.onRemarksChanged('');
                            }
                          }
                        });
                      },
                      activeColor: Colors.redAccent,
                      inactiveTrackColor: Colors.grey[300],
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // Rating Slider (conditionally enabled)
                IgnorePointer(
                  ignoring: _noFeedbackSelected, // Disable if no feedback selected
                  child: Opacity(
                    opacity: _noFeedbackSelected ? 0.4 : 1.0, // Visually disable
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Marks: ${_currentMarks.round()}', // Display current marks
                          style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.blueAccent,
                              inactiveTrackColor: Colors.blueAccent.withOpacity(0.3),
                              thumbColor: Colors.blue.shade800,
                              overlayColor: Colors.blue.shade200.withOpacity(0.2),
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24.0),
                              valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                              valueIndicatorColor: Colors.blue.shade800,
                              valueIndicatorTextStyle: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: Slider(
                              value: _currentMarks.toDouble(),
                              min: 0,
                              max: 10,
                              divisions: 10, // Allows integer steps from 0 to 10
                              label: _currentMarks.round().toString(),
                              onChanged: (double newValue) {
                                setState(() {
                                  _currentMarks = newValue.round();
                                  widget.onMarksChanged(_currentMarks);
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Remarks TextField (conditionally enabled)
                IgnorePointer(
                  ignoring: _noFeedbackSelected, // Disable if no feedback selected
                  child: Opacity(
                    opacity: _noFeedbackSelected ? 0.4 : 1.0, // Visually disable
                    child: TextField(
                      controller: _remarksController,
                      decoration: InputDecoration(
                        hintText: _noFeedbackSelected ? 'No feedback provided' : 'Remarks (Optional)',
                        hintStyle: GoogleFonts.roboto(color: Colors.grey[600]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.blue.shade50,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 18.0),
                        prefixIcon: Icon(Icons.edit_note, color: Colors.blueGrey[700]),
                      ),
                      maxLines: 3,
                      onChanged: widget.onRemarksChanged,
                      readOnly: _noFeedbackSelected, // Make read-only if no feedback is selected
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
