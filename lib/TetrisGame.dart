import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

class TetrisGame extends StatefulWidget {
  const TetrisGame({super.key});

  @override
  _TetrisGameState createState() => _TetrisGameState();
}

class _TetrisGameState extends State<TetrisGame> with SingleTickerProviderStateMixin {
  static const int rows = 14;
  static const int cols = 10;
  static const Duration initialTickRate = Duration(milliseconds: 500);
  late Duration tickRate;

  late List<List<Color?>> board;
  late Timer gameTimer;
  bool isPaused = false;
  bool gameStarted = false;
  int highScore = 0;
  int comboMultiplier = 1;

  final Map<String, Map<String, dynamic>> tetrominoShapes = {
    'I': {'color': Colors.cyan, 'shape': [[1, 1, 1, 1]]},
    'O': {'color': Colors.yellow, 'shape': [[1, 1], [1, 1]]},
    'T': {'color': Colors.purple, 'shape': [[0, 1, 0], [1, 1, 1]]},
    'L': {'color': Colors.orange, 'shape': [[1, 0], [1, 0], [1, 1]]},
    'J': {'color': Colors.blue, 'shape': [[0, 1], [0, 1], [1, 1]]},
    'S': {'color': Colors.green, 'shape': [[0, 1, 1], [1, 1, 0]]},
    'Z': {'color': Colors.red, 'shape': [[1, 1, 0], [0, 1, 1]]},
  };

  String? currentShape;
  List<List<int>>? currentShapeMatrix;
  Color? currentShapeColor;
  String? nextShape;
  Color? nextShapeColor;
  String? heldShape;
  Color? heldShapeColor;
  bool canHold = true;

  int currentRow = 0;
  int currentCol = 4;
  int score = 0;
  int level = 1;

  late AnimationController _controller;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _scoreAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _backgroundAnimation = Tween<double>(begin: 0, end: 1).animate(_controller)
      ..addListener(() => setState(() {}));
    _scoreAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.repeat(reverse: true);
    resetBoard();
    loadHighScore();
  }

  void resetBoard() {
    board = List.generate(rows, (_) => List.filled(cols, null));
    comboMultiplier = 1;
  }

  void startGame() {
    if (gameStarted) return;
    setState(() {
      gameStarted = true;
      spawnNewTetromino();
      tickRate = initialTickRate;
      gameTimer = Timer.periodic(tickRate, (timer) {
        if (!isPaused && gameStarted) {
          setState(() {
            if (!moveDown()) {
              mergeTetromino();
              clearFullRows();
              spawnNewTetromino();
            }
          });
        }
      });
    });
  }

  void spawnNewTetromino() {
    if (nextShape == null) {
      final shapes = tetrominoShapes.keys.toList()..shuffle();
      nextShape = shapes.first;
    }
    currentShape = nextShape;
    currentShapeMatrix = (tetrominoShapes[currentShape]!['shape'] as List<List<int>>)
        .map<List<int>>((row) => List<int>.from(row))
        .toList();
    currentShapeColor = tetrominoShapes[currentShape]!['color'] as Color;

    final shapes = tetrominoShapes.keys.toList()..shuffle();
    nextShape = shapes.first;
    nextShapeColor = tetrominoShapes[nextShape]!['color'] as Color;

    currentRow = 0;
    currentCol = (cols ~/ 2) - (currentShapeMatrix![0].length ~/ 2);
    canHold = true;

    if (isCollision(currentRow, currentCol, currentShapeMatrix!)) {
      gameTimer.cancel();
      updateHighScore();
      setState(() => gameStarted = false);
      showGameOver();
    }
  }

  bool moveDown() {
    if (!isCollision(currentRow + 1, currentCol, currentShapeMatrix!)) {
      currentRow++;
      _playSound('move.wav');
      return true;
    }
    return false;
  }

  void dropPiece() {
    setState(() {
      while (moveDown()) {}
      mergeTetromino();
      clearFullRows();
      spawnNewTetromino();
      _playSound('drop.wav');
    });
  }

  void moveLeft() => setState(() {
    if (!isCollision(currentRow, currentCol - 1, currentShapeMatrix!)) {
      currentCol--;
      _playSound('move.wav');
    }
  });

  void moveRight() => setState(() {
    if (!isCollision(currentRow, currentCol + 1, currentShapeMatrix!)) {
      currentCol++;
      _playSound('move.wav');
    }
  });

  void rotatePiece() => setState(() {
    final rotated = rotateMatrix(currentShapeMatrix!);
    if (!isCollision(currentRow, currentCol, rotated)) {
      currentShapeMatrix = rotated;
      _playSound('rotate.wav');
    }
  });

  void holdPiece() {
    if (!canHold) return;
    setState(() {
      if (heldShape == null) {
        heldShape = currentShape;
        heldShapeColor = currentShapeColor;
        spawnNewTetromino();
      } else {
        final tempShape = currentShape;
        final tempColor = currentShapeColor;
        currentShape = heldShape;
        currentShapeMatrix = (tetrominoShapes[heldShape]!['shape'] as List<List<int>>)
            .map<List<int>>((row) => List<int>.from(row))
            .toList();
        currentShapeColor = heldShapeColor;
        heldShape = tempShape;
        heldShapeColor = tempColor;
        currentRow = 0;
        currentCol = (cols ~/ 2) - (currentShapeMatrix![0].length ~/ 2);
      }
      canHold = false;
      _playSound('hold.wav');
    });
  }

  void mergeTetromino() {
    for (int r = 0; r < currentShapeMatrix!.length; r++) {
      for (int c = 0; c < currentShapeMatrix![r].length; c++) {
        if (currentShapeMatrix![r][c] == 1) {
          board[currentRow + r][currentCol + c] = currentShapeColor;
        }
      }
    }
  }

  void clearFullRows() {
    int clearedRows = 0;
    board.removeWhere((row) {
      if (row.every((cell) => cell != null)) {
        clearedRows++;
        return true;
      }
      return false;
    });
    for (int i = 0; i < clearedRows; i++) {
      board.insert(0, List.filled(cols, null));
    }
    if (clearedRows > 0) {
      updateScore(clearedRows);
      _playSound('clear.wav');
      comboMultiplier = (comboMultiplier + 1).clamp(1, 5); // Max multiplier 5x
    } else {
      comboMultiplier = 1; // Reset if no lines cleared
    }
  }

  void updateScore(int rowsCleared) {
    int baseScore = 0;
    if (rowsCleared == 1) baseScore = 100;
    else if (rowsCleared == 2) baseScore = 300;
    else if (rowsCleared == 3) baseScore = 500;
    else if (rowsCleared == 4) baseScore = 800;

    score += baseScore * comboMultiplier * level;

    if (score >= level * 1000) {
      level++;
      tickRate = Duration(milliseconds: (500 / level).clamp(100, 500).toInt());
      gameTimer.cancel();
      startGame();
      _playSound('level_up.wav');
    }
  }

  void showGameOver() {
    _playSound('game_over.wav');
    showDialog(
      context: context,
      builder: (context) => AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 500),
        child: AlertDialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Game Over', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: Text('Score: $score\nLevel: $level\nHigh Score: $highScore',
              style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  resetBoard();
                  score = 0;
                  level = 1;
                  tickRate = initialTickRate;
                  heldShape = null;
                });
              },
              child: const Text('Restart', style: TextStyle(color: Colors.cyan)),
            ),
          ],
        ),
      ),
    );
  }

  void showPauseMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Paused', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                togglePause();
              },
              child: const Text('Resume', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  resetBoard();
                  score = 0;
                  level = 1;
                  tickRate = initialTickRate;
                  heldShape = null;
                  gameStarted = false;
                });
              },
              child: const Text('Restart', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Quit', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );
  }

  bool isCollision(int newRow, int newCol, List<List<int>> shape) {
    for (int r = 0; r < shape.length; r++) {
      for (int c = 0; c < shape[r].length; c++) {
        if (shape[r][c] == 1) {
          int boardRow = newRow + r;
          int boardCol = newCol + c;
          if (boardRow >= rows ||
              boardCol < 0 ||
              boardCol >= cols ||
              (boardRow >= 0 && board[boardRow][boardCol] != null)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  int getDropRow() {
    int dropRow = currentRow;
    while (!isCollision(dropRow + 1, currentCol, currentShapeMatrix!)) {
      dropRow++;
    }
    return dropRow;
  }

  List<List<int>> rotateMatrix(List<List<int>> matrix) {
    final newMatrix = List.generate(matrix[0].length, (_) => List.filled(matrix.length, 0));
    for (int r = 0; r < matrix.length; r++) {
      for (int c = 0; c < matrix[r].length; c++) {
        newMatrix[c][matrix.length - 1 - r] = matrix[r][c];
      }
    }
    return newMatrix;
  }

  void loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => highScore = prefs.getInt('highScore') ?? 0);
  }

  void updateHighScore() async {
    if (score > highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('highScore', score);
      setState(() => highScore = score);
    }
  }

  void togglePause() {
    setState(() {
      isPaused = !isPaused;
      if (isPaused) showPauseMenu();
    });
  }

  void _playSound(String soundFile) async {
    await _audioPlayer.play(AssetSource('sounds/$soundFile'));
  }

  Widget buildGrid() {
    final dropRow = gameStarted ? getDropRow() : currentRow;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade900.withOpacity(0.8 + _backgroundAnimation.value * 0.2),
            Colors.blueGrey.shade900.withOpacity(0.8 + _backgroundAnimation.value * 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.5 + _backgroundAnimation.value * 0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: 1.0,
        ),
        itemCount: rows * cols,
        itemBuilder: (context, index) {
          int row = index ~/ cols;
          int col = index % cols;
          Color? color = board[row][col];
          bool isGhost = false;

          if (currentShapeMatrix != null) {
            final shapeRow = row - currentRow;
            final shapeCol = col - currentCol;
            final ghostRow = row - dropRow;
            if (shapeRow >= 0 &&
                shapeCol >= 0 &&
                shapeRow < currentShapeMatrix!.length &&
                shapeCol < currentShapeMatrix![shapeRow].length &&
                currentShapeMatrix![shapeRow][shapeCol] == 1) {
              color = currentShapeColor;
            } else if (ghostRow >= 0 &&
                shapeCol >= 0 &&
                ghostRow < currentShapeMatrix!.length &&
                shapeCol < currentShapeMatrix![ghostRow].length &&
                currentShapeMatrix![ghostRow][shapeCol] == 1 &&
                board[row][col] == null) {
              color = currentShapeColor!.withOpacity(0.3);
              isGhost = true;
            }
          }

          return Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: color ?? Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              boxShadow: color != null && !isGhost
                  ? [BoxShadow(color: color.withOpacity(0.7), blurRadius: 6, spreadRadius: 1)]
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget buildNextPiece() {
    if (nextShape == null) return const SizedBox.shrink();
    final nextShapeMatrix = tetrominoShapes[nextShape]!['shape'];
    final nextShapeColor = tetrominoShapes[nextShape]!['color'];

    return Column(
      children: [
        const Text('Next', style: TextStyle(fontSize: 20, color: Colors.white70, fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.cyan.withOpacity(0.5), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: (nextShapeMatrix as List<List<int>>).map(
                  (row) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((cell) => Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: cell == 1 ? nextShapeColor as Color : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: cell == 1
                        ? [BoxShadow(color: (nextShapeColor as Color).withOpacity(0.7), blurRadius: 6)]
                        : null,
                  ),
                )).toList(),
              ),
            ).toList(),
          ),
        ),
      ],
    );
  }

  Widget buildHeldPiece() {
    if (heldShape == null) return const SizedBox.shrink();
    final heldShapeMatrix = tetrominoShapes[heldShape]!['shape'];
    final heldShapeColor = tetrominoShapes[heldShape]!['color'];

    return Column(
      children: [
        const Text('Held', style: TextStyle(fontSize: 20, color: Colors.white70, fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.cyan.withOpacity(0.5), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: (heldShapeMatrix as List<List<int>>).map(
                  (row) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((cell) => Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: cell == 1 ? heldShapeColor as Color : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: cell == 1
                        ? [BoxShadow(color: (heldShapeColor as Color).withOpacity(0.7), blurRadius: 6)]
                        : null,
                  ),
                )).toList(),
              ),
            ).toList(),
          ),
        ),
      ],
    );
  }

  Widget buildCustomButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.cyanAccent, Colors.blueAccent.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.cyan.withOpacity(0.5 + _backgroundAnimation.value * 0.2), blurRadius: 8, spreadRadius: 2),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }

  Widget buildStartScreen() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade900, Colors.blueGrey.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15, spreadRadius: 5)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tetris', style: TextStyle(fontSize: 40, color: Colors.cyan, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text('Select Difficulty', style: TextStyle(fontSize: 20, color: Colors.white70)),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              onPressed: () {
                setState(() {
                  tickRate = const Duration(milliseconds: 500);
                  startGame();
                });
              },
              child: const Text('Easy', style: TextStyle(color: Colors.black)),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              onPressed: () {
                setState(() {
                  tickRate = const Duration(milliseconds: 300);
                  startGame();
                });
              },
              child: const Text('Hard', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.9 - _backgroundAnimation.value * 0.1),
              Colors.blueGrey.shade900.withOpacity(0.9 - _backgroundAnimation.value * 0.1),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: gameStarted
            ? Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      const Text('Score', style: TextStyle(fontSize: 18, color: Colors.white70)),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.cyan, Colors.blueAccent]),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(color: Colors.cyan.withOpacity(0.5), blurRadius: 8),
                          ],
                        ),
                        child: Text('$score',
                            style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      buildNextPiece(),
                      const SizedBox(height: 10),
                      buildHeldPiece(),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('Level', style: TextStyle(fontSize: 18, color: Colors.white70)),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.cyan, Colors.blueAccent]),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(color: Colors.cyan.withOpacity(0.5), blurRadius: 8),
                          ],
                        ),
                        child: Text('$level',
                            style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: score / (level * 1000),
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan.withOpacity(0.8)),
            ),
            Expanded(child: buildGrid()),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      buildCustomButton(Icons.arrow_left, moveLeft),
                      buildCustomButton(Icons.arrow_downward, moveDown),
                      buildCustomButton(Icons.arrow_right, moveRight),
                      buildCustomButton(Icons.rotate_right, rotatePiece),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      buildCustomButton(Icons.vertical_align_bottom, dropPiece),
                      buildCustomButton(Icons.swap_horiz, holdPiece),
                      buildCustomButton(isPaused ? Icons.play_arrow : Icons.pause, togglePause),
                    ],
                  ),
                ],
              ),
            ),
          ],
        )
            : buildStartScreen(),
      ),
    );
  }

  @override
  void dispose() {
    gameTimer.cancel();
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}