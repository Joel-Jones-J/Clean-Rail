import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

class UploadTrainDataPage extends StatefulWidget {
  const UploadTrainDataPage({super.key});

  @override
  State<UploadTrainDataPage> createState() => _UploadTrainDataPageState();
}

class _UploadTrainDataPageState extends State<UploadTrainDataPage> {
  final TextEditingController _trainNumberController = TextEditingController();
  final TextEditingController _trainNameController = TextEditingController();
  final TextEditingController _coachesController = TextEditingController(); // For Passenger train coaches
  final TextEditingController _urCoachesController = TextEditingController(); // For Express train UR coaches
  final TextEditingController _reservedCoachesController = TextEditingController(); // For Express train Reserved coaches

  // List to hold controllers for dynamically generated coach name text fields
  // This list will now store controllers for all coaches (UR then Reserved)
  final List<TextEditingController> _coachNameControllers = [];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>(); // Key for form validation
  bool _isUploading = false; // To show loading indicator

  String _selectedTrainType = 'Passenger'; // Default train type

  @override
  void dispose() {
    _trainNumberController.dispose();
    _trainNameController.dispose();
    _coachesController.dispose();
    _urCoachesController.dispose();
    _reservedCoachesController.dispose();
    for (var controller in _coachNameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Function to update the list of coach name controllers based on total coaches
  void _updateCoachNameControllers() {
    int totalCoaches = 0;
    if (_selectedTrainType == 'Express') {
      int ur = int.tryParse(_urCoachesController.text.trim()) ?? 0;
      int reserved = int.tryParse(_reservedCoachesController.text.trim()) ?? 0;
      totalCoaches = ur + reserved;
    }

    // Adjust the number of controllers to match totalCoaches
    // Dispose excess controllers
    while (_coachNameControllers.length > totalCoaches) {
      _coachNameControllers.removeLast().dispose();
    }
    // Add new controllers if needed
    while (_coachNameControllers.length < totalCoaches) {
      _coachNameControllers.add(TextEditingController());
    }
    setState(() {}); // Rebuild to show/hide coach name fields
  }

  Future<void> _uploadTrainData() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
      });

      try {
        final String trainNumber = _trainNumberController.text.trim();
        final String trainName = _trainNameController.text.trim();

        // Check for duplicate train name (excluding the current train if updating)
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('Train')
            .where('trainName', isEqualTo: trainName)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // If a document with this trainName exists AND its ID is different from the current trainNumber
          if (querySnapshot.docs.first.id != trainNumber) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Train with this name already exists!')),
            );
            setState(() {
              _isUploading = false;
            });
            return; // Stop upload
          }
        }

        Map<String, dynamic> trainData = {
          'trainNumber': trainNumber,
          'trainName': trainName,
          'trainType': _selectedTrainType,
          'timestamp': FieldValue.serverTimestamp(),
        };

        if (_selectedTrainType == 'Passenger') {
          final int coaches = int.tryParse(_coachesController.text.trim()) ?? 0;
          trainData['coaches'] = coaches;
          // Generate coach details for Passenger train (C1, C2, ...)
          Map<String, dynamic> coachDetails = {};
          for (int i = 1; i <= coaches; i++) {
            coachDetails['C$i'] = {}; // Empty map for future details
          }
          trainData['coachDetails'] = coachDetails;
        } else { // Express train
          final int urCoaches = int.tryParse(_urCoachesController.text.trim()) ?? 0;
          final int reservedCoaches = int.tryParse(_reservedCoachesController.text.trim()) ?? 0;
          trainData['urCoaches'] = urCoaches;
          trainData['reservedCoaches'] = reservedCoaches;

          // Collect coach names from dynamic text fields
          Map<String, dynamic> coachDetails = {};
          // First UR coaches
          for (int i = 0; i < urCoaches; i++) {
            final String coachName = _coachNameControllers[i].text.trim();
            coachDetails[coachName.isNotEmpty ? coachName : 'UR_Coach_${i + 1}'] = {};
          }
          // Then Reserved coaches
          for (int i = 0; i < reservedCoaches; i++) {
            final String coachName = _coachNameControllers[urCoaches + i].text.trim();
            coachDetails[coachName.isNotEmpty ? coachName : 'Reserved_Coach_${i + 1}'] = {};
          }
          trainData['coachDetails'] = coachDetails;
        }

        // Access Firestore instance
        FirebaseFirestore firestore = FirebaseFirestore.instance;

        // Save data to 'Train' collection with trainNumber as document ID
        await firestore.collection('Train').doc(trainNumber).set(trainData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Train data uploaded successfully!')),
        );

        // Clear the form fields after successful upload
        _trainNumberController.clear();
        _trainNameController.clear();
        _coachesController.clear();
        _urCoachesController.clear();
        _reservedCoachesController.clear();
        for (var controller in _coachNameControllers) {
          controller.clear();
        }
        setState(() {
          _coachNameControllers.clear(); // Clear dynamic controllers as well
        });

      } catch (e) {
        print("Error uploading train data: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload train data: $e')),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Train Data'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green, Colors.lightGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding( // Apply padding to the whole body
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Existing Train Data:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded( // Display existing data
              flex: 1, // Give it some flexible space
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('Train').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No train data available.'));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var trainDoc = snapshot.data!.docs[index];
                      Map<String, dynamic> trainData = trainDoc.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Train Number: ${trainData['trainNumber'] ?? 'N/A'}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Train Name: ${trainData['trainName'] ?? 'N/A'}',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 30), // Spacer between existing data and form
            Expanded( // Form takes available space
              flex: 2, // Give it more flexible space to accommodate inputs
              child: SingleChildScrollView( // Use SingleChildScrollView for scrollability on small screens
                padding: const EdgeInsets.all(8.0), // Inner padding for the form
                child: Form(
                  key: _formKey, // Assign the form key
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.train, // Changed icon to a more relevant one
                        size: 100,
                        color: Colors.green[700],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Enter new train details:',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 30),
                      TextFormField(
                        controller: _trainNumberController,
                        decoration: InputDecoration(
                          labelText: 'Train Number',
                          hintText: 'e.g., 12345',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.confirmation_number),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a train number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _trainNameController,
                        decoration: InputDecoration(
                          labelText: 'Train Name',
                          hintText: 'e.g., Express Train',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.subtitles),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a train name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      // Train Type Selection
                      DropdownButtonFormField<String>(
                        value: _selectedTrainType,
                        decoration: InputDecoration(
                          labelText: 'Train Type',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.category),
                        ),
                        items: <String>['Passenger', 'Express']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedTrainType = newValue!;
                            // Clear coach related fields when type changes
                            _coachesController.clear();
                            _urCoachesController.clear();
                            _reservedCoachesController.clear();
                            for (var controller in _coachNameControllers) {
                              controller.dispose(); // Dispose old controllers
                            }
                            _coachNameControllers.clear(); // Clear the list
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Conditional input fields based on train type
                      if (_selectedTrainType == 'Passenger') ...[
                        TextFormField(
                          controller: _coachesController,
                          decoration: InputDecoration(
                            labelText: 'Number of Coaches (C1 to Cn)',
                            hintText: 'e.g., 10',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.directions_railway),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the number of coaches';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ] else if (_selectedTrainType == 'Express') ...[
                        TextFormField(
                          controller: _urCoachesController,
                          decoration: InputDecoration(
                            labelText: 'Number of UR (Unreserved) Coaches',
                            hintText: 'e.g., 5',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.person),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _updateCoachNameControllers(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter number of UR coaches';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _reservedCoachesController,
                          decoration: InputDecoration(
                            labelText: 'Number of Reserved Coaches',
                            hintText: 'e.g., 5',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.event_seat),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _updateCoachNameControllers(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter number of reserved coaches';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        if (_coachNameControllers.isNotEmpty)
                          const Text(
                            'Enter Coach Names:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        const SizedBox(height: 10),
                        // Dynamically generated coach name text fields
                        ..._coachNameControllers.asMap().entries.map((entry) {
                          int idx = entry.key;
                          TextEditingController controller = entry.value;
                          int urCoachesCount = int.tryParse(_urCoachesController.text.trim()) ?? 0;
                          String coachTypeLabel = idx < urCoachesCount ? 'UR Coach' : 'Reserved Coach';
                          int coachNumber = idx < urCoachesCount ? idx + 1 : idx - urCoachesCount + 1;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 15.0),
                            child: TextFormField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: '$coachTypeLabel $coachNumber Name',
                                hintText: 'e.g., A1, S1, B1',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: const Icon(Icons.edit_note),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a name for $coachTypeLabel $coachNumber';
                                }
                                return null;
                              },
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 30),
                      _isUploading
                          ? const CircularProgressIndicator() // Show loading indicator while uploading
                          : ElevatedButton.icon(
                              onPressed: _uploadTrainData,
                              icon: const Icon(Icons.cloud_upload), // Changed icon to upload
                              label: const Text('Upload Train Data'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 5,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
