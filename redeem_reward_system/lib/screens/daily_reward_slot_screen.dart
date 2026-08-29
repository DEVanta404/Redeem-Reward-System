import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class DailyRewardSlotScreen extends StatefulWidget {
  final int rewardAmount;
  final bool isLuckyDay;
  final Future<bool> Function() onRewardClaimed;

  const DailyRewardSlotScreen({
    super.key,
    required this.rewardAmount,
    required this.isLuckyDay,
    required this.onRewardClaimed,
  });

  @override
  State<DailyRewardSlotScreen> createState() => _DailyRewardSlotScreenState();
}

class _DailyRewardSlotScreenState extends State<DailyRewardSlotScreen>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _clack1Controller;
  late AnimationController _clack2Controller;
  late AnimationController _clack3Controller;
  late AnimationController _celebrationController;

  bool _showResult = false;
  bool _isClaiming = false;
  bool _isSpinning = false;

  late List<int> _reelValues;
  late List<bool> _reelStopped;

  final List<int> _possibleRewards = [10, 20, 30, 50];

  @override
  void initState() {
    super.initState();

    // Initial reel values before spinning
    _reelValues = [10, 20, 30];
    _reelStopped = [false, false, false];

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _clack1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _clack2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _clack3Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _startSlotAnimation();
  }

  Future<void> _startSlotAnimation() async {
    if (!mounted) return;

    setState(() {
      _isSpinning = true;
    });

    // Start spinning all reels
    _spinController.forward();

    // Reel 1 stops
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    setState(() {
      _reelValues[0] = _randomReward();
      _reelStopped[0] = true;
    });
    _clack1Controller.forward();

    // Reel 2 stops
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() {
      _reelValues[1] = _randomReward();
      _reelStopped[1] = true;
    });
    _clack2Controller.forward();

    // Reel 3 stops (final value)
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() {
      _reelValues[2] = widget.rewardAmount;
      _reelStopped[2] = true;
    });
    _clack3Controller.forward();

    // Show result screen
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() {
      _showResult = true;
      _isSpinning = false;
    });

    _celebrationController.forward();
  }

  int _randomReward() {
    return _possibleRewards[
        Random().nextInt(_possibleRewards.length)];
  }

  Future<void> _handleCollectPressed() async {
    if (_isClaiming) return;

    setState(() {
      _isClaiming = true;
    });

    final success = await widget.onRewardClaimed();

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _isClaiming = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not claim reward. Please try again.',
          ),
        ),
      );
    }
  }

  String _getResultTitle() {
    switch (widget.rewardAmount) {
      case 50:
        return '💰 MEGA JACKPOT!';
      case 30:
        return '⭐ LUCKY HIT!';
      case 20:
        return '🔥 GREAT ROLL!';
      default:
        return '🎉 NICE!';
    }
  }

  String _getResultMessage() {
    switch (widget.rewardAmount) {
      case 50:
        return 'YOU ARE INSANELY LUCKY!';
      case 30:
        return 'That was a lucky spin!';
      case 20:
        return 'Not bad at all!';
      default:
        return 'Come back tomorrow!';
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _clack1Controller.dispose();
    _clack2Controller.dispose();
    _clack3Controller.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _showResult,
      child: Scaffold(
        backgroundColor: const Color(0xFF111122),
        body: SafeArea(
          child: _showResult
              ? _buildResultScreen()
              : _buildSlotScreen(),
        ),
      ),
    );
  }

  Widget _buildSlotScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '🎰 DAILY REWARD',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'TRY YOUR LUCK!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white54,
              letterSpacing: 3,
            ),
          ),

          const SizedBox(height: 45),

          // Slot Machine
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF3B3B5C),
                  Color(0xFF20203A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFFFD700),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700)
                      .withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  '★ DAILY LUCK ★',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildReel(0),
                    const SizedBox(width: 10),
                    _buildReel(1),
                    const SizedBox(width: 10),
                    _buildReel(2),
                  ],
                ),

                const SizedBox(height: 15),

                // Winning line
                Container(
                  height: 3,
                  width: 250,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  'GOOD LUCK! 🍀',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          AnimatedOpacity(
            opacity: _isSpinning ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: const Text(
              '✨ SPINNING... ✨',
              style: TextStyle(
                color: Color(0xFF00FF88),
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReel(int index) {
    late AnimationController clackController;
    if (index == 0) {
      clackController = _clack1Controller;
    } else if (index == 1) {
      clackController = _clack2Controller;
    } else {
      clackController = _clack3Controller;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        _spinController,
        clackController,
      ]),
      builder: (context, child) {
        // Clack effect - scale up then down
        final clackScale = clackController.value == 0
            ? 1.0
            : 1.0 + (sin(clackController.value * pi) * 0.15);

        return Transform.scale(
          scale: clackScale,
          child: Container(
            width: 80,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF080812),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF00FF88),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF88)
                      .withValues(alpha: 0.2),
                  blurRadius: 12,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _reelStopped[index]
                  ? Center(
                      child: Text(
                        '${_reelValues[index]}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00FF88),
                          fontFamily: 'Courier',
                        ),
                      ),
                    )
                  : _buildSpinningReel(index),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpinningReel(int index) {
    // Create a continuous spinning effect
    final spinSpeed = 20.0;
    final offset = (_spinController.value * spinSpeed).remainder(
      _possibleRewards.length.toDouble(),
    );

    final displayValues = <int>[];
    for (int i = 0; i < 5; i++) {
      displayValues.add(
        _possibleRewards[
          (offset.floor() + i) % _possibleRewards.length
        ],
      );
    }

    return Center(
      child: Transform.translate(
        offset: Offset(
          0,
          offset * 40 - 40,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: displayValues
              .map(
                (value) => SizedBox(
                  height: 40,
                  child: Center(
                    child: Text(
                      '$value',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00FF88),
                        fontFamily: 'Courier',
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final bool jackpot = widget.rewardAmount >= 30;

    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _celebrationController,
        curve: Curves.elasticOut,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getResultTitle(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: jackpot ? 30 : 28,
                    fontWeight: FontWeight.bold,
                    color: jackpot
                        ? const Color(0xFFFFD700)
                        : Colors.white,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  _getResultMessage(),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 35),

                // Reward
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 30,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: jackpot
                          ? [
                              const Color(0xFFFFD700),
                              const Color(0xFFFF8C00),
                            ]
                          : [
                              const Color(0xFF00FF88),
                              const Color(0xFF00AA66),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: (jackpot
                                ? const Color(0xFFFFD700)
                                : const Color(0xFF00FF88))
                            .withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'YOU WON',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        '+${widget.rewardAmount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Text(
                        'POINTS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),

                      if (widget.isLuckyDay) ...[
                        const SizedBox(height: 15),
                      const Text(
                        '🌟 LUCKY DAY BONUS 🌟',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 30),

              if (jackpot)
                const Text(
                  '🎉 🎉 🎉',
                  style: TextStyle(fontSize: 28),
                ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed:
                      _isClaiming ? null : _handleCollectPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    foregroundColor: const Color(0xFF111122),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 10,
                  ),
                  child: _isClaiming
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'COLLECT REWARD',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}