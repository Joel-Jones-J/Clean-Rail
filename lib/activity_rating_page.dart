import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For saving ratings
import 'package:firebase_auth/firebase_auth.dart'; // For getting current user ID

class ActivityRatingPage extends StatefulWidget {
  final String activityTitle;
  final String trainNumber;
  final int initialMarks; // New: to receive initial marks
  final String initialRemarks; // New: to receive initial remarks

  const ActivityRatingPage({
    super.key,
    required this.activityTitle,
    required this.trainNumber,
    this.initialMarks = 0, // Default to 0 if not provided
    this.initialRemarks = '', // Default to empty if not provided
  });

  @override
  State<ActivityRatingPage> createState() => _ActivityRatingPageState();
}

class _ActivityRatingPageState extends State<ActivityRatingPage> {
  late double _currentRating; // Use late as it will be initialized in initState
  late TextEditingController _remarksController; // Use late
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialMarks.toDouble(); // Initialize with initialMarks
    _remarksController = TextEditingController(text: widget.initialRemarks); // Initialize with initialRemarks
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Save rating to Firestore
      // Collection: 'train_inspections' (consistent with DashboardPage)
      // Document: trainNumber
      // Subcollection: 'activities'
      // Document: activityTitle (cleaned up for document ID)
      await FirebaseFirestore.instance
          .collection('train_inspections')
          .doc(widget.trainNumber)
          .collection('activities')
          .doc(widget.activityTitle.replaceAll(' ', '_').toLowerCase()) // Create a clean ID
          .set({
        'rating': _currentRating.toInt(), // Save as int
        'remarks': _remarksController.text.trim(), // Save remarks
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid, // Optional: store user ID
        'activityTitle': widget.activityTitle,
        'trainNumber': widget.trainNumber,
      }, SetOptions(merge: true)); // Use merge to update if exists, create if not

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rating for "${widget.activityTitle}" submitted successfully!')),
      );

      // Return the updated marks and remarks to the previous page
      Navigator.pop(context, {
        'marks': _currentRating.toInt(),
        'remarks': _remarksController.text.trim(),
      });
    } catch (e) {
      print("Error submitting rating: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit rating: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rate: ${widget.activityTitle}'),
        flexibleSpace: Container(
          // Gradient for a visually appealing app bar
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.lightBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        // Background gradient for the body
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFE3F2FD)], // Light blue background gradient
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.star_half, // A relevant icon for rating
                  size: 80,
                  color: Colors.amber[700], // Amber color for star
                ),
                const SizedBox(height: 20),
                Text(
                  'How would you rate the "${widget.activityTitle}" activity for Train ${widget.trainNumber}?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _currentRating.toStringAsFixed(1), // Display rating with one decimal
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange, // Highlight rating number
                        ),
                      ),
                      Slider(
                        value: _currentRating,
                        min: 0,
                        max: 10,
                        divisions: 100, // Allows for 0.1 increments
                        label: _currentRating.toStringAsFixed(1),
                        onChanged: (double value) {
                          setState(() {
                            _currentRating = value;
                          });
                        },
                        activeColor: Colors.deepOrangeAccent,
                        inactiveColor: Colors.deepOrangeAccent.withOpacity(0.3),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('0', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('10', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField( // Remarks field
                  controller: _remarksController,
                  decoration: InputDecoration(
                    hintText: 'Add your remarks (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.comment),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 30),
                _isSubmitting
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: _submitRating,
                        icon: const Icon(Icons.send),
                        label: const Text('Submit Rating'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30), // More rounded button
                          ),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          elevation: 8, // Add shadow for depth
                          shadowColor: Colors.blueAccent.withOpacity(0.5),
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
