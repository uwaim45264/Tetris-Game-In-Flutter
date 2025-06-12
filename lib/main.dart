import 'package:flutter/material.dart';
import 'TetrisGame.dart';


void main(){
  runApp(const TetrisApp()
  );
}

class TetrisApp extends StatelessWidget {
  const TetrisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tetris',
      theme: ThemeData.dark(),
      home: const TetrisGame(),
    );
  }
}

