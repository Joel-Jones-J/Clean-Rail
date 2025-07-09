import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'login_page.dart'; // Import LoginPage for logout navigation
import 'package:collection/collection.dart'; // Import for firstWhereOrNull


class PlatformPage extends StatefulWidget {
  const PlatformPage({super.key});

  @override
  State<PlatformPage> createState() => _PlatformPageState();
}

class _PlatformPageState extends State<PlatformPage> {
  final TextEditingController _stationNameController = TextEditingController();
  DateTime _selectedDate = DateTime.now(); // Default to current date
  bool _isStationDetailsEntered = false;
  bool _isLoading = false;
  String? _errorMessage;

  // PageController for the main carousels
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;

  // Define the initial structure of platform inspection data
  // This will be used to create a fresh copy for new inspections
  final List<Map<String, dynamic>> _initialPlatformInspectionData = [
    {'category': 'Station Details', 'activities': []},
    {
      'category': 'Platform Cleanliness',
      'activities': [
        {'title': 'Platform Surface Cleanliness (free from litter, stains, etc.)', 'marks': 0, 'remarks': ''},
        {'title': 'Platform Drainage Cleanliness (free from blockage, standing waters)', 'marks': 0, 'remarks': ''},
        {'title': 'Seating Area Cleanliness (benches, waiting areas)', 'marks': 0, 'remarks': ''},
        {'title': 'Dustbin Cleanliness & Availability', 'marks': 0, 'remarks': ''},
        {'title': 'Station Signage and Display Board Cleanliness', 'marks': 0, 'remarks': ''},
      ]
    },
    {
      'category': 'Urinals & Toilets',
      'activities': [
        {'title': 'Urinal/Toilet Fixtures Cleanliness', 'marks': 0, 'remarks': ''},
        {'title': 'Floor & Wall Cleanliness in Urinals/Toilets', 'marks': 0, 'remarks': ''},
        {'title': 'Water Availability in Toilets, Flushing System Functionality', 'marks': 0, 'remarks': ''},
      ]
    },
    {
      'category': 'Water Booth',
      'activities': [
        {'title': 'Drinking Water Booth Cleanliness', 'marks': 0, 'remarks': ''},
        {'title': 'Water Filter/Cooler Cleanliness', 'marks': 0, 'remarks': ''},
        {'title': 'Water Quality (Visual Inspection)', 'marks': 0, 'remarks': ''},
      ]
    },
    {
      'category': 'Waiting Rooms',
      'activities': [
        {'title': 'Waiting Room Floor/Surface Cleanliness', 'marks': 0, 'remarks': ''},
        {'title': 'Seating Arrangement Cleanliness in Waiting Room', 'marks': 0, 'remarks': ''},
        {'title': 'Ventilation and Air Quality in Waiting Room', 'marks': 0, 'remarks': ''},
      ]
    },
    {
      'category': 'Subway / FOB',
      'activities': [
        {'title': 'FOB/Subway Floor Cleanliness', 'marks': 0, 'remarks': ''},
        {'title': 'Stairs/Ramps Cleanliness in FOB/Subway', 'marks': 0, 'remarks': ''},
        {'title': 'Lighting & Signage in FOB/Subway', 'marks': 0, 'remarks': ''},
      ]
    },
    {
      'category': 'Station Approach',
      'activities': [
        {'title': 'Approach Road Cleanliness', 'marks': 0, 'remarks': ''},
        {'title': 'Parking Area Cleanliness', 'marks': 0, 'remarks': ''},
        {'title': 'Gardens/Greenery Maintenance (if applicable)', 'marks': 0, 'remarks': ''},
      ]
    },
  ];

  // This list will hold the current state of the inspection data
  late List<Map<String, dynamic>> _platformInspectionData;

  @override
  void initState() {
    super.initState();
    _resetPlatformInspectionData(); // Initialize with fresh data on first load
  }

  // Helper function to create a deep copy of the initial data structure
  void _resetPlatformInspectionData() {
    _platformInspectionData = _initialPlatformInspectionData.map((categoryMap) {
      return {
        'category': categoryMap['category'],
        'activities': (categoryMap['activities'] as List<dynamic>).map((activityMap) {
          return Map<String, dynamic>.from(activityMap); // Ensure each activity is a Map<String, dynamic>
        }).toList(),
      };
    }).toList();
  }

  @override
  void dispose() {
    _stationNameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Function to select date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blueAccent, // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black87, // Body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueAccent, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Function to handle initial station details submission
  Future<void> _submitStationDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String stationName = _stationNameController.text.trim();
    if (stationName.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the Station Name.';
        _isLoading = false;
      });
      return;
    }

    try {
      // Check if station name already exists
      DocumentSnapshot stationDoc = await FirebaseFirestore.instance.collection('station_data').doc(stationName).get();

      if (stationDoc.exists) {
        // Load existing data if station exists
        Map<String, dynamic> existingData = stationDoc.data() as Map<String, dynamic>;
        print("Existing data for $stationName: $existingData");

        // Reset data first to ensure a clean slate before loading
        _resetPlatformInspectionData();

        // Iterate through _platformInspectionData categories (skipping 'Station Details')
        for (int i = 1; i < _platformInspectionData.length; i++) {
          String categoryKey = _platformInspectionData[i]['category'].replaceAll(' ', '_').toLowerCase();
          if (existingData.containsKey(categoryKey)) {
            final dynamic categoryDataFromFirestore = existingData[categoryKey]; // Get the whole category data

            if (categoryDataFromFirestore is Map<String, dynamic>) {
              final dynamic activitiesFromFirestore = categoryDataFromFirestore['activities'];

              List<Map<String, dynamic>> loadedActivities = [];

              if (activitiesFromFirestore is Map<String, dynamic>) {
                // This is the preferred structure (Map of activities)
                activitiesFromFirestore.forEach((key, value) {
                  if (value is Map<String, dynamic>) {
                    loadedActivities.add({
                      'title': value['name'] ?? key.replaceAll('_', ' '), // Use stored name or reconstruct
                      'marks': value['marks'] ?? 0,
                      'remarks': value['remarks'] ?? '',
                    });
                  }
                });
              } else if (activitiesFromFirestore is List<dynamic>) {
                // Handle legacy List<dynamic> structure
                for (var item in activitiesFromFirestore) {
                  if (item is Map<String, dynamic>) {
                    loadedActivities.add(Map<String, dynamic>.from(item)); // Explicitly cast
                  } else {
                    print("Warning: Non-Map item found in activities list for category '$categoryKey': $item");
                  }
                }
              } else {
                print("Warning: 'activities' for category '$categoryKey' is neither a Map nor a List in Firestore. It is ${activitiesFromFirestore.runtimeType}. Using default activities for this category.");
              }

              // Now, merge loaded activities with initial structure to ensure all expected activities are present
              List<Map<String, dynamic>> finalActivities = [];
              for (var initialActivity in _initialPlatformInspectionData[i]['activities']) {
                String initialTitle = initialActivity['title'];
                // Find if this activity was loaded from Firestore
                Map<String, dynamic>? foundLoadedActivity = loadedActivities.firstWhereOrNull(
                  (loaded) => loaded['title'] == initialTitle,
                );

                if (foundLoadedActivity != null) {
                  // Explicitly create a new Map<String, dynamic> from the found loaded activity
                  finalActivities.add(Map<String, dynamic>.from(foundLoadedActivity));
                } else {
                  // If not found, use a deep copy of the initial default
                  finalActivities.add(Map<String, dynamic>.from(initialActivity));
                }
              }
              // Assign the final list, ensuring its type is List<Map<String, dynamic>>
              _platformInspectionData[i]['activities'] = finalActivities;

            } else {
              print("Warning: Category data for '$categoryKey' is not a Map in Firestore. It is ${categoryDataFromFirestore.runtimeType}. Using default activities for this category.");
              // If category data itself is not a map, revert to initial defaults for this category
              _platformInspectionData[i]['activities'] = List<Map<String, dynamic>>.from(
                  _initialPlatformInspectionData[i]['activities'].map((act) => Map<String, dynamic>.from(act))
              );
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded existing data for Station "$stationName".')),
        );

      } else {
        // If station does not exist, proceed to create new entry
        _resetPlatformInspectionData(); // Ensure fresh data for new station

        await FirebaseFirestore.instance.collection('station_data').doc(stationName).set({
          'stationName': stationName,
          'inspectionDate': Timestamp.fromDate(_selectedDate),
          'inspectorId': FirebaseAuth.instance.currentUser?.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdatedAt': FieldValue.serverTimestamp(), // Set initial last update time
        }, SetOptions(merge: true)); // Use merge to avoid overwriting if partial data exists

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New Station "$stationName" created. Start inspection.')),
        );
      }

      setState(() {
        _isStationDetailsEntered = true; // Show carousel content
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error submitting station details: $e';
        _isLoading = false;
      });
      print("Error submitting station details: $e");
    }
  }

  // Function to submit data for the current carousel category
  Future<void> _submitCategoryData(int categoryIndex) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String stationName = _stationNameController.text.trim();
      final String category = _platformInspectionData[categoryIndex]['category'];
      final List<Map<String, dynamic>> activities = List<Map<String, dynamic>>.from(_platformInspectionData[categoryIndex]['activities']);

      // Prepare data for Firestore
      Map<String, dynamic> categoryData = {
        'category': category,
        'submittedAt': FieldValue.serverTimestamp(),
        'submittedBy': FirebaseAuth.instance.currentUser?.uid,
      };

      // Convert activities list to a map for easier Firestore storage
      Map<String, Map<String, dynamic>> activitiesMap = {};
      for (var activity in activities) {
        activitiesMap[activity['title'].replaceAll(' ', '_').toLowerCase()] = {
          'marks': activity['marks'],
          'remarks': activity['remarks'],
        };
      }
      categoryData['activities'] = activitiesMap;

      // Update the main station document with the new category data
      await FirebaseFirestore.instance.collection('station_data').doc(stationName).set(
        {
          category.replaceAll(' ', '_').toLowerCase(): categoryData, // Use category name as field key
          'lastUpdatedAt': FieldValue.serverTimestamp(), // Update last update time
        },
        SetOptions(merge: true), // Merge to update specific fields without overwriting others
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data for "$category" submitted successfully!')),
      );

      // Move to the next carousel page if not the last one
      if (categoryIndex < _platformInspectionData.length - 1) {
        _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeIn);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All inspection categories submitted!')),
        );
        // Optionally navigate back or show a completion screen
        Navigator.pop(context); // Go back to Home Page
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error submitting category data: $e';
        _isLoading = false;
      });
      print("Error submitting category data for $categoryIndex: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inspection Scorecard',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (_isStationDetailsEntered) // Only show if station details are entered
              Text(
                '${_stationNameController.text} - ${DateFormat('dd-MM-yyyy').format(_selectedDate)}',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          )
        ],
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
      body: _isStationDetailsEntered
          ? Column(
              children: [
                // Category Header matching the image style
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.white, // White background as in image
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.directions_railway, // Train icon as in image
                        color: Colors.blueGrey[700], // Darker blue-grey for icon
                        size: 30,
                      ),
                      const SizedBox(width: 10),
                      SlideInUp( // Animation for the category title
                        key: ValueKey(_currentPageIndex), // Key to trigger animation on page change
                        duration: const Duration(milliseconds: 400),
                        child: Text(
                          _platformInspectionData[_currentPageIndex + 1]['category'],
                          style: TextStyle(
                            fontSize: 24, // Slightly smaller than before but still prominent
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[800], // Dark blue-grey for text
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Top Navigation Tabs (Station Details, Platform Cleanliness, etc.)
                Container(
                  color: Colors.white, // White background for tabs
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _platformInspectionData.asMap().entries.map((entry) {
                        int idx = entry.key;
                        String categoryTitle = entry.value['category'];
                        bool isSelected = _currentPageIndex == idx - 1; // Adjust index for carousel vs data list

                        // If it's the "Station Details" tab, it's always the first one
                        if (idx == 0) {
                          isSelected = _currentPageIndex == -1; // Special case for initial screen
                        } else {
                          isSelected = _currentPageIndex == idx - 1;
                        }

                        return GestureDetector(
                          onTap: () {
                            if (idx == 0) {
                              // If tapping "Station Details" tab, go back to initial screen
                              setState(() {
                                _isStationDetailsEntered = false;
                                _stationNameController.clear();
                                _selectedDate = DateTime.now();
                                _currentPageIndex = 0; // Reset index
                              });
                            } else {
                              _pageController.animateToPage(
                                idx - 1, // Adjust for carousel index
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.ease,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blueAccent : Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blueAccent.withOpacity(isSelected ? 1.0 : 0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  idx == 0 ? Icons.info_outline : Icons.cleaning_services, // Example icons
                                  color: isSelected ? Colors.white : Colors.blueAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  categoryTitle,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.blueAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _platformInspectionData.length - 1, // Exclude the first 'Station Details' entry
                    onPageChanged: (index) {
                      setState(() {
                        _currentPageIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final categoryData = _platformInspectionData[index + 1]; // +1 to skip Station Details
                      final List<Map<String, dynamic>> activities = categoryData['activities'];

                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0), // Padding for the content of each page
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // List of ActivityInputCards for the current carousel
                            ...activities.asMap().entries.map((entry) {
                              int activityIndex = entry.key;
                              Map<String, dynamic> activity = entry.value;
                              return _ActivityRatingCard(
                                activityTitle: activity['title'],
                                initialMarks: activity['marks'],
                                initialRemarks: activity['remarks'],
                                onMarksChanged: (newMarks) {
                                  setState(() {
                                    activities[activityIndex]['marks'] = newMarks;
                                  });
                                },
                                onRemarksChanged: (newRemarks) {
                                  setState(() {
                                    activities[activityIndex]['remarks'] = newRemarks;
                                  });
                                },
                              );
                            }).toList(),
                            const SizedBox(height: 20),
                            // Submit button for the current category
                            SizedBox(
                              width: double.infinity,
                              child: _isLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : ElevatedButton.icon(
                                      onPressed: () => _submitCategoryData(index + 1), // Pass actual index
                                      icon: const Icon(Icons.send),
                                      label: Text('Submit ${categoryData['category']}'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 15),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        backgroundColor: Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        elevation: 5,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
          : SingleChildScrollView( // Added SingleChildScrollView here
              child: Container(
                // Initial screen for Station Name and Date of Inspection
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF42A5F5)], // Deep blue to light blue gradient
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FadeInDown(
                          duration: const Duration(milliseconds: 1000), // Increased duration
                          child: Icon(
                            Icons.location_city, // Icon for station
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
                        FadeInLeft(
                          duration: const Duration(milliseconds: 1200), // Increased duration
                          child: const Text(
                            'Start Platform Inspection',
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
                        FadeInRight(
                          duration: const Duration(milliseconds: 1400), // Increased duration
                          child: const Text(
                            'Please enter station details to begin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        FadeInUp(
                          duration: const Duration(milliseconds: 1600), // Increased duration
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
                            child: TextField(
                              controller: _stationNameController,
                              decoration: const InputDecoration(
                                labelText: 'Station Name',
                                hintText: 'e.g., Chennai Central',
                                border: InputBorder.none,
                                labelStyle: TextStyle(color: Colors.blueGrey),
                                hintStyle: TextStyle(color: Colors.grey),
                                prefixIcon: Icon(Icons.location_on, color: Colors.blueAccent),
                              ),
                              style: const TextStyle(fontSize: 18, color: Colors.black87),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeInUp(
                          duration: const Duration(milliseconds: 1800), // Increased duration
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
                            child: InkWell(
                              onTap: () => _selectDate(context),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date of Inspection',
                                  border: InputBorder.none,
                                  labelStyle: TextStyle(color: Colors.blueGrey),
                                  prefixIcon: Icon(Icons.calendar_today, color: Colors.blueAccent),
                                ),
                                baseStyle: const TextStyle(fontSize: 18, color: Colors.black87),
                                child: Text(
                                  DateFormat('dd-MM-yyyy').format(_selectedDate),
                                  style: const TextStyle(fontSize: 18, color: Colors.black87),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_errorMessage != null)
                          FadeInUp(
                            duration: const Duration(milliseconds: 1900), // Increased duration
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
                        FadeInUp(
                          duration: const Duration(milliseconds: 2000), // Increased duration
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : ElevatedButton.icon(
                                  onPressed: _submitStationDetails,
                                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                                  label: const Text(
                                    'Start Inspection',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
                        // Add some bottom padding to ensure content doesn't get cut off
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

// Reusable widget for individual activity rating
class _ActivityRatingCard extends StatefulWidget {
  final String activityTitle;
  final int initialMarks;
  final String initialRemarks;
  final ValueChanged<int> onMarksChanged;
  final ValueChanged<String> onRemarksChanged;

  const _ActivityRatingCard({
    required this.activityTitle,
    required this.initialMarks,
    required this.initialRemarks,
    required this.onMarksChanged,
    required this.onRemarksChanged,
  });

  @override
  State<_ActivityRatingCard> createState() => _ActivityRatingCardState();
}

class _ActivityRatingCardState extends State<_ActivityRatingCard> {
  late double _currentRating;
  late TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialMarks.toDouble();
    _remarksController = TextEditingController(text: widget.initialRemarks);
  }

  @override
  void didUpdateWidget(covariant _ActivityRatingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMarks != oldWidget.initialMarks) {
      _currentRating = widget.initialMarks.toDouble();
    }
    if (widget.initialRemarks != oldWidget.initialRemarks) {
      _remarksController.text = widget.initialRemarks;
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  void _incrementMarks() {
    setState(() {
      if (_currentRating < 10) {
        _currentRating++;
        widget.onMarksChanged(_currentRating.round());
      }
    });
  }

  void _decrementMarks() {
    setState(() {
      if (_currentRating > 0) {
        _currentRating--;
        widget.onMarksChanged(_currentRating.round());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeInUp( // Added FadeInUp for individual card animation
      duration: const Duration(milliseconds: 500), // Subtle animation for each card
      child: Card(
        elevation: 8, // Increased elevation for more depth
        margin: const EdgeInsets.only(bottom: 20.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Container( // Added Container for gradient background
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [Colors.blue.shade50!, Colors.blue.shade100!], // Subtle blue gradient
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
                  style: const TextStyle(
                    fontSize: 20, // Slightly larger title
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E), // Deep blue for title
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Marks:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white, // White background for marks counter
                        borderRadius: BorderRadius.circular(25), // More rounded
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 28), // Thematic icon
                            onPressed: _decrementMarks,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8), // Add padding for touch target
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15.0), // Increased padding
                            child: Text(
                              _currentRating.round().toString(), // Display rounded integer
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)), // Deep blue for marks
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 28), // Thematic icon
                            onPressed: _incrementMarks,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8), // Add padding for touch target
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20), // Increased spacing
                TextField(
                  controller: _remarksController,
                  decoration: InputDecoration(
                    hintText: 'Remarks (Optional)',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), // More rounded corners
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.blue.shade50, // Light blue fill for remarks
                    contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 18.0),
                    prefixIcon: Icon(Icons.edit_note, color: Colors.blueGrey[700]), // Icon for remarks
                  ),
                  maxLines: 3,
                  onChanged: widget.onRemarksChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
