import 'package:flutter/material.dart';
import 'dashboard_page.dart'; // Import your existing DashboardPage
import 'platform_page.dart'; // Import the PlatformPage
import 'pdf_page.dart'; // Import the PdfPage
import 'upload_train_data.dart'; // Import UploadTrainDataPage
import 'login_page.dart'; // Import LoginPage
import 'package:firebase_auth/firebase_auth.dart'; // For logout functionality

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Function to handle user logout
  void _logout(BuildContext context) async {
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
      extendBodyBehindAppBar: true, // Allows body to extend behind the app bar
      appBar: AppBar(
        title: const Text(
          'Indian Railways Portal', // More thematic title
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 26, // Slightly larger title
            shadows: [
              Shadow(
                blurRadius: 8.0,
                color: Colors.black54,
                offset: Offset(2.0, 2.0),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent, // Make app bar transparent
        elevation: 0, // Remove app bar shadow
        centerTitle: true,
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
                'Indian Railways Menu', // Drawer title
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.alt_route, color: Colors.blueGrey),
              title: const Text(
                'Platform Management',
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
              leading: const Icon(Icons.directions_railway, color: Colors.blueGrey),
              title: const Text(
                'Train Operations',
                style: TextStyle(fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DashboardPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.blueGrey),
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
              onTap: () => _logout(context), // Call the logout function
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient - Indian Railways Blue & White Theme
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFFE3F2FD)], // Blue to very light blue/white
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 100), // More space for the app bar title and visual balance

                  // Platform Button
                  ThemedAnimatedButton(
                    title: 'Platform Management', // More descriptive title
                    imageUrl: 'assets/platform_view.png', // Asset image path
                    targetPage: const PlatformPage(),
                    gradientColors: const [Color(0xFF1976D2), Color(0xFF42A5F5)], // Deeper blue to lighter blue
                    icon: Icons.alt_route, // Icon for platform/route
                  ),
                  const SizedBox(height: 30),
                  // Train Button
                  ThemedAnimatedButton(
                    title: 'Train Operations', // More descriptive title
                    imageUrl: 'assets/train_interior.png', // Asset image path
                    targetPage: const DashboardPage(),
                    gradientColors: const [Color(0xFF0D47A1), Color(0xFF42A5F5)], // Even deeper blue to lighter blue
                    icon: Icons.directions_railway, // Icon for train
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// New Stateful Widget for the animated, themed buttons
class ThemedAnimatedButton extends StatefulWidget {
  final String title;
  final String imageUrl; // This will now be an asset path
  final Widget targetPage;
  final List<Color> gradientColors;
  final IconData icon;

  const ThemedAnimatedButton({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.targetPage,
    required this.gradientColors,
    required this.icon,
  });

  @override
  State<ThemedAnimatedButton> createState() => _ThemedAnimatedButtonState();
}

class _ThemedAnimatedButtonState extends State<ThemedAnimatedButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150), // Fast animation for tap feedback
      lowerBound: 0.95, // Scale down slightly on press
      upperBound: 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward(); // Scale down
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse(); // Scale back up
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => widget.targetPage),
    );
  }

  void _onTapCancel() {
    _controller.reverse(); // Scale back up if tap is cancelled
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4), // Darker shadow for more depth
                    spreadRadius: 4, // Increased spread
                    blurRadius: 15, // Increased blur
                    offset: const Offset(0, 8), // More pronounced shadow
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Background Image from assets
                    Image.asset( // Changed from Image.network to Image.asset
                      widget.imageUrl,
                      height: 220, // Slightly increased height for more presence
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 220,
                        width: double.infinity,
                        color: Colors.grey[300],
                        child: Center(
                          child: Text(
                            'Asset image not found for ${widget.title}\n(${widget.imageUrl})', // More informative error
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ),
                    ),
                    // Gradient Overlay for better text readability
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.gradientColors[0].withOpacity(0.8), // More opaque gradient
                              widget.gradientColors[1].withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    // Content (Icon and Text)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              widget.icon,
                              size: 70, // Larger icon
                              color: Colors.white,
                              shadows: const [
                                Shadow(
                                  blurRadius: 12.0, // More pronounced shadow
                                  color: Colors.black87,
                                  offset: Offset(3.0, 3.0),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15), // Increased spacing
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 30, // Larger font size
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    blurRadius: 12.0, // More pronounced shadow
                                    color: Colors.black87,
                                    offset: Offset(3.0, 3.0),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
