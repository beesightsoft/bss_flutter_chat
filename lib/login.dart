import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bss_chat/const.dart';
import 'package:flutter_bss_chat/main.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BSS chat',
      theme: new ThemeData(
        primaryColor: themeColor,
      ),
      home: LoginScreen(title: 'BSS CHAT'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginScreen extends StatefulWidget {
  LoginScreen({Key key, this.title}) : super(key: key);

  final String title;

  @override
  LoginScreenState createState() => new LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn googleSignIn = new GoogleSignIn();
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

  final TextEditingController emailEditingController = new TextEditingController();
  final TextEditingController passwordEditingController = new TextEditingController();

  SharedPreferences prefs;

  bool isLoading = false;
  bool isLoggedIn = false;
  FirebaseUser currentUser;

  @override
  void initState() {
    super.initState();
    isSignedIn();
  }

  void isSignedIn() async {
    this.setState(() {
      isLoading = true;
    });

    prefs = await SharedPreferences.getInstance();

    // Check login with google
    isLoggedIn = await googleSignIn.isSignedIn();
    if (isLoggedIn) {
      Fluttertoast.showToast(msg: "Log in with google success");
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MainScreen(currentUserId: prefs.getString('id'))),
      );
    }

    // Check login with email
    firebaseAuth.currentUser().then((firebaseUser) {
      if (firebaseUser != null) {
        Fluttertoast.showToast(msg: "Log in with email success");
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MainScreen(currentUserId: prefs.getString('id'))),
        );
      }
    });

    this.setState(() {
      isLoading = false;
    });
  }

  // 0 = Google, 1 = email
  Future handleSignIn(int typeSignIn) async {
    this.setState(() {
      isLoading = true;
    });

    switch (typeSignIn) {
      case 0:
        GoogleSignInAccount googleUser = await googleSignIn.signIn();
        GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        FirebaseUser firebaseUser = await firebaseAuth.signInWithGoogle(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        handleDataSignIn(firebaseUser);
        break;

      case 1:
        if (emailEditingController.text.trim() != '' || emailEditingController.text.trim() != '') {
          firebaseAuth
              .signInWithEmailAndPassword(email: emailEditingController.text, password: passwordEditingController.text)
              .then((firebaseUser) async {
            handleDataSignIn(firebaseUser);
          }).catchError((error) async {
            await firebaseAuth
                .createUserWithEmailAndPassword(
                    email: emailEditingController.text, password: passwordEditingController.text)
                .then((firebaseUser) async {
              handleDataSignIn(firebaseUser);
            }).catchError((error) {
              this.setState(() {
                isLoading = false;
              });
              Fluttertoast.showToast(msg: 'Your email or pasword not true');
            });
          });
        } else {
          this.setState(() {
            isLoading = false;
          });
          Fluttertoast.showToast(msg: 'Your email or pasword not true');
        }
        break;
    }
  }

  void handleDataSignIn(FirebaseUser firebaseUser) async {
    if (firebaseUser != null) {
      // Check is already sign up
      final QuerySnapshot result =
          await Firestore.instance.collection('users').where('id', isEqualTo: firebaseUser.uid).getDocuments();
      final List<DocumentSnapshot> documents = result.documents;
      if (documents.length == 0) {
        // Update data to server if user is new
        Firestore.instance.collection('users').document(firebaseUser.uid).setData({
          'nickname': firebaseUser.displayName,
          'photoUrl': firebaseUser.photoUrl,
          'id': firebaseUser.uid,
          'isOnline': true
        });

        // Write data to local
        currentUser = firebaseUser;
        await prefs.setString('id', currentUser.uid);
        await prefs.setString('nickname', currentUser.displayName);
        await prefs.setString('photoUrl', currentUser.photoUrl);
      } else {
        // Write data to local
        await prefs.setString('id', documents[0]['id']);
        await prefs.setString('nickname', documents[0]['nickname']);
        await prefs.setString('photoUrl', documents[0]['photoUrl']);
        await prefs.setString('aboutMe', documents[0]['aboutMe']);
      }
      Fluttertoast.showToast(msg: "Sign in success");
      this.setState(() {
        isLoading = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MainScreen(currentUserId: firebaseUser.uid)),
      );
    } else {
      Fluttertoast.showToast(msg: "Sign in fail");
      this.setState(() {
        isLoading = false;
      });
    }
  }

  Future openDialogLogin() async {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return new SimpleDialog(
            contentPadding: new EdgeInsets.only(left: 0.0, right: 0.0, top: 0.0, bottom: 10.0),
            children: <Widget>[
              // Title
              Container(
                color: themeColor,
                margin: new EdgeInsets.all(0.0),
                child: Center(
                  child: new Text(
                    'Fill out your email and password',
                    style: new TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.0),
                    textAlign: TextAlign.center,
                  ),
                ),
                height: 80.0,
              ),

              // Email
              Container(
                child: TextField(
                  decoration: InputDecoration.collapsed(
                      hintText: 'Email', hintStyle: TextStyle(color: greyColor), border: UnderlineInputBorder()),
                  controller: emailEditingController,
                  keyboardType: TextInputType.emailAddress,
                ),
                padding: EdgeInsets.all(15.0),
                margin: EdgeInsets.only(top: 20.0),
              ),

              // Password
              Container(
                child: TextField(
                  decoration: InputDecoration.collapsed(
                      hintText: 'Password', hintStyle: TextStyle(color: greyColor), border: UnderlineInputBorder()),
                  controller: passwordEditingController,
                  obscureText: true,
                ),
                padding: EdgeInsets.all(15.0),
              ),

              // Go button
              Container(
                child: FlatButton(
                  onPressed: () {
                    Navigator.pop(context);
                    handleSignIn(1);
                  },
                  child: Text(
                    'GO',
                    style: TextStyle(fontSize: 16.0),
                  ),
                  color: themeColor,
                  highlightColor: themeColor2,
                  splashColor: Colors.transparent,
                  textColor: Colors.white,
                  padding: EdgeInsets.fromLTRB(30.0, 15.0, 30.0, 15.0),
                ),
                margin: EdgeInsets.fromLTRB(50.0, 20.0, 50.0, 10.0),
              ),
            ],
          );
        });
  }

  Future openDialogForgotPassword() async {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return new SimpleDialog(
            contentPadding: new EdgeInsets.only(left: 0.0, right: 0.0, top: 0.0, bottom: 10.0),
            children: <Widget>[
              // Title
              Container(
                color: themeColor,
                margin: new EdgeInsets.all(0.0),
                child: Center(
                  child: new Text(
                    'Fill out your email',
                    style: new TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.0),
                    textAlign: TextAlign.center,
                  ),
                ),
                height: 80.0,
              ),

              // Email
              Container(
                child: TextField(
                  decoration: InputDecoration.collapsed(
                      hintText: 'Email', hintStyle: TextStyle(color: greyColor), border: UnderlineInputBorder()),
                  controller: emailEditingController,
                  keyboardType: TextInputType.emailAddress,
                ),
                padding: EdgeInsets.all(15.0),
                margin: EdgeInsets.only(top: 10.0),
              ),

              // Go button
              Container(
                child: FlatButton(
                  onPressed: () {
                    Navigator.pop(context);
                    forgotPassword();
                  },
                  child: Text(
                    'DONE',
                    style: TextStyle(fontSize: 16.0),
                  ),
                  color: themeColor,
                  highlightColor: themeColor2,
                  splashColor: Colors.transparent,
                  textColor: Colors.white,
                  padding: EdgeInsets.fromLTRB(30.0, 15.0, 30.0, 15.0),
                ),
                margin: EdgeInsets.fromLTRB(50.0, 20.0, 50.0, 10.0),
              ),
            ],
          );
        });
  }

  void forgotPassword() {
    firebaseAuth.sendPasswordResetEmail(email: emailEditingController.text).whenComplete(() {
      Fluttertoast.showToast(msg: 'Check your email to reset password');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: <Widget>[
            Center(
              child: Column(
                children: <Widget>[
                  Container(
                    child: Image.asset(
                      'images/logo_bss.png',
                      width: 100.0,
                      height: 100.0,
                      fit: BoxFit.contain,
                    ),
                    margin: EdgeInsets.only(bottom: 50.0),
                  ),

                  // Button sign-in with google
                  Container(
                    child: FlatButton(
                      onPressed: () {
                        handleSignIn(0);
                      },
                      child: Text(
                        'SIGN IN WITH GOOGLE',
                        style: TextStyle(fontSize: 16.0),
                      ),
                      color: themeColor,
                      highlightColor: themeColor2,
                      splashColor: Colors.transparent,
                      textColor: Colors.white,
                      padding: EdgeInsets.fromLTRB(30.0, 15.0, 30.0, 15.0),
                    ),
                    width: 250.0,
                    margin: EdgeInsets.only(bottom: 20.0),
                  ),

                  // Button sign-in with email
                  Container(
                    child: FlatButton(
                      onPressed: () {
                        openDialogLogin();
                      },
                      child: Text(
                        'SIGN IN WITH EMAIL',
                        style: TextStyle(fontSize: 16.0),
                      ),
                      color: themeColor,
                      highlightColor: themeColor2,
                      splashColor: Colors.transparent,
                      textColor: Colors.white,
                      padding: EdgeInsets.fromLTRB(30.0, 15.0, 30.0, 15.0),
                    ),
                    width: 250.0,
                  ),
                ],
                mainAxisAlignment: MainAxisAlignment.center,
              ),
            ),

            // Button forgot password
            Positioned(
              child: Container(
                child: FlatButton(
                  onPressed: openDialogForgotPassword,
                  child: Text(
                    'Fotgot password?',
                    style: TextStyle(
                      color: themeColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              right: 10.0,
              bottom: 10.0,
            ),

            // Loading
            Positioned(
              child: isLoading
                  ? Container(
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                        ),
                      ),
                      color: Colors.white.withOpacity(0.8),
                    )
                  : Container(),
            ),
          ],
        ));
  }
}
