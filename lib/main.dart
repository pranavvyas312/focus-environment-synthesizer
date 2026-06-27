import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus Environment Synthesizer',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1115),
      ),
      home: const SynthesizerWorkspace(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SoundNode {
  final String id;
  final String name;
  final Color color;
  final String audioUrl;
  Offset position;
  double volume;
  AudioPlayer? player;

  SoundNode({
    required this.id,
    required this.name,
    required this.color,
    required this.audioUrl,
    required this.position,
    this.volume = 0.0,
  });
}

class Preset {
  final String name;
  final Map<String, double> targetVolumes;
  final Map<String, Offset> targetPositions;

  Preset({
    required this.name,
    required this.targetVolumes,
    required this.targetPositions,
  });
}

class SynthesizerWorkspace extends StatefulWidget {
  const SynthesizerWorkspace({super.key});

  @override
  State<SynthesizerWorkspace> createState() => _SynthesizerWorkspaceState();
}

class _SynthesizerWorkspaceState extends State<SynthesizerWorkspace> with TickerProviderStateMixin {
  late List<SoundNode> nodes;
  late List<Preset> presets;
  bool isAudioInitialized = false;
  bool showOverlay = true;
  Offset listenerPosition = Offset.zero;
  Size workspaceSize = Size.zero;

  @override
  void initState() {
    super.initState();
    
    // Initialize standard royalty-free loops directly via URL
    nodes = [
      SoundNode(
        id: 'rain',
        name: 'Rain',
        color: Colors.blueAccent,
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3', // Placeholder audio loops
        position: const Offset(-150, -150),
      ),
      SoundNode(
        id: 'campfire',
        name: 'Campfire',
        color: Colors.orangeAccent,
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        position: const Offset(150, -150),
      ),
      SoundNode(
        id: 'wind',
        name: 'Wind',
        color: Colors.blueGrey,
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
        position: const Offset(-150, 150),
      ),
      SoundNode(
        id: 'cafe',
        name: 'Cafe Ambient',
        color: Colors.purpleAccent,
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
        position: const Offset(150, 150),
      ),
    ];

    presets = [
      Preset(
        name: 'Midnight Storm',
        targetVolumes: {'rain': 0.9, 'wind': 0.6, 'campfire': 0.0, 'cafe': 0.0},
        targetPositions: {
          'rain': const Offset(-50, -50),
          'wind': const Offset(60, -40),
          'campfire': const Offset(300, 300),
          'cafe': const Offset(-300, 300),
        },
      ),
      Preset(
        name: 'Cozy Cafe',
        targetVolumes: {'cafe': 0.8, 'campfire': 0.4, 'rain': 0.0, 'wind': 0.0},
        targetPositions: {
          'cafe': const Offset(-40, 40),
          'campfire': const Offset(80, -20),
          'rain': const Offset(-300, -300),
          'wind': const Offset(300, -300),
        },
      ),
      Preset(
        name: 'Deep Focus',
        targetVolumes: {'rain': 0.5, 'wind': 0.5, 'campfire': 0.0, 'cafe': 0.0},
        targetPositions: {
          'rain': const Offset(-100, -100),
          'wind': const Offset(100, 100),
          'campfire': const Offset(300, -300),
          'cafe': const Offset(-300, 300),
        },
      ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    workspaceSize = MediaQuery.of(context).size;
    listenerPosition = Offset(workspaceSize.width / 2, workspaceSize.height / 2);
    for (var node in nodes) {
      _updateVolume(node);
    }
  }

  Future<void> _initializeAudioSystem() async {
    setState(() {
      showOverlay = false;
    });

    for (var node in nodes) {
      node.player = AudioPlayer();
      try {
        await node.player!.setUrl(node.audioUrl);
        await node.player!.setLoopMode(LoopMode.all);
        await node.player!.setVolume(node.volume);
        node.player!.play();
      } catch (e) {
        debugPrint("Error loading audio for ${node.name}: $e");
      }
    }

    setState(() {
      isAudioInitialized = true;
    });
  }

  void _updateVolume(SoundNode node) {
    // Relative calculation from central listener anchor node
    final absoluteNodePos = Offset(
      listenerPosition.dx + node.position.dx,
      listenerPosition.dy + node.position.dy,
    );

    double distance = (absoluteNodePos - listenerPosition).distance;
    double maxRadius = math.min(workspaceSize.width, workspaceSize.height) * 0.6;
    
    // Closer = louder, further falloff curve
    double rawVolume = 1.0 - (distance / maxRadius);
    node.volume = rawVolume.clamp(0.0, 1.0);

    if (isAudioInitialized && node.player != null) {
      node.player!.setVolume(node.volume);
      if (node.volume == 0.0 && node.player!.playing) {
        node.player!.pause();
      } else if (node.volume > 0.0 && !node.player!.playing) {
        node.player!.play();
      }
    }
  }

  void _applyPreset(Preset preset) {
    setState(() {
      for (var node in nodes) {
        if (preset.targetPositions.containsKey(node.id)) {
          node.position = preset.targetPositions[node.id]!;
          _updateVolume(node);
        }
      }
    });
  }

  @override
  void dispose() {
    for (var node in nodes) {
      node.player?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double rainVol = nodes.firstWhere((n) => n.id == 'rain').volume;
    double fireVol = nodes.firstWhere((n) => n.id == 'campfire').volume;

    return Scaffold(
      body: Stack(
        children: [
          // Reactive dynamic canvas particles in background
          Positioned.fill(
            child: CustomPaint(
              painter: ParticlePainter(rainVolume: rainVol, campfireVolume: fireVol),
            ),
          ),

          // Central Anchor Listener Node
          Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 4,
                  )
                ],
              ),
            ),
          ),

          // Draggable Workspace Nodes
          ...nodes.map((node) {
            final absX = listenerPosition.dx + node.position.dx - 60;
            final absY = listenerPosition.dy + node.position.dy - 60;

            return Positioned(
              left: absX,
              top: absY,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    node.position += details.delta;
                    _updateVolume(node);
                  });
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E222B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: node.color.withOpacity(0.8), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: node.color.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(node.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('${(node.volume * 100).toStringAsFixed(0)}%', style: TextStyle(color: node.color, fontSize: 20, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Upper Preset Configuration Layout Toolbar
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: presets.map((preset) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton(
                    onPressed: () => _applyPreset(preset),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF242936),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(preset.name),
                  ),
                );
              }).toList(),
            ),
          ),

          // User-gesture authorization requirement overlay context blocks
          if (showOverlay)
            Positioned.fill(
              child: Container(
                color: Colors.black95,
                child: Center(
                  child: ElevatedButton(
                    onPressed: _initializeAudioSystem,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      backgroundColor: Colors.blueAccent,
                    ),
                    child: const Text('Start Ambient Synthesizer', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ParticlePainter extends CustomPainter {
  final double rainVolume;
  final double campfireVolume;

  ParticlePainter({required this.rainVolume, required this.campfireVolume});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);

    // Draw dynamic rain metrics
    if (rainVolume > 0.2) {
      final paint = Paint()
        ..color = Colors.blueAccent.withOpacity(0.2 * rainVolume)
        ..strokeWidth = 1.5;
      int count = (100 * rainVolume).toInt();
      for (int i = 0; i < count; i++) {
        double x = random.nextDouble() * size.width;
        double y = random.nextDouble() * size.height;
        canvas.drawLine(Offset(x, y), Offset(x - 2, y + 15), paint);
      }
    }

    // Draw sparks metrics
    if (campfireVolume > 0.2) {
      final paint = Paint()..color = Colors.orangeAccent.withOpacity(0.4 * campfireVolume);
      int count = (40 * campfireVolume).toInt();
      for (int i = 0; i < count; i++) {
        double x = (size.width / 2) + (random.nextDouble() * 200 - 100);
        double y = (size.height / 2) + (random.nextDouble() * 200 - 100) - (random.nextDouble() * 50);
        canvas.drawCircle(Offset(x, y), random.nextDouble() * 3 + 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}