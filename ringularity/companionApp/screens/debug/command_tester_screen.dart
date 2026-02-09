import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/ble/ble_service.dart';

class CommandTesterScreen extends StatefulWidget {
  const CommandTesterScreen({super.key});

  @override
  State<CommandTesterScreen> createState() => _CommandTesterScreenState();
}

class _CommandTesterScreenState extends State<CommandTesterScreen> {
  final TextEditingController _hexController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();

  @override
  void dispose() {
    _hexController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  void _sendHex() {
    final text = _hexController.text.replaceAll(' ', '');
    // Need even number of chars
    if (text.length % 2 != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hex string must be even length")));
      return;
    }

    try {
      List<int> bytes = [];
      for (int i = 0; i < text.length; i += 2) {
        bytes.add(int.parse(text.substring(i, i + 2), radix: 16));
      }
      Provider.of<BleService>(context, listen: false).sendRawPacket(bytes);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Invalid Hex: $e")));
    }
  }

  void _sendPreset(String name, List<int> packet) {
    Provider.of<BleService>(context, listen: false).sendRawPacket(packet);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text("Sent $name"),
          duration: const Duration(milliseconds: 500)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Command Tester")),
      body: Consumer<BleService>(
        builder: (context, ble, child) {
          // Auto-scroll to bottom of log
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_logScrollController.hasClients) {
              _logScrollController
                  .jumpTo(_logScrollController.position.maxScrollExtent);
            }
          });

          return Column(
            children: [
              // 1. Presets Area
              Container(
                height: 120,
                padding: const EdgeInsets.all(8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildPresetBtn("DISABLE HR (0x16)", [
                      0x16,
                      0x02,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x18
                    ]),
                    _buildPresetBtn("STOP HR (0x69..00)", [
                      0x69,
                      0x01,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x6A
                    ]),
                    _buildPresetBtn("START HR (0x69..01)", [
                      0x69,
                      0x01,
                      0x01,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x6B
                    ]),
                    _buildPresetBtn("DISABLE SpO2 (0x2C)", [
                      0x2C,
                      0x02,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x2E
                    ]),
                    _buildPresetBtn("STOP SpO2 (0x69..00)", [
                      0x69,
                      0x03,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x6C
                    ]),
                    _buildPresetBtn("START SpO2 (0x69..01)", [
                      0x69,
                      0x03,
                      0x01,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x6D
                    ]),
                    _buildPresetBtn("Disable Raw (0xA1 02)", [
                      0xA1,
                      0x02,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0xA1 + 0x02
                    ]),
                    _buildPresetBtn("Disable Stress (0x36)", [
                      0x36,
                      0x02,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x38
                    ]),
                    _buildPresetBtn("Reboot (0x08)", [
                      0x08,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x08
                    ]),
                    _buildPresetBtn("Check HR Cfg (16 01)", [
                      0x16,
                      0x01,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x17
                    ]),
                    _buildPresetBtn("Check SpO2 Cfg (2C 01)", [
                      0x2C,
                      0x01,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x2D
                    ]),
                    _buildPresetBtn("Get Battery (03)", [0x03]),
                    _buildPresetBtn("Test 3B (3B 01)", [
                      0x3B,
                      0x01,
                      0x01,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x3D
                    ]),
                  ],
                ),
              ),
              const Divider(),

              // 2. Custom Input Area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _hexController,
                        decoration: const InputDecoration(
                          labelText: "Custom Hex (e.g. 690100)",
                          hintText: "Enter hex bytes",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _sendHex,
                      child: const Text("Send"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. Log Area
              Expanded(
                child: Container(
                  color: Colors.black87,
                  child: ListView.builder(
                    controller: _logScrollController,
                    itemCount: ble.protocolLog.length,
                    itemBuilder: (context, index) {
                      final log = ble.protocolLog[index];
                      final isTx = log.contains("TX:");
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        child: Text(
                          log,
                          style: TextStyle(
                            color: isTx
                                ? Colors.greenAccent
                                : Colors.lightBlueAccent,
                            fontFamily: 'Monospace',
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPresetBtn(String label, List<int> packet) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () => _sendPreset(label, packet),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(60, 40),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
