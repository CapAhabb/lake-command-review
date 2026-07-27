import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChartPlotterScreen extends StatefulWidget {
  const ChartPlotterScreen({super.key});

  @override
  State<ChartPlotterScreen> createState() => _ChartPlotterScreenState();
}

class _ChartPlotterScreenState extends State<ChartPlotterScreen> {
  double boatHeading = 45.0;
  double boatSpeed = 5.2;
  double lat = 42.485;
  double lon = -86.415;
  bool toolboxVisible = false;

  final Map<String, LayerControl> layerControls = {
    'CONTOURS': LayerControl(enabled: true, gain: 0.8),
    'DEPTH SHADING': LayerControl(enabled: true, gain: 0.4),
    'BAIT DENSITY': LayerControl(enabled: false, gain: 0.6),
    'SPECIES': LayerControl(enabled: true, gain: 0.7),
    'CURRENT': LayerControl(enabled: false, gain: 0.5),
    'WATER TEMP': LayerControl(enabled: false, gain: 0.6),
    'WEATHER': LayerControl(enabled: false, gain: 0.5),
  };

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050608),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AspectRatio(
            aspectRatio: 1536 / 1024,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF07090B),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: const Color(0xFF2C3237), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xCC000000),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Stack(
                  children: [
                    const Positioned.fill(child: _BezelSurface()),
                    const Positioned(
                      top: 32,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          'LakeGuard Pro',
                          style: TextStyle(
                            color: Color(0xFF8F969B),
                            fontSize: 31,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 118,
                      top: 92,
                      bottom: 60,
                      right: 174,
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _SonarStrip(),
                                Expanded(
                                  child: _GptChartPanel(
                                    layerControls: layerControls,
                                  ),
                                ),
                                _TelemetryPanel(speed: boatSpeed),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 190,
                            child: _BottomLayerControls(
                              layerControls: layerControls,
                              onToggle: (name, enabled) {
                                setState(() {
                                  layerControls[name]!.enabled = enabled;
                                });
                              },
                              onGainChanged: (name, gain) {
                                setState(() {
                                  layerControls[name]!.gain = gain;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 25,
                      top: 110,
                      bottom: 82,
                      width: 118,
                      child: _HardwareSide(
                        onMenuTap: () {
                          setState(() {
                            toolboxVisible = !toolboxVisible;
                          });
                        },
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      left: toolboxVisible ? 118 : -280,
                      top: 110,
                      bottom: 250,
                      child: _ToolboxMenu(
                        onClose: () {
                          setState(() {
                            toolboxVisible = false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LayerControl {
  LayerControl({required this.enabled, required this.gain});
  bool enabled;
  double gain;
}

class _BezelSurface extends StatelessWidget {
  const _BezelSurface();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.05,
          colors: [Color(0xFF171C20), Color(0xFF07090B), Color(0xFF020304)],
          stops: [0, 0.5, 1],
        ),
      ),
      child: CustomPaint(painter: _BezelPainter()),
    );
  }
}

class _BezelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0x553F474D)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final inset = Rect.fromLTWH(18, 14, size.width - 36, size.height - 28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inset, const Radius.circular(28)),
      stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inset.deflate(8), const Radius.circular(22)),
      Paint()
        ..color = const Color(0xAA000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SonarStrip extends StatelessWidget {
  const _SonarStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF090807),
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Column(
          children: [
            const _AquaHeader(label: 'AquaPlotter', compact: true),
            Expanded(
              child: CustomPaint(
                painter: _SonarPainter(),
                child: const SizedBox.expand(),
              ),
            ),
            Container(
              height: 66,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF10100F),
                border: Border.all(color: const Color(0xFF5E3A0C)),
              ),
              child: const Icon(Icons.home, color: Color(0xFFFFA326), size: 38),
            ),
          ],
        ),
      ),
    );
  }
}

class _SonarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(19);
    final dot = Paint()..color = const Color(0x99FF8A00);
    for (int i = 0; i < 900; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        random.nextDouble() * 1.15,
        dot,
      );
    }

    final sweep = Paint()
      ..color = const Color(0xFFFFAF36)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 5; i++) {
      final y = size.height * (0.58 + i * 0.055);
      final path = Path()
        ..moveTo(-10, y)
        ..quadraticBezierTo(size.width * 0.45, y - 48, size.width + 6, y - 18);
      canvas.drawPath(
        path,
        sweep
          ..color = Color.lerp(
            const Color(0xFFFFB036),
            Colors.black,
            i * 0.12,
          )!,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GptChartPanel extends StatelessWidget {
  const _GptChartPanel({required this.layerControls});

  final Map<String, LayerControl> layerControls;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071016),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        children: [
          const _AquaHeader(label: 'AquaPlotter', compact: false),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _ChartPainter(layerControls: layerControls),
                ),
                const Positioned(right: 16, bottom: 12, child: _ThermalScale()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AquaHeader extends StatelessWidget {
  const _AquaHeader({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        height: 48,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF050607), Color(0xFF000000)],
          ),
        ),
      );
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF050607), Color(0xFF000000)],
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFA326),
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          const Icon(Icons.navigation, color: Color(0xFFFFA326), size: 34),
          const Spacer(),
          const Icon(
            Icons.settings_input_component,
            color: Color(0xFF39E845),
            size: 24,
          ),
          const SizedBox(width: 20),
          const Icon(Icons.battery_full, color: Color(0xFF7DF45C), size: 32),
        ],
      ),
    );
  }
}

class _ThermalScale extends StatelessWidget {
  const _ThermalScale();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF513A12)),
      ),
      child: Row(
        children: [
          const Text(
            'Low',
            style: TextStyle(color: Color(0xFFFFC02C), fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF3E3300),
                    Color(0xFFFF8B00),
                    Color(0xFFC90000),
                  ],
                ),
                border: Border.all(color: Colors.black),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'High',
            style: TextStyle(color: Color(0xFFFF5A1F), fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _TelemetryPanel extends StatelessWidget {
  const _TelemetryPanel({required this.speed});

  final double speed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TelemetryTile(label: 'Depth:', value: '47', unit: 'ft'),
          const _TelemetryTile(label: 'Water Temp:', value: '68.4', unit: 'F'),
          _TelemetryTile(
            label: 'Speed:',
            value: speed.toStringAsFixed(1),
            unit: '',
          ),
          const _TelemetryTile(label: 'Time', value: '2:34', unit: 'PM'),
          const _TelemetryTile(label: 'GPS', value: '3D Fix', unit: ''),
        ],
      ),
    );
  }
}

class _TelemetryTile extends StatelessWidget {
  const _TelemetryTile({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xF2070809),
          border: Border.all(color: const Color(0xFF71470E)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFFA326),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Color(0xFFFFA326),
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                  children: [
                    TextSpan(text: value, style: const TextStyle(fontSize: 30)),
                    if (unit.isNotEmpty)
                      TextSpan(
                        text: unit,
                        style: const TextStyle(fontSize: 16),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomLayerControls extends StatelessWidget {
  const _BottomLayerControls({
    required this.layerControls,
    required this.onToggle,
    required this.onGainChanged,
  });

  final Map<String, LayerControl> layerControls;
  final void Function(String, bool) onToggle;
  final void Function(String, double) onGainChanged;

  @override
  Widget build(BuildContext context) {
    const specs = [
      _LayerSpec('SPECIES', 'Species\nDensity'),
      _LayerSpec('BAIT DENSITY', 'Bait\nDensity'),
      _LayerSpec('CURRENT', 'Current'),
      _LayerSpec('CURRENT', 'Current @\nDepth'),
      _LayerSpec('WATER TEMP', 'Surface\nTemp'),
      _LayerSpec('DEPTH SHADING', 'Thermocline'),
      _LayerSpec('SPECIES', 'Waypoints /\nMarked Fish'),
      _LayerSpec('WEATHER', 'Weather\nRadar'),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: specs.map((spec) {
        final control = layerControls[spec.key]!;
        return Expanded(
          child: _BottomLayerControl(
            label: spec.label,
            control: control,
            onToggle: () => onToggle(spec.key, !control.enabled),
            onGainChanged: (gain) => onGainChanged(spec.key, gain),
          ),
        );
      }).toList(),
    );
  }
}

class _LayerSpec {
  const _LayerSpec(this.key, this.label);

  final String key;
  final String label;
}

class _BottomLayerControl extends StatelessWidget {
  const _BottomLayerControl({
    required this.label,
    required this.control,
    required this.onToggle,
    required this.onGainChanged,
  });

  final String label;
  final LayerControl control;
  final VoidCallback onToggle;
  final void Function(double) onGainChanged;

  @override
  Widget build(BuildContext context) {
    final active = control.enabled;
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
        decoration: BoxDecoration(
          color: const Color(0xF0060708),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? const Color(0xFFFF7A1A) : const Color(0xFF4D3518),
            width: active ? 2 : 1,
          ),
          boxShadow: [
            if (active)
              const BoxShadow(
                color: Color(0xCCFF6A00),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            const BoxShadow(
              color: Color(0xAA000000),
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active
                        ? const Color(0xFFFFD6A1)
                        : const Color(0xFFD8C6B3),
                    fontSize: 23,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onPanUpdate: (details) {
                final newGain = (control.gain - details.delta.dy * 0.008).clamp(
                  0.0,
                  1.0,
                );
                onGainChanged(newGain);
              },
              child: SizedBox(
                width: 72,
                height: 72,
                child: CustomPaint(
                  painter: _OrangeKnobPainter(
                    value: control.gain,
                    active: active,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                active ? 'Gain' : '${(control.gain * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFFFFC76C),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF120A03),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFFFF6A00)),
                boxShadow: const [
                  BoxShadow(color: Color(0xAAFF6A00), blurRadius: 9),
                ],
              ),
              child: Text(
                active ? 'ON' : 'OFF',
                style: const TextStyle(
                  color: Color(0xFFFFA326),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrangeKnobPainter extends CustomPainter {
  const _OrangeKnobPainter({required this.value, required this.active});

  final double value;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;

    if (active) {
      canvas.drawCircle(
        center,
        radius + 3,
        Paint()
          ..color = const Color(0x77FF6A00)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.35),
          colors: [Color(0xFF2D2D2D), Color(0xFF090909), Color(0xFF000000)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = active ? const Color(0xFFFF8A1A) : const Color(0xFF5A3B17)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    final angle = -math.pi * 0.75 + value * math.pi * 1.5;
    final end = Offset(
      center.dx + (radius - 12) * math.cos(angle),
      center.dy + (radius - 12) * math.sin(angle),
    );
    canvas.drawLine(
      center,
      end,
      Paint()
        ..color = active ? const Color(0xFFFFD28C) : const Color(0xFF8A6A40)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 5, Paint()..color = const Color(0xFF050505));
  }

  @override
  bool shouldRepaint(covariant _OrangeKnobPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.active != active;
}

class _HardwareSide extends StatelessWidget {
  const _HardwareSide({required this.onMenuTap});

  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _RoundSideButton(icon: Icons.arrow_drop_up),
        const SizedBox(height: 12),
        const _RoundSideButton(icon: Icons.add),
        const SizedBox(height: 12),
        const _RoundSideButton(icon: Icons.remove),
        const Spacer(),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFF7A1A), width: 5),
            boxShadow: const [
              BoxShadow(color: Color(0xCCFF6A00), blurRadius: 18),
            ],
            gradient: const RadialGradient(
              colors: [Color(0xFF171717), Color(0xFF030303)],
            ),
          ),
        ),
        const Spacer(),
        const _RockerControl(),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: onMenuTap,
          child: Container(
            width: 96,
            height: 78,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFF6A00), width: 4),
              boxShadow: const [
                BoxShadow(color: Color(0xCCFF6A00), blurRadius: 12),
              ],
            ),
            child: const Text(
              'MENU',
              style: TextStyle(
                color: Color(0xFFFFA326),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundSideButton extends StatelessWidget {
  const _RoundSideButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0xFF2A2D31), Color(0xFF050607)],
        ),
      ),
      child: Icon(icon, color: Color(0xFFBFC5C9), size: 28),
    );
  }
}

class _RockerControl extends StatelessWidget {
  const _RockerControl();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFF080A0C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1B2024), width: 2),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Icon(Icons.arrow_drop_up, color: Color(0xFFC8CED2), size: 36),
          Icon(Icons.arrow_drop_down, color: Color(0xFFC8CED2), size: 36),
        ],
      ),
    );
  }
}

// Data Bezel Panel (left side with toggles, LEDs, and knobs)
// ignore: unused_element
class _DataBezelPanel extends StatelessWidget {
  const _DataBezelPanel({
    required this.layerControls,
    required this.onToggle,
    required this.onGainChanged,
  });

  final Map<String, LayerControl> layerControls;
  final void Function(String, bool) onToggle;
  final void Function(String, double) onGainChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2530), Color(0xFF0D1520)],
        ),
        border: const Border(
          right: BorderSide(color: Color(0xFF2A3A4A), width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 15,
            offset: const Offset(3, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF0A1520),
              border: Border(bottom: BorderSide(color: Color(0xFF2A3A4A))),
            ),
            child: const Row(
              children: [
                Icon(Icons.layers, color: Color(0xFFD7A84A), size: 20),
                SizedBox(width: 8),
                Text(
                  'DATA BEZEL',
                  style: TextStyle(
                    color: Color(0xFFD7A84A),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Layer controls
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: layerControls.entries.map((entry) {
                return _LayerControlRow(
                  name: entry.key,
                  control: entry.value,
                  onToggle: (enabled) => onToggle(entry.key, enabled),
                  onGainChanged: (gain) => onGainChanged(entry.key, gain),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerControlRow extends StatelessWidget {
  const _LayerControlRow({
    required this.name,
    required this.control,
    required this.onToggle,
    required this.onGainChanged,
  });

  final String name;
  final LayerControl control;
  final void Function(bool) onToggle;
  final void Function(double) onGainChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1520),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1A2A35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle + LED row
          Row(
            children: [
              // LED indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: control.enabled
                      ? const Color(0xFFFF3333)
                      : const Color(0xFF3A1515),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: control.enabled
                      ? const [
                          BoxShadow(
                            color: Color(0xFFFF3333),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),

              // Toggle switch (rectangular, soft rubber look)
              GestureDetector(
                onTap: () => onToggle(!control.enabled),
                child: Container(
                  width: 44,
                  height: 26,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: control.enabled
                          ? [const Color(0xFF4A5D6A), const Color(0xFF2A3A45)]
                          : [const Color(0xFF2A3540), const Color(0xFF1A2530)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: control.enabled
                          ? const Color(0xFF5A6D7A)
                          : const Color(0xFF1A2530),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.1),
                        blurRadius: 1,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeInOut,
                        left: control.enabled ? 22 : 2,
                        top: 2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: control.enabled
                                  ? [
                                      const Color(0xFF6A7D8A),
                                      const Color(0xFF4A5D6A),
                                    ]
                                  : [
                                      const Color(0xFF3A4550),
                                      const Color(0xFF2A3540),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Layer name
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: control.enabled
                        ? const Color(0xFFE8F1F3)
                        : const Color(0xFF5A6A75),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // GAIN label + knob
          Row(
            children: [
              const SizedBox(width: 16),
              const Text(
                'GAIN',
                style: TextStyle(
                  color: Color(0xFF5A6A75),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 6),

              // Rotary knob (slightly bigger)
              GestureDetector(
                onPanUpdate: (details) {
                  final change = -details.delta.dy * 0.008;
                  final newGain = (control.gain + change).clamp(0.0, 1.0);
                  onGainChanged(newGain);
                },
                child: _RotaryKnob(
                  value: control.gain,
                  enabled: control.enabled,
                ),
              ),

              const SizedBox(width: 4),

              // Value display
              Container(
                width: 28,
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1A22),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF1A2A35)),
                ),
                child: Text(
                  '${(control.gain * 100).round()}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: control.enabled
                        ? const Color(0xFF70C4D4)
                        : const Color(0xFF3A4A55),
                    fontSize: 9,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RotaryKnob extends StatelessWidget {
  const _RotaryKnob({required this.value, required this.enabled});

  final double value;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: CustomPaint(
        painter: _KnobPainter(value: value, enabled: enabled),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  _KnobPainter({required this.value, required this.enabled});

  final double value;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Outer ring
    final outerPaint = Paint()
      ..color = const Color(0xFF1A3040)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, outerPaint);

    // Knob body gradient
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF4A6070), const Color(0xFF2A3A4A)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius - 3, bodyPaint);

    // Indicator line
    final angle = -math.pi * 0.75 + value * math.pi * 1.5;
    final indicatorEnd = Offset(
      center.dx + (radius - 6) * math.cos(angle),
      center.dy + (radius - 6) * math.sin(angle),
    );

    final indicatorPaint = Paint()
      ..color = enabled ? const Color(0xFFD7A84A) : const Color(0xFF4A6070)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, indicatorEnd, indicatorPaint);

    // Center dot
    final centerDotPaint = Paint()
      ..color = const Color(0xFF0D1F28)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _KnobPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.enabled != enabled;
}

// Chart Area with data overlays
// ignore: unused_element
class _ChartArea extends StatelessWidget {
  const _ChartArea({required this.layerControls});

  final Map<String, LayerControl> layerControls;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1520), Color(0xFF07131A)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(5, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CustomPaint(
          painter: _ChartPainter(layerControls: layerControls),
          child: Container(),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.layerControls});

  final Map<String, LayerControl> layerControls;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0A1A25), Color(0xFF07131A)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFF1A3040).withValues(alpha: 0.5)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Depth shading overlay
    if (layerControls['DEPTH SHADING']!.enabled) {
      _drawDepthShading(canvas, size);
    }

    // Contours overlay
    if (layerControls['CONTOURS']!.enabled) {
      _drawContours(canvas, size, layerControls['CONTOURS']!.gain);
    }

    // Bait density overlay
    if (layerControls['BAIT DENSITY']!.enabled) {
      _drawBaitDensity(canvas, size, layerControls['BAIT DENSITY']!.gain);
    }

    // Species overlay
    if (layerControls['SPECIES']!.enabled) {
      _drawSpecies(canvas, size, layerControls['SPECIES']!.gain);
    }

    // Current overlay
    if (layerControls['CURRENT']!.enabled) {
      _drawCurrents(canvas, size, layerControls['CURRENT']!.gain);
    }

    // Water temp overlay
    if (layerControls['WATER TEMP']!.enabled) {
      _drawWaterTemp(canvas, size, layerControls['WATER TEMP']!.gain);
    }

    // Weather overlay
    if (layerControls['WEATHER']!.enabled) {
      _drawWeather(canvas, size, layerControls['WEATHER']!.gain);
    }

    // Boat indicator
    _drawBoat(canvas, center);
  }

  void _drawDepthShading(Canvas canvas, Size size) {
    final depthPaint = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x000A1520), Color(0x40103020), Color(0x50204030)],
          ).createShader(
            Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.6),
          );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.6),
      depthPaint,
    );
  }

  void _drawText(Canvas canvas, String text, Offset position, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, position);
  }

  void _drawContours(Canvas canvas, Size size, double gain) {
    final paint = Paint()
      ..color = const Color(0xFF2A5060).withValues(alpha: gain)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path1 = Path();
    path1.moveTo(size.width * 0.1, size.height * 0.3);
    path1.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.25,
      size.width * 0.5,
      size.height * 0.4,
    );
    path1.quadraticBezierTo(
      size.width * 0.7,
      size.height * 0.55,
      size.width * 0.9,
      size.height * 0.5,
    );
    canvas.drawPath(path1, paint);

    final path2 = Path();
    path2.moveTo(size.width * 0.15, size.height * 0.5);
    path2.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.6,
      size.width * 0.6,
      size.height * 0.55,
    );
    path2.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.5,
      size.width * 0.85,
      size.height * 0.7,
    );
    canvas.drawPath(
      path2,
      paint..color = const Color(0xFF1A4050).withValues(alpha: gain),
    );

    // Depth markers
    _drawText(
      canvas,
      '42ft',
      Offset(size.width * 0.2, size.height * 0.35),
      const Color(0xFF4A7080).withValues(alpha: gain),
    );
    _drawText(
      canvas,
      '58ft',
      Offset(size.width * 0.5, size.height * 0.45),
      const Color(0xFF4A7080).withValues(alpha: gain),
    );
    _drawText(
      canvas,
      '75ft',
      Offset(size.width * 0.7, size.height * 0.6),
      const Color(0xFF4A7080).withValues(alpha: gain),
    );
  }

  void _drawBaitDensity(Canvas canvas, Size size, double gain) {
    final opacity = gain * 0.6;

    // Bait fish schools (small circles)
    final baitPaint = Paint()
      ..color = const Color(0xFF80A040).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    // School 1
    final center1 = Offset(size.width * 0.35, size.height * 0.4);
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final x = center1.dx + 15 * math.cos(angle);
      final y = center1.dy + 15 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 3, baitPaint);
    }
    canvas.drawCircle(
      center1,
      5,
      baitPaint..color = const Color(0xFF90B050).withValues(alpha: opacity),
    );

    // School 2
    final center2 = Offset(size.width * 0.65, size.height * 0.55);
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final x = center2.dx + 12 * math.cos(angle);
      final y = center2.dy + 12 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 2.5, baitPaint);
    }
  }

  void _drawSpecies(Canvas canvas, Size size, double gain) {
    final opacity = gain * 0.8;
    final speciesPaint = Paint()
      ..color = const Color(0xFFE46353).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    // Fish markers (trophy size)
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.35),
      6,
      speciesPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.6),
      5,
      speciesPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.45),
      7,
      speciesPaint,
    );

    // Fish icons
    final iconPaint = Paint()
      ..color = const Color(0xFFFF6B6B).withValues(alpha: opacity)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    _drawFishIcon(
      canvas,
      Offset(size.width * 0.3, size.height * 0.35),
      12,
      iconPaint,
    );
    _drawFishIcon(
      canvas,
      Offset(size.width * 0.75, size.height * 0.45),
      14,
      iconPaint,
    );
  }

  void _drawFishIcon(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx - size, center.dy)
      ..quadraticBezierTo(
        center.dx - size / 2,
        center.dy - size / 2,
        center.dx + size / 2,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + size,
        center.dy + size / 3,
        center.dx + size,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + size,
        center.dy - size / 3,
        center.dx + size / 2,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - size / 2,
        center.dy + size / 2,
        center.dx - size,
        center.dy,
      );
    canvas.drawPath(path, paint);
  }

  void _drawCurrents(Canvas canvas, Size size, double gain) {
    final opacity = gain * 0.5;
    final currentPaint = Paint()
      ..color = const Color(0xFF40A0D0).withValues(alpha: opacity)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Current arrows
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 5; col++) {
        final x = size.width * (0.2 + col * 0.15);
        final y = size.height * (0.3 + row * 0.2);
        final arrowLength = 20 + gain * 15;

        // Main line
        canvas.drawLine(
          Offset(x - arrowLength / 2, y),
          Offset(x + arrowLength / 2, y),
          currentPaint,
        );
        // Arrow head
        canvas.drawLine(
          Offset(x + arrowLength / 2, y),
          Offset(x + arrowLength / 2 - 6, y - 4),
          currentPaint,
        );
        canvas.drawLine(
          Offset(x + arrowLength / 2, y),
          Offset(x + arrowLength / 2 - 6, y + 4),
          currentPaint,
        );
      }
    }
  }

  void _drawWaterTemp(Canvas canvas, Size size, double gain) {
    // Temperature gradient overlay
    final tempPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x004080FF), Color(0x0080D0FF), Color(0x00FF8040)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), tempPaint);

    // Temperature legend
    final textColor = const Color(0xFF70C4D4).withValues(alpha: gain);
    _drawText(
      canvas,
      '58°F',
      Offset(size.width - 50, size.height - 30),
      textColor,
    );
    _drawText(canvas, '42°F', Offset(10, 20), textColor);
  }

  void _drawWeather(Canvas canvas, Size size, double gain) {
    final weatherPaint = Paint()
      ..color = const Color(0xFF607080).withValues(alpha: gain)
      ..strokeWidth = 1;

    // Wind direction indicators
    for (int i = 0; i < 4; i++) {
      final x = size.width * (0.2 + i * 0.2);
      final y = 30.0;

      // Cloud symbol
      canvas.drawCircle(
        Offset(x, y),
        8,
        weatherPaint..style = PaintingStyle.fill,
      );
      canvas.drawCircle(Offset(x + 6, y - 3), 6, weatherPaint);
      canvas.drawCircle(Offset(x + 10, y), 7, weatherPaint);
    }
  }

  void _drawBoat(Canvas canvas, Offset center) {
    // Boat body
    final boatPaint = Paint()
      ..color = const Color(0xFFD7A84A)
      ..style = PaintingStyle.fill;

    final boatPath = Path()
      ..moveTo(center.dx, center.dy - 16)
      ..lineTo(center.dx - 10, center.dy + 10)
      ..lineTo(center.dx, center.dy + 6)
      ..lineTo(center.dx + 10, center.dy + 10)
      ..close();
    canvas.drawPath(boatPath, boatPaint);

    // Heading line
    final headingPaint = Paint()
      ..color = const Color(0xFFFF6B6B).withValues(alpha: 0.8)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(center.dx, center.dy - 16),
      Offset(center.dx + 60, center.dy - 45),
      headingPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;
}

// ignore: unused_element
class _MenuButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MenuButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A3A4A), Color(0xFF1A2A3A)],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3A4A5A)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: const Icon(Icons.menu, color: Color(0xFFD7A84A), size: 28),
      ),
    );
  }
}

// ignore: unused_element
class _CompassWidget extends StatelessWidget {
  const _CompassWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xCC0D1F28),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF40606D), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(64, 64), painter: _CompassPainter()),
          const Text(
            '045°',
            style: TextStyle(
              color: Color(0xFFD7A84A),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFF8FB3BE)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // N indicator
    final nPath = Path()
      ..moveTo(center.dx, center.dy - 26)
      ..lineTo(center.dx - 4, center.dy - 20)
      ..moveTo(center.dx, center.dy - 26)
      ..lineTo(center.dx + 4, center.dy - 20);
    canvas.drawPath(nPath, paint);

    // Degree marks
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final inner = center.dx + 24 * math.cos(angle);
      final innerY = center.dy + 24 * math.sin(angle);
      final outer = center.dx + 28 * math.cos(angle);
      final outerY = center.dy + 28 * math.sin(angle);
      canvas.drawLine(
        Offset(inner, innerY),
        Offset(outer, outerY),
        paint..strokeWidth = i % 2 == 0 ? 2 : 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ignore: unused_element
class _TopInfoBar extends StatelessWidget {
  const _TopInfoBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1520).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A3A4A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.anchor, color: Color(0xFFD7A84A), size: 18),
          const SizedBox(width: 8),
          const Flexible(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'LAKE COMMAND IN DEPTH',
                style: TextStyle(
                  color: Color(0xFFD7A84A),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Flexible(
            flex: 4,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 4,
              children: [
                _DataChip(label: 'LAT', value: '42.485'),
                _DataChip(label: 'LON', value: '-86.415'),
                _DataChip(label: 'SPD', value: '5.2 kn'),
                _DataChip(label: 'HDG', value: '045°'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DataChip extends StatelessWidget {
  final String label;
  final String value;
  const _DataChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Color(0xFF6A8090),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF70C4D4),
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ToolboxMenu extends StatelessWidget {
  final VoidCallback onClose;
  const _ToolboxMenu({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2530), Color(0xFF0D1520)],
        ),
        border: const Border(
          right: BorderSide(color: Color(0xFF3A4A5A), width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF2A3A4A))),
            ),
            child: Row(
              children: [
                const Icon(Icons.settings, color: Color(0xFFD7A84A), size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'TOOLBOX',
                    style: TextStyle(
                      color: Color(0xFFD7A84A),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A3A4A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Color(0xFF70C4D4),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: const [
                _MenuItem(icon: Icons.speed, label: 'Settings'),
                _MenuItem(icon: Icons.book, label: "Captain's Log"),
                _MenuItem(icon: Icons.history, label: 'Historical Data'),
                _MenuItem(icon: Icons.emoji_events, label: 'Tournaments'),
                _MenuItem(icon: Icons.cloud, label: 'Weather'),
                _MenuItem(icon: Icons.credit_card, label: 'Subscription'),
                _MenuItem(
                  icon: Icons.warning,
                  label: 'Emergency Waypoint Contact',
                ),
                _MenuItem(icon: Icons.link, label: 'API & Data Sources'),
                _MenuItem(icon: Icons.person, label: 'User Settings'),
                Divider(color: Color(0xFF2A3A4A)),
                _MenuItem(
                  icon: Icons.logout,
                  label: 'Log Out',
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;
  const _MenuItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? const Color(0xFFE46353)
        : const Color(0xFFE8F1F3);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1520),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A3A4A)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color.withValues(alpha: 0.8), size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: color.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
