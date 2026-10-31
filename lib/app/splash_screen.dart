
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const Color _primary = Color(0xFF003F50);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Image(
                  image: AssetImage('assets/images/logo_medmais.png'),
                  fit: BoxFit.contain,
                  width: 360,
                ),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: 38,
                height: 38,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(_primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
