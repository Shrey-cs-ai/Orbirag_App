class Validators {
  Validators._();

  static final RegExp _emailRegex =
      RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
  static final RegExp _uppercaseRegex = RegExp(r'[A-Z]');
  static final RegExp _lowercaseRegex = RegExp(r'[a-z]');
  static final RegExp _numberRegex = RegExp(r'[0-9]');
  static final RegExp _specialRegex =
      RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]');

  // ============================================================
  // Email
  // ============================================================
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  // ============================================================
  // Strong Password
  // ============================================================
  static String? password(String? value, {int minLength = 8}) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    if (!_uppercaseRegex.hasMatch(value)) {
      return 'Add at least one uppercase letter (A-Z)';
    }
    if (!_lowercaseRegex.hasMatch(value)) {
      return 'Add at least one lowercase letter (a-z)';
    }
    if (!_numberRegex.hasMatch(value)) {
      return 'Add at least one number (0-9)';
    }
    if (!_specialRegex.hasMatch(value)) {
      return 'Add at least one special character (!@#\$%^&*...)';
    }
    return null;
  }

  // ============================================================
  // Password Strength Score (0 = weak, 4 = strong)
  // ============================================================
  static int passwordStrength(String value) {
    int score = 0;
    if (value.length >= 8) score++;
    if (_uppercaseRegex.hasMatch(value)) score++;
    if (_numberRegex.hasMatch(value)) score++;
    if (_specialRegex.hasMatch(value)) score++;
    return score;
  }

  static String passwordStrengthLabel(int score) {
    switch (score) {
      case 0:
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      default:
        return 'Strong';
    }
  }

  // ============================================================
  // Confirm Password
  // ============================================================
  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  // ============================================================
  // Name
  // ============================================================
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Enter a valid name';
    return null;
  }
}