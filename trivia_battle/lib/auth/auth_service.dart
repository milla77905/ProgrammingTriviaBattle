import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  bool get isLoggedIn => _auth.currentUser != null;

  Future<User?> signInWithGoogle() async {
    try {
      print("Poskus prijave z Google...");

      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      final googleUser = await _googleSignIn.signIn();
      print("Google uporabnik: $googleUser");

      if (googleUser == null) {
        print("Uporabnik je preklical prijavo");
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      print("Firebase prijava uspešna: ${userCredential.user?.email}");
      print("Uporabnik ID: ${userCredential.user?.uid}");

      return userCredential.user;
    } catch (e) {
      print("Napaka pri Google prijavi: $e");

      if (e.toString().contains('already signed-in')) {
        print("Uporabnik je že prijavljen, odjavljam...");
        await signOut();
        return await signInWithGoogle();
      }

      return null;
    }
  }

  Future<void> signOut() async {
    try {
      print("Začenjam odjavo...");

      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
        print("Odjava iz Google uspešna");
      }

      await _auth.signOut();
      print("Odjava iz Firebase uspešna");

      print("Odjava zaključena");
    } catch (e) {
      print("Napaka pri odjavi: $e");
      rethrow;
    }
  }
}
