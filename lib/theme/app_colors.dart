import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const primary = Color(0xFF2196F3);     // Material Blue
  static const secondary = Color(0xFF03A9F4);   // Light Blue
  static const accent = Color(0xFF4FC3F7);      // Lighter Blue
  static const background = Color(0xFFF5F5F5);  // Light Gray
  static const surface = Colors.white;
  static const error = Color(0xFFE53935);       // Error Red
  
  // Additional Colors
  static const success = Color(0xFF43A047);     // Success Green
  static const warning = Color(0xFFFFA000);     // Warning Orange
  static const info = Color(0xFF039BE5);        // Info Blue
  static const dark = Color(0xFF263238);        // Dark Blue Gray
  
  // Text Colors
  static const textPrimary = Color(0xFF212121);   // Dark Gray
  static const textSecondary = Color(0xFF757575); // Medium Gray
  static const textLight = Color(0xFFBDBDBD);     // Light Gray

  // Dashboard Colors
  static const dashboardCard1 = Color(0xFF2196F3);  // Blue
  static const dashboardCard2 = Color(0xFF00BCD4);  // Cyan
  static const dashboardCard3 = Color(0xFF3F51B5);  // Indigo
  static const dashboardCard4 = Color(0xFF673AB7);  // Deep Purple

  // Splash screen gradients
  static final splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1976D2),  // Deep Blue
      Color(0xFF2196F3),  // Material Blue
      Color(0xFF64B5F6),  // Light Blue
    ],
    stops: [0.0, 0.5, 1.0],
  );
  
  // Button gradients
  static final gradientPrimary = LinearGradient(
    colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static final gradientAccent = LinearGradient(
    colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Card gradients
  static final gradientCard = LinearGradient(
    colors: [Colors.white, Color(0xFFF5F5F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dashboard gradients
  static final gradientDashboard1 = LinearGradient(
    colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final gradientDashboard2 = LinearGradient(
    colors: [Color(0xFF0097A7), Color(0xFF00BCD4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final gradientDashboard3 = LinearGradient(
    colors: [Color(0xFF303F9F), Color(0xFF3F51B5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final gradientDashboard4 = LinearGradient(
    colors: [Color(0xFF512DA8), Color(0xFF673AB7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Input field colors
  static const inputBackground = Color(0xFFF5F5F5);
  static const inputBorder = Color(0xFFE0E0E0);
  static const inputFocus = Color(0xFF2196F3);

  // Shadow colors
  static const shadowLight = Color(0x1A000000);
  static const shadowMedium = Color(0x33000000);
  static const shadowDark = Color(0x4D000000);
} 