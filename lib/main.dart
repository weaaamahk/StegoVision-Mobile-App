import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

void main() {
  runApp(const StegoVisionApp());
}

// ============================================================
// APP
// ============================================================

class StegoVisionApp extends StatelessWidget {
  const StegoVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StegoVision',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ============================================================
// HOME
// ============================================================

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'StegoVision',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.security,
              size: 90,
            ),

            const SizedBox(height: 20),

            const Text(
              'StegoVision',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Secure Image Steganography',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
              ),
            ),

            const SizedBox(height: 50),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HidePage(),
                  ),
                );
              },
              icon: const Icon(Icons.lock),
              label: const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Hide Message',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExtractPage(),
                  ),
                );
              },
              icon: const Icon(Icons.lock_open),
              label: const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Extract Message',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),

            const SizedBox(height: 40),

            const Text(
              'Your data stays on your device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HIDE PAGE
// ============================================================

class HidePage extends StatefulWidget {
  const HidePage({super.key});

  @override
  State<HidePage> createState() => _HidePageState();
}

class _HidePageState extends State<HidePage> {
  final ImagePicker picker = ImagePicker();

  File? selectedImage;

  final TextEditingController messageController =
      TextEditingController();

  bool isProcessing = false;

  // ----------------------------------------------------------
  // PICK IMAGE
  // ----------------------------------------------------------

  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null) return;

    setState(() {
      selectedImage = File(image.path);
    });
  }

  // ----------------------------------------------------------
  // HIDE MESSAGE
  // ----------------------------------------------------------

  Future<void> hideMessage() async {
    if (selectedImage == null) {
      showMessage('Please select an image first.');
      return;
    }

    if (messageController.text.trim().isEmpty) {
      showMessage('Please enter a secret message.');
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      final Uint8List bytes =
          await selectedImage!.readAsBytes();

      final img.Image? image =
          img.decodeImage(bytes);

      if (image == null) {
        showMessage('Unable to read image.');
        return;
      }

      final Uint8List messageBytes =
          Uint8List.fromList(
        utf8.encode(messageController.text),
      );

      final List<int> data = [];

      final int length = messageBytes.length;

      // Store message length in 32 bits
      for (int i = 3; i >= 0; i--) {
        data.add(
          (length >> (i * 8)) & 0xFF,
        );
      }

      data.addAll(messageBytes);

      final int totalBits =
          data.length * 8;

      final int availableBits =
          image.width *
              image.height *
              3;

      if (totalBits > availableBits) {
        showMessage(
          'Message is too large for this image.',
        );
        return;
      }

      // --------------------------------------------------------
      // LSB EMBEDDING
      // --------------------------------------------------------

      int bitIndex = 0;

      for (int y = 0;
          y < image.height;
          y++) {
        for (int x = 0;
            x < image.width;
            x++) {
          final pixel =
              image.getPixel(x, y);

          int r = pixel.r.toInt();
          int g = pixel.g.toInt();
          int b = pixel.b.toInt();

          if (bitIndex < totalBits) {
            final int bit =
                getBit(data, bitIndex);

            r = (r & 0xFE) | bit;
            bitIndex++;
          }

          if (bitIndex < totalBits) {
            final int bit =
                getBit(data, bitIndex);

            g = (g & 0xFE) | bit;
            bitIndex++;
          }

          if (bitIndex < totalBits) {
            final int bit =
                getBit(data, bitIndex);

            b = (b & 0xFE) | bit;
            bitIndex++;
          }

          image.setPixelRgb(
            x,
            y,
            r,
            g,
            b,
          );

          if (bitIndex >= totalBits) {
            break;
          }
        }

        if (bitIndex >= totalBits) {
          break;
        }
      }

      // --------------------------------------------------------
      // SAVE PNG
      // --------------------------------------------------------

      final Uint8List output =
          Uint8List.fromList(
        img.encodePng(image),
      );

      final Directory directory =
          await getApplicationDocumentsDirectory();

      final String filePath =
          '${directory.path}/stegovision_${DateTime.now().millisecondsSinceEpoch}.png';

      final File outputFile =
          File(filePath);

      await outputFile.writeAsBytes(output);

      // Save to Gallery
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }

      await Gal.putImageBytes(
        output,
        album: 'StegoVision',
      );

      if (!mounted) return;

      // --------------------------------------------------------
      // RESULT PAGE
      // --------------------------------------------------------

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultPage(
            imageFile: outputFile,
            title: 'Message Hidden Successfully',
          ),
        ),
      );
    } catch (e) {
      showMessage('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  int getBit(
    List<int> data,
    int bitIndex,
  ) {
    final int byteIndex =
        bitIndex ~/ 8;

    final int bitPosition =
        7 - (bitIndex % 8);

    return (data[byteIndex] >>
            bitPosition) &
        1;
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hide Message'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Hide a secret message inside an image.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 25),

            ElevatedButton.icon(
              onPressed:
                  isProcessing ? null : pickImage,
              icon: const Icon(Icons.image),
              label: const Text('Select Image'),
            ),

            const SizedBox(height: 20),

            if (selectedImage != null)
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(15),
                child: Image.file(
                  selectedImage!,
                  height: 260,
                  fit: BoxFit.cover,
                ),
              ),

            const SizedBox(height: 20),

            TextField(
              controller: messageController,
              maxLines: 5,
              decoration:
                  const InputDecoration(
                labelText: 'Secret Message',
                hintText:
                    'Enter your secret message',
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed:
                  isProcessing
                      ? null
                      : hideMessage,
              icon: const Icon(Icons.lock),
              label: const Text(
                'Hide Message',
              ),
            ),

            if (isProcessing)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child:
                      CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }
}

// ============================================================
// EXTRACT PAGE
// ============================================================

class ExtractPage extends StatefulWidget {
  const ExtractPage({super.key});

  @override
  State<ExtractPage> createState() =>
      _ExtractPageState();
}

class _ExtractPageState
    extends State<ExtractPage> {
  final ImagePicker picker = ImagePicker();

  File? selectedImage;

  String extractedMessage = '';

  bool isProcessing = false;

  // ----------------------------------------------------------
  // PICK IMAGE
  // ----------------------------------------------------------

  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null) return;

    setState(() {
      selectedImage = File(image.path);
      extractedMessage = '';
    });
  }

  // ----------------------------------------------------------
  // EXTRACT MESSAGE
  // ----------------------------------------------------------

  Future<void> extractMessage() async {
    if (selectedImage == null) {
      showMessage('Please select an image first.');
      return;
    }

    setState(() {
      isProcessing = true;
      extractedMessage = '';
    });

    try {
      final Uint8List bytes =
          await selectedImage!.readAsBytes();

      final img.Image? image =
          img.decodeImage(bytes);

      if (image == null) {
        showMessage('Unable to read image.');
        return;
      }

      final List<int> bits = [];

      // Read LSBs
      for (int y = 0;
          y < image.height;
          y++) {
        for (int x = 0;
            x < image.width;
            x++) {
          final pixel =
              image.getPixel(x, y);

          final int r =
              pixel.r.toInt();

          final int g =
              pixel.g.toInt();

          final int b =
              pixel.b.toInt();

          bits.add(r & 1);
          bits.add(g & 1);
          bits.add(b & 1);
        }
      }

      if (bits.length < 32) {
        showMessage(
          'No hidden message found.',
        );
        return;
      }

      // Read message length
      int messageLength = 0;

      for (int i = 0; i < 32; i++) {
        messageLength =
            (messageLength << 1) |
                bits[i];
      }

      if (messageLength <= 0) {
        showMessage(
          'This image does not contain a valid message.',
        );
        return;
      }

      final int requiredBits =
          32 +
              (messageLength * 8);

      if (requiredBits > bits.length) {
        showMessage(
          'This image does not contain a valid message.',
        );
        return;
      }

      final List<int> messageBytes = [];

      for (int byteIndex = 0;
          byteIndex < messageLength;
          byteIndex++) {
        int value = 0;

        for (int bit = 0;
            bit < 8;
            bit++) {
          final int index =
              32 +
                  (byteIndex * 8) +
                  bit;

          value =
              (value << 1) |
                  bits[index];
        }

        messageBytes.add(value);
      }

      final String message =
          utf8.decode(messageBytes);

      if (!mounted) return;

      setState(() {
        extractedMessage = message;
      });

      // --------------------------------------------------------
      // RESULT PAGE
      // --------------------------------------------------------

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultPage(
            imageFile: selectedImage!,
            title: 'Message Extracted',
            message: message,
          ),
        ),
      );
    } catch (e) {
      showMessage(
        'Unable to extract message.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Message'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Extract a hidden message from a stego-image.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 25),

            ElevatedButton.icon(
              onPressed:
                  isProcessing ? null : pickImage,
              icon: const Icon(Icons.image),
              label: const Text(
                'Select Encoded Image',
              ),
            ),

            const SizedBox(height: 20),

            if (selectedImage != null)
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(15),
                child: Image.file(
                  selectedImage!,
                  height: 260,
                  fit: BoxFit.cover,
                ),
              ),

            const SizedBox(height: 20),

            OutlinedButton.icon(
              onPressed:
                  isProcessing
                      ? null
                      : extractMessage,
              icon: const Icon(
                Icons.lock_open,
              ),
              label: const Text(
                'Extract Message',
              ),
            ),

            if (isProcessing)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child:
                      CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// RESULT PAGE
// ============================================================

class ResultPage extends StatelessWidget {
  final File imageFile;
  final String title;
  final String? message;

  const ResultPage({
    super.key,
    required this.imageFile,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle,
              size: 80,
            ),

            const SizedBox(height: 15),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 25),

            ClipRRect(
              borderRadius:
                  BorderRadius.circular(15),
              child: Image.file(
                imageFile,
                height: 280,
                fit: BoxFit.cover,
              ),
            ),

            if (message != null) ...[
              const SizedBox(height: 25),

              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Extracted Message',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        message!,
                        style:
                            const TextStyle(
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: () {
                Navigator.popUntil(
                  context,
                  (route) => route.isFirst,
                );
              },
              child: const Text(
                'Back to Home',
              ),
            ),
          ],
        ),
      ),
    );
  }
}