import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vtm_helper/screens/character_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VTM V20 Helper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: GoogleFonts.literata().fontFamily, // или другой шрифт
        // остальные настройки
      ),
      home: const CharacterListScreen(),
    );
  }
}
