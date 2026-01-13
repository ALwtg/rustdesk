import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../common.dart';
import '../../models/platform_model.dart';
import '../../models/input_model.dart';

class OverlayButtonConfig {
  String id;
  String label;
  List<String> keys;
  double x;
  double y;
  bool isHolding = false;

  OverlayButtonConfig({
    required this.id,
    required this.label,
    required this.keys,
    this.x = 100,
    this.y = 100,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'keys': keys,
    'x': x,
    'y': y,
  };

  factory OverlayButtonConfig.fromJson(Map<String, dynamic> json) {
    return OverlayButtonConfig(
      id: json['id'] ?? DateTime.now().toString(),
      label: json['label'] ?? 'Btn',
      keys: List<String>.from(json['keys'] ?? []),
      x: json['x']?.toDouble() ?? 100.0,
      y: json['y']?.toDouble() ?? 100.0,
    );
  }
}

class CustomOverlayButtons extends StatefulWidget {
  final InputModel inputModel;

  const CustomOverlayButtons({Key? key, required this.inputModel}) : super(key: key);

  @override
  State<CustomOverlayButtons> createState() => _CustomOverlayButtonsState();
}

class _CustomOverlayButtonsState extends State<CustomOverlayButtons> {
  List<OverlayButtonConfig> buttons = [];
  bool showButtons = true;
  Offset togglePos = const Offset(50, 50);
  Offset keyboardTogglePos = const Offset(50, 120);
  final String _prefKey = 'custom_overlay_buttons_config_v2';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() async {
    String configStr = await bind.mainGetLocalOption(key: _prefKey);
    if (configStr.isNotEmpty) {
      try {
        final data = jsonDecode(configStr);
        if (data is Map) {
          if (data['buttons'] != null) {
            buttons = (data['buttons'] as List)
                .map((e) => OverlayButtonConfig.fromJson(e))
                .toList();
          }
          if (data['togglePos'] != null) {
            togglePos = Offset(data['togglePos']['x'], data['togglePos']['y']);
          }
          if (data['keyboardTogglePos'] != null) {
            keyboardTogglePos = Offset(data['keyboardTogglePos']['x'], data['keyboardTogglePos']['y']);
          }
        }
      } catch (e) {
        debugPrint("Failed to load overlay config: $e");
      }
    } else {
      // Defaults
      buttons.add(OverlayButtonConfig(id: '1', label: 'Ctrl+C', keys: ['control', 'c'], x: 100, y: 200));
      buttons.add(OverlayButtonConfig(id: '2', label: 'Ctrl+V', keys: ['control', 'v'], x: 200, y: 200));
    }
    setState(() {});
  }

  void _saveConfig() {
    final data = {
      'buttons': buttons.map((e) => e.toJson()).toList(),
      'togglePos': {'x': togglePos.dx, 'y': togglePos.dy},
      'keyboardTogglePos': {'x': keyboardTogglePos.dx, 'y': keyboardTogglePos.dy},
    };
    bind.mainSetLocalOption(key: _prefKey, value: jsonEncode(data));
  }

  void _sendKey(OverlayButtonConfig btn, {bool? down, bool? press}) {
    bool ctrl = btn.keys.contains('control');
    bool alt = btn.keys.contains('alt');
    bool shift = btn.keys.contains('shift');
    bool command = btn.keys.contains('command');
    
    // Update InputModel state if it's a hold action (down != null)
    if (down != null) {
      if (ctrl) widget.inputModel.ctrl = down;
      if (alt) widget.inputModel.alt = down;
      if (shift) widget.inputModel.shift = down;
      if (command) widget.inputModel.command = down;
    }

    String? key;
    for (var k in btn.keys) {
      if (!['control', 'alt', 'shift', 'command'].contains(k)) {
        key = k;
        break;
      }
    }

    if (key == null && (ctrl || alt || shift || command)) {
       // Only modifiers
       // Use the first modifier as the key name for sessionInputKey
       key = btn.keys.first;
    }
    
    if (key != null) {
      bind.sessionInputKey(
        sessionId: widget.inputModel.sessionId,
        name: key,
        down: down ?? false,
        press: press ?? false,
        alt: alt,
        ctrl: ctrl,
        shift: shift,
        command: command,
      );
    }
  }

  void _showEditDialog({OverlayButtonConfig? btn}) {
    final isNew = btn == null;
    final config = btn ?? OverlayButtonConfig(id: DateTime.now().toString(), label: '', keys: []);
    final labelController = TextEditingController(text: config.label);
    final keysController = TextEditingController(text: config.keys.join(' '));

    final shortcuts = ['control', 'alt', 'shift', 'command', 'win', 'delete', 'esc', 'tab'];

    Get.dialog(
      AlertDialog(
        title: Text(isNew ? 'Add Button' : 'Edit Button'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Label (e.g. Ctrl+C)'),
              ),
              TextField(
                controller: keysController,
                decoration: const InputDecoration(labelText: 'Keys (space sep, e.g. control c)'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: shortcuts.map((k) => ActionChip(
                  label: Text(k),
                  onPressed: () {
                    final current = keysController.text.trim();
                    keysController.text = current.isEmpty ? k : '$current $k';
                    // Update label if empty or simple append
                    if (labelController.text.isEmpty) {
                      labelController.text = k == 'control' ? 'Ctrl' : k.capitalizeFirst!;
                    } else if (!labelController.text.contains('+') && labelController.text.length < 5) {
                       // Try to smart append label? Maybe not.
                    }
                  },
                )).toList(),
              ),
              const SizedBox(height: 10),
              const Text('Supported: control, alt, shift, command, a-z, 0-9, f1-f12...'),
            ],
          ),
        ),
        actions: [
          if (!isNew)
            TextButton(
              onPressed: () {
                setState(() {
                  buttons.remove(btn);
                });
                _saveConfig();
                Get.back();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              config.label = labelController.text;
              config.keys = keysController.text.split(' ').where((e) => e.isNotEmpty).toList();
              if (isNew) {
                setState(() {
                  buttons.add(config);
                });
              } else {
                setState(() {});
              }
              _saveConfig();
              Get.back();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    double clampDouble(double v, double min, double max) =>
        v.clamp(min, max).toDouble();
    Offset clampOffset(Offset p, double w, double h) {
      final maxX = (screenSize.width - w);
      final maxY = (screenSize.height - h);
      return Offset(
        clampDouble(p.dx, 0, maxX > 0 ? maxX : 0),
        clampDouble(p.dy, 0, maxY > 0 ? maxY : 0),
      );
    }

    final togglePosClamped = clampOffset(togglePos, 40, 40);
    final keyboardTogglePosClamped = clampOffset(keyboardTogglePos, 40, 40);
    return Stack(
      children: [
        if (showButtons)
          ...buttons.map((btn) => Positioned(
            left: clampDouble(btn.x, 0, (screenSize.width - 80) > 0 ? (screenSize.width - 80) : 0),
            top: clampDouble(btn.y, 0, (screenSize.height - 40) > 0 ? (screenSize.height - 40) : 0),
            child: GestureDetector(
              onTap: () {
                _sendKey(btn, press: true);
              },
              onDoubleTap: () {
                setState(() {
                  btn.isHolding = !btn.isHolding;
                });
                _sendKey(btn, down: btn.isHolding);
              },
              onPanUpdate: (d) {
                setState(() {
                  btn.x += d.delta.dx;
                  btn.y += d.delta.dy;
                });
                _saveConfig();
              },
              onLongPress: () {
                _showEditDialog(btn: btn);
              },
              child: Container(
                width: 80, // ~2cm
                height: 40, // ~1cm
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: btn.isHolding ? Colors.blue : Colors.grey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.white, width: 0.5),
                ),
                child: Text(
                  btn.label,
                  style: const TextStyle(color: Colors.white, fontSize: 12, decoration: TextDecoration.none),
                ),
              ),
            ),
          )).toList(),
        
        // Toggle Button
        Positioned(
          left: togglePosClamped.dx,
          top: togglePosClamped.dy,
          child: GestureDetector(
            onTap: () {
              setState(() {
                showButtons = !showButtons;
              });
            },
            onPanUpdate: (d) {
              setState(() {
                togglePos += d.delta;
              });
              _saveConfig();
            },
            onLongPress: () {
                _showEditDialog(btn: null); // Add new
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: showButtons ? Colors.blue : Colors.grey.withOpacity(0.5),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Icon(Icons.layers, color: Colors.white, size: 20),
            ),
          ),
        ),

        // Keyboard Toggle
        Positioned(
          left: keyboardTogglePosClamped.dx,
          top: keyboardTogglePosClamped.dy,
          child: GestureDetector(
            onTap: () {
               // Toggle logic
               if (MediaQuery.of(context).viewInsets.bottom > 0) {
                   // Hide keyboard
                   gFFI.invokeMethod("enable_soft_keyboard", false);
                   SystemChannels.textInput.invokeMethod('TextInput.hide');
                   FocusManager.instance.primaryFocus?.unfocus();
               } else {
                   // Show keyboard
                   gFFI.invokeMethod("enable_soft_keyboard", true);
                   SystemChannels.textInput.invokeMethod('TextInput.show');
               }
            },
            onPanUpdate: (d) {
              setState(() {
                keyboardTogglePos += d.delta;
              });
              _saveConfig();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MediaQuery.of(context).viewInsets.bottom > 0 ? Colors.blue : Colors.grey.withOpacity(0.5),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Icon(Icons.keyboard, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}
