import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ZahmaApp());
}

class ZahmaApp extends StatelessWidget {
  const ZahmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "زحمة إسكندرية",
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1410),
        body: GameWidget(game: ZahmaGame()),
      ),
    );
  }
}

// ============================================================
// GAME
// ============================================================
class ZahmaGame extends FlameGame with TapCallbacks {
  double _speed = 4.0;
  double _spawnTimer = 0;
  double _score = 0;
  int _highScore = 0;
  bool _gameOver = false;

  final List<Car> _cars = [];
  late TukTuk _player;

  @override
  Color backgroundColor() => const Color(0xFF2A2018);

  @override
  Future<void> onLoad() async {
    await _loadHighScore();
    _player = TukTuk(game: this);
    add(_player);
    add(LeftButton(game: this));
    add(RightButton(game: this));
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    _highScore = prefs.getInt('high_score') ?? 0;
  }

  Future<void> _saveHighScore() async {
    if (_score.toInt() > _highScore) {
      _highScore = _score.toInt();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('high_score', _highScore);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    _score += dt * 10;
    _speed = 4.0 + (_score / 100).clamp(0, 6);
    _spawnTimer += dt;

    if (_spawnTimer > (1.0 / _speed).clamp(0.35, 1.2)) {
      _spawnTimer = 0;
      _spawnCar();
    }

    _cars.removeWhere((c) => c.position.y > size.y + 200);

    for (final car in _cars) {
      if (_collides(car)) {
        _gameOver = true;
        _saveHighScore();
        break;
      }
    }
  }

  bool _collides(Car car) {
    final dx = (_player.position.x - car.position.x).abs();
    final dy = (_player.position.y - car.position.y).abs();
    return dx < 50 && dy < 80;
  }

  void _spawnCar() {
    final rng = math.Random();
    final lane = rng.nextInt(3) - 1;
    final x = size.x / 2 + lane * 90 - 35;
    final car = Car(
      x: x,
      y: -150,
      speed: _speed,
      color: _randomColor(rng),
    );
    _cars.add(car);
    add(car);
  }

  Color _randomColor(math.Random rng) {
    final colors = [
      const Color(0xFFE24A4A),
      const Color(0xFF4A90E2),
      const Color(0xFF7AD77A),
      const Color(0xFFFFD54A),
      const Color(0xFFC77AFF),
      const Color(0xFFFF9B4A),
    ];
    return colors[rng.nextInt(colors.length)];
  }

  void moveLeft() {
    if (_gameOver) return;
    _player.position.x -= 40;
    if (_player.position.x < size.x / 2 - 180) {
      _player.position.x = size.x / 2 - 180;
    }
  }

  void moveRight() {
    if (_gameOver) return;
    _player.position.x += 40;
    if (_player.position.x > size.x / 2 + 180) {
      _player.position.x = size.x / 2 + 180;
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // 1. الرصيف الأخضر
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF4A6A3A),
    );

    // 2. الطريق
    final roadLeft = w / 2 - 220;
    final roadRight = w / 2 + 220;
    canvas.drawRect(
      Rect.fromLTWH(roadLeft, 0, roadRight - roadLeft, h),
      Paint()..color = const Color(0xFF5A5A66),
    );

    // 3. الخطوط البيضا
    final linePaint = Paint()..color = const Color(0xFFCCCCCC);
    for (double y = 0; y < h; y += 60) {
      canvas.drawRect(Rect.fromLTWH(w / 2 - 3, y, 6, 30), linePaint);
    }

    // 4. خطوط المسارات
    final sideLine = Paint()
      ..color = const Color(0xFFAAAAAA).withOpacity(0.4)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(w / 2 - 90, 0), Offset(w / 2 - 90, h), sideLine);
    canvas.drawLine(Offset(w / 2 + 90, 0), Offset(w / 2 + 90, h), sideLine);

    // 5. نخل
    _drawPalm(canvas, 40, 80);
    _drawPalm(canvas, w - 40, 160);
    _drawPalm(canvas, 50, h - 120);
    _drawPalm(canvas, w - 60, h - 60);

    // 6. HUD
    _drawHud(canvas);

    // 7. Game Over
    if (_gameOver) _drawGameOver(canvas);
  }

  void _drawPalm(Canvas canvas, double x, double y) {
    canvas.drawRect(
      Rect.fromLTWH(x - 4, y - 40, 8, 60),
      Paint()..color = const Color(0xFF8A6A3A),
    );
    final leaf = Paint()..color = const Color(0xFF4A7A3A);
    for (int i = 0; i < 5; i++) {
      final angle = (i - 2) * 0.5;
      canvas.save();
      canvas.translate(x, y - 40);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -20), width: 12, height: 35),
        leaf,
      );
      canvas.restore();
    }
  }

  void _drawHud(Canvas canvas) {
    // النقاط
    final scoreTp = TextPainter(
      text: TextSpan(
        text: 'النقاط: ${_score.toInt()}',
        style: const TextStyle(
          color: Color(0xFFFFD54A),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    _drawChip(canvas, 20, 20, scoreTp, const Color(0xFFFFD54A));

    // أعلى نتيجة
    final highTp = TextPainter(
      text: TextSpan(
        text: '🏆 أعلى: $_highScore',
        style: const TextStyle(
          color: Color(0xFFFF9B4A),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    _drawChip(canvas, 20, 75, highTp, const Color(0xFFFF9B4A));

    // السرعة
    final speedTp = TextPainter(
      text: TextSpan(
        text: 'السرعة: ${_speed.toStringAsFixed(1)}x',
        style: const TextStyle(
          color: Color(0xFF7AD7FF),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    _drawChip(
      canvas,
      size.x - speedTp.width - 50,
      20,
      speedTp,
      const Color(0xFF7AD7FF),
    );
  }

  void _drawChip(Canvas canvas, double x, double y, TextPainter tp, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, tp.width + 30, tp.height + 20),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.black.withOpacity(0.6),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, tp.width + 30, tp.height + 20),
        const Radius.circular(8),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    tp.paint(canvas, Offset(x + 15, y + 10));
  }

  void _drawGameOver(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = Colors.black.withOpacity(0.75),
    );

    final titleTp = TextPainter(
      text: const TextSpan(
        text: 'خبطة!',
        style: TextStyle(
          color: Color(0xFFE24A4A),
          fontSize: 60,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    titleTp.paint(
      canvas,
      Offset((size.x - titleTp.width) / 2, size.y / 2 - 130),
    );

    final scoreTp = TextPainter(
      text: TextSpan(
        text: 'النقاط: ${_score.toInt()}',
        style: const TextStyle(
          color: Color(0xFFFFD54A),
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    scoreTp.paint(
      canvas,
      Offset((size.x - scoreTp.width) / 2, size.y / 2 - 40),
    );

    final highTp = TextPainter(
      text: TextSpan(
        text: '🏆 أعلى نتيجة: $_highScore',
        style: const TextStyle(
          color: Color(0xFFFF9B4A),
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    highTp.paint(
      canvas,
      Offset((size.x - highTp.width) / 2, size.y / 2 + 20),
    );

    final hintTp = TextPainter(
      text: const TextSpan(
        text: 'دوس على الشاشة عشان تلعب تاني',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 18,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    hintTp.paint(
      canvas,
      Offset((size.x - hintTp.width) / 2, size.y / 2 + 80),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_gameOver) _reset();
  }

  void _reset() {
    for (final c in _cars) {
      c.removeFromParent();
    }
    _cars.clear();
    _player.position = Vector2(size.x / 2 - 30, size.y - 180);
    _score = 0;
    _speed = 4.0;
    _spawnTimer = 0;
    _gameOver = false;
  }
}

// ============================================================
// TUK TUK
// ============================================================
class TukTuk extends PositionComponent {
  final ZahmaGame game;

  TukTuk({required this.game});

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (position == Vector2.zero()) {
      position = Vector2(size.x / 2 - 30, size.y - 180);
      this.size = Vector2(60, 100);
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h - 8), width: w * 0.9, height: 14),
      Paint()..color = Colors.black.withOpacity(0.35),
    );

    final body = Paint()..color = const Color(0xFFFFCC00);
    final dark = Paint()..color = const Color(0xFFCC9900);
    final black = Paint()..color = const Color(0xFF1A1A1A);
    final glass = Paint()..color = const Color(0xFFA8DCFF);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(5, 30, w - 10, h - 50),
        const Radius.circular(8),
      ),
      body,
    );

    canvas.drawRect(Rect.fromLTWH(5, h - 40, w - 10, 8), black);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 5, w - 20, 30),
        const Radius.circular(6),
      ),
      body,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(14, 10, w - 28, 20),
        const Radius.circular(3),
      ),
      glass,
    );

    canvas.drawCircle(
      Offset(w / 2, h - 15),
      6,
      Paint()..color = const Color(0xFFFFF3B0),
    );
    canvas.drawCircle(
      Offset(w / 2, h - 15),
      8,
      Paint()
        ..color = const Color(0xFFFFF3B0).withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawCircle(Offset(w / 2, h - 8), 5, black);

    canvas.drawCircle(const Offset(12, 0), 6, black);
    canvas.drawCircle(Offset(w - 12, 0), 6, black);
    canvas.drawCircle(
      const Offset(12, 0),
      2.5,
      Paint()..color = const Color(0xFF808080),
    );
    canvas.drawCircle(
      Offset(w - 12, 0),
      2.5,
      Paint()..color = const Color(0xFF808080),
    );

    canvas.drawRect(Rect.fromLTWH(5, 40, 3, 30), dark);
    canvas.drawRect(Rect.fromLTWH(w - 8, 40, 3, 30), dark);
  }
}

// ============================================================
// CAR
// ============================================================
class Car extends PositionComponent {
  final double x;
  final double y;
  final double speed;
  final Color color;

  Car({
    required this.x,
    required this.y,
    required this.speed,
    required this.color,
  }) : super(
          position: Vector2(x, y),
          size: Vector2(70, 120),
        );

  @override
  void update(double dt) {
    position.y += speed * 150 * dt;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h - 8), width: w * 0.9, height: 16),
      Paint()..color = Colors.black.withOpacity(0.3),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 15, w, h - 30),
        const Radius.circular(10),
      ),
      Paint()..color = color,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 30, w - 20, h - 70),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF222222),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(14, 15, w - 28, 18),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFA8DCFF),
    );

    // ✅ شباك ورا — الإصلاح هنا
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(14, h - 35, w - 28, 18),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFA8DCFF),
    );

    final black = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawRect(Rect.fromLTWH(-4, 20, 6, 20), black);
    canvas.drawRect(Rect.fromLTWH(w - 2, 20, 6, 20), black);
    canvas.drawRect(Rect.fromLTWH(-4, h - 45, 6, 20), black);
    canvas.drawRect(Rect.fromLTWH(w - 2, h - 45, 6, 20), black);
  }
}

// ============================================================
// BUTTONS
// ============================================================
class LeftButton extends PositionComponent with TapCallbacks {
  final ZahmaGame game;

  LeftButton({required this.game}) : super();

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = Vector2(20, size.y - 100);
    this.size = Vector2(80, 80);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      Paint()..color = const Color(0xFFFFD54A),
    );
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: '◀',
        style: TextStyle(
          color: Colors.black,
          fontSize: 36,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(size.x / 2 - tp.width / 2, size.y / 2 - tp.height / 2),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    game.moveLeft();
  }
}

class RightButton extends PositionComponent with TapCallbacks {
  final ZahmaGame game;

  RightButton({required this.game}) : super();

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = Vector2(size.x - 100, size.y - 100);
    this.size = Vector2(80, 80);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      Paint()..color = const Color(0xFFFFD54A),
    );
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: '▶',
        style: TextStyle(
          color: Colors.black,
          fontSize: 36,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(size.x / 2 - tp.width / 2, size.y / 2 - tp.height / 2),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    game.moveRight();
  }
}