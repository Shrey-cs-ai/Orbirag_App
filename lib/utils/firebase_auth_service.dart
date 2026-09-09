import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  FirebaseAuthService._internal();
  static final FirebaseAuthService instance = FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isLoggedIn => _auth.currentUser != null;

  // ==================== EMAIL/PASSWORD AUTH ====================

  /// Sign up with email and password
  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());
      await credential.user?.reload();
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Login with email and password
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Send password reset email
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ==================== SOCIAL AUTH ====================

  /// Sign in with Google
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return 'Google sign-in cancelled';
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      await _auth.signInWithCredential(credential);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    } catch (e) {
      return 'Google sign-in failed: $e';
    }
  }

  /// Sign in with GitHub
  Future<String?> signInWithGitHub() async {
    try {
      // IMPORTANT: Enable GitHub in Firebase Console first
      // Go to: Firebase Console → Authentication → Sign-in methods → GitHub
      // You need to register a GitHub OAuth app and add Client ID & Secret
      
      final provider = GithubAuthProvider();
      provider.addScope('read:user');
      provider.addScope('user:email');
      
      await _auth.signInWithProvider(provider);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    } catch (e) {
      return 'GitHub sign-in failed: $e';
    }
  }

  /// Sign in with LinkedIn (Custom Implementation)
  Future<String?> signInWithLinkedIn() async {
    // LinkedIn requires custom OAuth implementation
    // You can use packages like: linkedin_login
    return 'LinkedIn sign-in not configured. Please use Email, Google, or GitHub.';
  }

  // ==================== PROFILE MANAGEMENT ====================

  /// Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    final user = _auth.currentUser;
    if (user != null) {
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }
      await user.reload();
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ==================== ERROR HANDLING ====================

  /// Map Firebase errors to user-friendly messages
  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}