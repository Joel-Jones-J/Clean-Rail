import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lottie/lottie.dart'; // Import lottie package
import 'home_page.dart'; // Import the new HomePage

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final auth = FirebaseAuth.instance;
  bool _showLoadingOverlay = false; // Controls visibility of the Lottie overlay

  Future<void> login() async {
    setState(() {
      _showLoadingOverlay = true; // Show Lottie overlay
    });

    bool loginSuccess = false; // Flag to track login success
    try {
      await auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      loginSuccess = true; // Set flag to true on successful login
    } catch (e) {
      if (mounted) { // Check if the widget is still in the tree before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      // Ensure the Lottie animation plays for a minimum duration
      // Adjust this duration (e.g., 2 seconds) to match the length of your Lottie animation.
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _showLoadingOverlay = false; // Hide Lottie overlay
      });

      // Navigate only if login was successful and the widget is still mounted
      if (loginSuccess && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack( // Use Stack to layer the login content and the loading overlay
        children: <Widget>[
          // Main Login Content
          SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Container(
                  height: 400,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/background.png'), // Ensure this asset exists
                      fit: BoxFit.fill,
                    ),
                  ),
                  child: Stack(
                    children: <Widget>[
                      Positioned(
                        left: 30,
                        width: 80,
                        height: 200,
                        child: FadeInUp(
                          duration: const Duration(seconds: 1),
                          child: Container(
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/light-1.png'), // Ensure this asset exists
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 140,
                        width: 80,
                        height: 150,
                        child: FadeInUp(
                          duration: const Duration(milliseconds: 1200),
                          child: Container(
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/light-2.png'), // Ensure this asset exists
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 40,
                        top: 40,
                        width: 80,
                        height: 150,
                        child: FadeInUp(
                          duration: const Duration(milliseconds: 1300),
                          child: Container(
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/clock.png'), // Ensure this asset exists
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        child: FadeInUp(
                          duration: const Duration(milliseconds: 1600),
                          child: Container(
                            margin: const EdgeInsets.only(top: 50),
                            child: const Center(
                              child: Text(
                                "Login",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    children: <Widget>[
                      FadeInUp(
                        duration: const Duration(milliseconds: 1800),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color.fromRGBO(143, 148, 251, 1),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(143, 148, 251, .2),
                                blurRadius: 20.0,
                                offset: Offset(0, 10),
                              )
                            ],
                          ),
                          child: Column(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.all(8.0),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Color.fromRGBO(143, 148, 251, 1),
                                    ),
                                  ),
                                ),
                                child: TextField(
                                  controller: emailController,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: "Email",
                                    hintStyle: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8.0),
                                child: TextField(
                                  controller: passwordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: "Password",
                                    hintStyle: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      FadeInUp(
                        duration: const Duration(milliseconds: 1900),
                        child: ElevatedButton(
                          onPressed: _showLoadingOverlay ? null : login, // Disable button while loading
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 10,
                            shadowColor: const Color.fromRGBO(143, 148, 251, .6),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                colors: [
                                  Color.fromRGBO(143, 148, 251, 1),
                                  Color.fromRGBO(143, 148, 251, .6),
                                ],
                              ),
                            ),
                            child: Container(
                              height: 50,
                              alignment: Alignment.center,
                              child: const Text(
                                "Login",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),

          // Lottie Loading Overlay
          if (_showLoadingOverlay)
            Container(
              color: Colors.black54, // Semi-transparent black background
              child: Center(
                child: Lottie.asset(
                  'assets/train_login.json', // Your Lottie animation file
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  repeat: false, // Play the animation only once
                ),
              ),
            ),
        ],
      ),
    );
  }
}
