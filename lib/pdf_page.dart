import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart'; // For animations
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore
import 'package:pdf/pdf.dart'; // For PDF generation
import 'package:pdf/widgets.dart' as pw; // For PDF widgets
import 'package:flutter/foundation.dart'; // For kIsWeb (though its usage for web-specific download is removed)
import 'package:firebase_auth/firebase_auth.dart'; // For logout functionality
import 'package:intl/intl.dart'; // For DateFormat
import 'dart:io'; // For File operations on mobile
import 'package:path_provider/path_provider.dart'; // For getting directory paths
import 'package:permission_handler/permission_handler.dart'; // For requesting permissions
import 'package:open_filex/open_filex.dart'; // For opening files on mobile/desktop

// Import your existing pages for navigation
import 'platform_page.dart';
import 'dashboard_page.dart';
import 'upload_train_data.dart'; // Import UploadTrainDataPage
import 'login_page.dart'; // Import LoginPage

class PdfPage extends StatefulWidget {
  const PdfPage({super.key});

  @override
  State<PdfPage> createState() => _PdfPageState();
}

class _PdfPageState extends State<PdfPage> {
  bool _isGeneratingPdf = false;
  String? _statusMessage;

  // Function to show a custom input dialog
  Future<String?> _showInputDialog(
      BuildContext context, {
        required String title,
        required String labelText,
        required String hintText,
        TextInputType keyboardType = TextInputType.text,
      }) async {
    final TextEditingController controller = TextEditingController();
    String? errorMessage;

    return await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return FadeInDown( // Animation for the dialog
              duration: const Duration(milliseconds: 300),
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(
                  title,
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFF1A237E)),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      decoration: InputDecoration(
                        labelText: labelText,
                        hintText: hintText,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        errorText: errorMessage,
                      ),
                    ),
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          errorMessage!,
                          style: GoogleFonts.roboto(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(null); // Return null on cancel
                    },
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.roboto(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isEmpty) {
                        setState(() {
                          errorMessage = 'This field cannot be empty.';
                        });
                      } else {
                        Navigator.of(dialogContext).pop(controller.text.trim());
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Submit',
                      style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Function to generate and download PDF
  Future<void> _generateAndDownloadPdf(pw.Document pdf, String filename) async {
    try {
      final bytes = await pdf.save();

      // Mobile/Desktop download and open logic
      Directory? directory;
      String message = 'PDF saved to app documents directory.';
      Color messageColor = Colors.green;
      String? filePath;

      // Request storage permission for Android
      if (Theme.of(context).platform == TargetPlatform.android) {
        var status = await Permission.storage.request();
        if (status.isGranted) {
          directory = await getDownloadsDirectory(); // Try to get Downloads directory
          if (directory != null) {
            message = 'PDF saved to Downloads folder.';
          } else {
            directory = await getApplicationDocumentsDirectory(); // Fallback
            message = 'PDF saved to app documents directory (Downloads not accessible).';
          }
        } else {
          directory = await getApplicationDocumentsDirectory(); // Fallback if permission denied
          message = 'Storage permission denied. PDF saved to app documents directory.';
          messageColor = Colors.orange;
        }
      } else {
        // For iOS, Linux, MacOS, Windows, try Downloads first, then app documents
        directory = await getDownloadsDirectory();
        if (directory != null) {
          message = 'PDF saved to Downloads folder.';
        } else {
          directory = await getApplicationDocumentsDirectory(); // Fallback
          message = 'PDF saved to app documents directory (Downloads not accessible).';
        }
      }

      final file = File('${directory.path}/$filename.pdf');
      await file.writeAsBytes(bytes);
      filePath = file.path;
      _showStatusMessage(message, messageColor);

      // Attempt to open the file
      // ignore: unnecessary_null_comparison
      if (filePath != null) {
        final result = await OpenFilex.open(filePath);
        if (result.type == ResultType.done) {
          _showStatusMessage('PDF opened successfully!', Colors.green);
        } else {
          _showStatusMessage('Failed to open PDF: ${result.message}', Colors.red);
        }
      }
        } catch (e) {
      _showStatusMessage('Error generating PDF: $e', Colors.red);
      print('Error generating PDF: $e');
    }
  }

  void _showStatusMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Function to handle Station Reports
  Future<void> _handleStationReports() async {
    final stationName = await _showInputDialog(
      context,
      title: 'Enter Station Name',
      labelText: 'Station Name',
      hintText: 'e.g., Madurai',
    );

    if (stationName == null || stationName.isEmpty) {
      _showStatusMessage('Station name not provided.', Colors.orange);
      return;
    }

    setState(() {
      _isGeneratingPdf = true;
      _statusMessage = 'Fetching station data...';
    });

    try {
      // Fetch data from the 'station_data' collection
      final docSnapshot = await FirebaseFirestore.instance.collection('station_data').doc(stationName).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final pdf = pw.Document();

        // Extracting data with null checks
        final String stationReportName = data['stationName'] ?? 'N/A';
        final String inspectorId = data['inspectorId'] ?? 'N/A';
        final String category = data['category'] ?? 'N/A';

        // Format timestamps
        final String createdAt = data['createdAt'] != null
            ? DateFormat('dd MMM indelible HH:mm:ss').format((data['createdAt'] as Timestamp).toDate())
            : 'N/A';
        final String inspectionDate = data['inspectionDate'] != null
            ? DateFormat('dd MMM indelible').format((data['inspectionDate'] as Timestamp).toDate())
            : 'N/A';
        final String lastUpdatedAt = data['lastUpdatedAt'] != null
            ? DateFormat('dd MMM indelible HH:mm:ss').format((data['lastUpdatedAt'] as Timestamp).toDate())
            : 'N/A';
        final String submittedAt = data['submittedAt'] != null
            ? DateFormat('dd MMM indelible HH:mm:ss').format((data['submittedAt'] as Timestamp).toDate())
            : 'N/A';
        final String submittedBy = data['submittedBy'] ?? 'N/A';


        List<pw.Widget> cleanlinessCriteriaWidgets = [];
        if (data['platform_cleanliness'] is Map) {
          final platformCleanliness = data['platform_cleanliness'] as Map<String, dynamic>;
          if (platformCleanliness['activities'] is Map) {
            final activities = platformCleanliness['activities'] as Map<String, dynamic>;

            activities.forEach((key, value) {
              if (value is Map<String, dynamic>) {
                final int marks = value['marks'] ?? 0;
                final String remarks = value['remarks'] ?? 'N/A';
                cleanlinessCriteriaWidgets.add(
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Criterion: $key',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Marks: $marks'),
                      pw.Text('Remarks: $remarks'),
                      pw.SizedBox(height: 10),
                    ],
                  ),
                );
              }
            });
          }
        }


        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Station Report: $stationReportName', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 20),
                  pw.Text('Inspector ID: $inspectorId'),
                  pw.Text('Category: $category'),
                  pw.Text('Inspection Date: $inspectionDate'),
                  pw.SizedBox(height: 10),
                  pw.Text('Created At: $createdAt'),
                  pw.Text('Last Updated At: $lastUpdatedAt'),
                  pw.Text('Submitted At: $submittedAt'),
                  pw.Text('Submitted By: $submittedBy'),
                  pw.SizedBox(height: 30),
                  pw.Text('Platform Cleanliness Details:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  ...cleanlinessCriteriaWidgets,
                ],
              );
            },
          ),
        );
        await _generateAndDownloadPdf(pdf, 'StationReport_${stationName.replaceAll(' ', '_')}');
      } else {
        _showStatusMessage('Station "$stationName" not found in database. Please check the name and try again.', Colors.red);
      }
    } catch (e) {
      _showStatusMessage('Error fetching station data: $e', Colors.red);
      print('Error fetching station data: $e');
    } finally {
      setState(() {
        _isGeneratingPdf = false;
      });
    }
  }

  // Function to handle Train Interior Reports
  Future<void> _handleTrainInteriorReports() async {
    final trainNumber = await _showInputDialog(
      context,
      title: 'Enter Train Number',
      labelText: 'Train Number',
      hintText: 'e.g., 12345',
      keyboardType: TextInputType.number,
    );

    if (trainNumber == null || trainNumber.isEmpty) {
      _showStatusMessage('Train number not provided.', Colors.orange);
      return;
    }

    setState(() {
      _isGeneratingPdf = true;
      _statusMessage = 'Fetching train data...';
    });

    try {
      final trainDoc = await FirebaseFirestore.instance.collection('Train').doc(trainNumber).get();

      if (!trainDoc.exists) {
        _showStatusMessage('Train number "$trainNumber" not found in Train collection.', Colors.red);
        setState(() {
          _isGeneratingPdf = false;
        });
        return;
      }

      final trainName = trainDoc.data()?['trainName'] ?? 'Unknown Train';
      final documentId = '$trainNumber-${trainName.replaceAll(' ', '_')}';

      final inspectionDoc = await FirebaseFirestore.instance.collection('Train Interior').doc(documentId).get();

      if (inspectionDoc.exists) {
        final data = inspectionDoc.data() as Map<String, dynamic>;
        final pdf = pw.Document();

        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              List<pw.Widget> parameterWidgets = [];
              if (data['parameters'] is List) {
                for (var param in data['parameters']) {
                  if (param is Map<String, dynamic>) {
                    final String name = param['name'] ?? 'N/A';
                    final int marks = param['marks'] ?? 0;
                    final String remarks = param['remarks'] ?? 'N/A';
                    final bool noFeedback = param['noFeedback'] ?? false;

                    parameterWidgets.add(
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 5),
                          if (noFeedback)
                            pw.Text('Status: No Feedback Provided', style: pw.TextStyle(color: PdfColors.red)),
                          if (!noFeedback) ...[
                            pw.Text('Marks: $marks/10'),
                            pw.Text('Remarks: $remarks'),
                          ],
                          pw.SizedBox(height: 10),
                        ],
                      ),
                    );
                  }
                }
              }

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Train Interior Inspection Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 20),
                  pw.Text('Train Number: ${data['trainNumber'] ?? 'N/A'}'),
                  pw.Text('Train Name: ${data['trainName'] ?? 'N/A'}'),
                  pw.Text('Inspection Coach: ${data['inspectionCoach'] ?? 'N/A'}'),
                  pw.Text('Inspection Date: ${data['inspectionDate'] != null ? DateFormat('dd MMM indelible').format((data['inspectionDate'] as Timestamp).toDate()) : 'N/A'}'),
                  pw.Text('Inspector ID: ${data['inspectorId'] ?? 'N/A'}'),
                  pw.Text('Report Generated: ${data['timestamp'] != null ? DateFormat('dd MMM indelible HH:mm').format((data['timestamp'] as Timestamp).toDate()) : 'N/A'}'),
                  pw.SizedBox(height: 30),
                  pw.Text('Inspection Parameters:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  ...parameterWidgets,
                ],
              );
            },
          ),
        );
        await _generateAndDownloadPdf(pdf, 'TrainInteriorReport_$documentId');
      } else {
        _showStatusMessage('No inspection data found for Train "$trainNumber" ($trainName).', Colors.red);
      }
    } catch (e) {
      _showStatusMessage('Error fetching train inspection data: $e', Colors.red);
      print('Error fetching train inspection data: $e');
    } finally {
      setState(() {
        _isGeneratingPdf = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PDF Reports',
          style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
      drawer: Drawer( // Added Drawer
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
                // Already on PdfPage, so just close drawer or pushReplacement to self
                Navigator.pushReplacement(
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)], // Light blue to slightly darker light blue
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: _isGeneratingPdf
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      _statusMessage ?? 'Generating PDF...',
                      style: GoogleFonts.roboto(fontSize: 16, color: Colors.blueGrey),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Station Report Icon
                    _buildReportOption(
                      context,
                      icon: Icons.alt_route,
                      title: 'Station Reports',
                      onTap: _handleStationReports,
                      color: Colors.deepOrangeAccent,
                    ),
                    const SizedBox(height: 40),
                    // Train Interior Report Icon
                    _buildReportOption(
                      context,
                      icon: Icons.directions_railway,
                      title: 'Train Interior Reports',
                      onTap: _handleTrainInteriorReports,
                      color: Colors.teal,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildReportOption(BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: FadeInUp(
        duration: const Duration(milliseconds: 600),
        child: Card(
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7, // Responsive width
            padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  spreadRadius: 3,
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 80,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black54,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                        blurRadius: 8.0,
                        color: Colors.black54,
                        offset: Offset(1.0, 1.0),
                      ),
                    ],
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
