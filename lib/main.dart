import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyB4fl-TW_HVtW99IXLyExfgiDrm2OkZTuM",
      appId: "1:395736519154:android:e139d66fe6ade95ea61b6b",
      messagingSenderId: "395736519154",
      projectId: "play-music-54f16",
    ),
  );

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Play Music',
    home: AuthGate(),
  ));
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return const MusicPlayerApp();
        }
        return const LoginScreen();
      },
    );
  }
}
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isCreateAccount = false;
  bool isLoading = false;
  String errorMessage = '';

  Future<void> handleAuth() async {
    setState(() {
      errorMessage = '';
      isLoading = true;
    });
    try {
      if (isCreateAccount) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = e.message ?? 'Something went wrong!');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: EpoxyBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.music_note_rounded, size: 65, color: Color(0xFFFF7A00)),
                  const SizedBox(height: 8),
                  const Text('Play Music',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFF7A00))),
                  const SizedBox(height: 4),
                  Text(isCreateAccount ? 'Create an Account' : 'Sign In with Email',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password (6+ characters)',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                  if (errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(errorMessage, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : handleAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: Text(isCreateAccount ? 'Create Account' : 'Sign In',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      isCreateAccount = !isCreateAccount;
                      errorMessage = '';
                    }),
                    child: Text(
                      isCreateAccount ? 'Already have an account? Sign In' : 'New here? Create an account',
                      style: const TextStyle(color: Color(0xFFFF6E6C), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class MusicPlayerApp extends StatefulWidget {
  const MusicPlayerApp({super.key});

  @override
  State<MusicPlayerApp> createState() => _MusicPlayerAppState();
}

class _MusicPlayerAppState extends State<MusicPlayerApp> {
  final AudioPlayer player = AudioPlayer();
  bool isPlaying = false;
  bool isShuffle = false;
  int currentIndex = 0;
  String selectedCategory = 'Music Library';

  // Only songs 1-2 have pictures; extra songs automatically show the orange music icon!
  final List<Map<String, String>> songs = [
    {
      'title': 'Shri Durga Mahatmyam (Devi Mahatmyam)',
      'artist': 'Traditional Sanskrit Recitation',
      'genre': 'Navratri & Devotional Prayer',
      'file': 'devi_mahatmyam.mp3',
      'image': 'assets/durga_maa.jpg',
      'source': 'asset',
    },
    {
      'title': 'Traditional Indian Folk & Bhajan',
      'artist': 'Indian Devotional Ensemble',
      'genre': 'Folk & Devotional',
      'file': 'folk_song.mp3',
      'image': 'assets/folk_devotional.jpg',
      'source': 'asset',
    },
    {
      'title': 'Devotional Folk Track 3',
      'artist': 'Traditional Folk Ensemble',
      'genre': 'Folk & Devotional',
      'file': 'folk_song_2.mp3',
      'source': 'asset',
    },
  ];

  @override
  void initState() {
    super.initState();
    player.onPlayerComplete.listen((event) => nextSong());
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> importSongsFromStorage() async {
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      status = await Permission.audio.request();
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (var picked in result.files) {
            if (picked.path != null) {
              songs.add({
                'title': picked.name.replaceAll('.mp3', ''),
                'artist': 'Device Storage',
                'genre': 'Local Audio',
                'file': picked.path!,
                'source': 'device',
              });
            }
          }
          selectedCategory = 'Device Storage';
          currentIndex = songs.length - 1;
        });
        await playCurrentSong();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage picker note: $e')),
        );
      }
    }
  }

  Future<void> playCurrentSong() async {
    final current = songs[currentIndex];
    try {
      await player.stop();
      if (current['source'] == 'device') {
        await player.play(DeviceFileSource(current['file']!));
      } else {
        await player.play(AssetSource(current['file']!));
      }
      setState(() => isPlaying = true);
    } catch (e) {
      setState(() => isPlaying = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play ${current['title']}')),
        );
      }
    }
  }

  Future<void> toggleMusic() async {
    if (isPlaying) {
      await player.pause();
      setState(() => isPlaying = false);
    } else {
      await playCurrentSong();
    }
  }

  Future<void> nextSong() async {
    setState(() {
      if (isShuffle && songs.length > 1) {
        int nextIdx = currentIndex;
        while (nextIdx == currentIndex) {
          nextIdx = Random().nextInt(songs.length);
        }
        currentIndex = nextIdx;
      } else {
        currentIndex = (currentIndex + 1) % songs.length;
      }
    });
    await playCurrentSong();
  }

  Future<void> previousSong() async {
    setState(() => currentIndex = (currentIndex - 1 + songs.length) % songs.length);
    await playCurrentSong();
  }
  @override
  Widget build(BuildContext context) {
    final currentSong = songs[currentIndex];
    final hasImage = currentSong['image'] != null && currentSong['image']!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF5E62), Color(0xFFFF8008), Color(0xFFFFC837)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.music_note_rounded, size: 46, color: Colors.white),
                  SizedBox(height: 10),
                  Text('Play Music',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Your Music Library',
                      style: TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.library_music_rounded, color: Color(0xFFFF7A00)),
              title: const Text('Music Library', style: TextStyle(fontWeight: FontWeight.bold)),
              selected: selectedCategory == 'Music Library',
              onTap: () {
                setState(() => selectedCategory = 'Music Library');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.self_improvement_rounded, color: Color(0xFFFF5E62)),
              title: const Text('Devotional & Festivals'),
              selected: selectedCategory == 'Devotional & Festivals',
              onTap: () {
                setState(() => selectedCategory = 'Devotional & Festivals');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded, color: Color(0xFFFFB800)),
              title: const Text('Device Storage (Find Songs)'),
              subtitle: const Text('Scan phone/tablet for MP3s'),
              onTap: () {
                Navigator.pop(context);
                importSongsFromStorage();
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.black54),
              title: const Text('Sign Out'),
              onTap: () async {
                await player.stop();
                await FirebaseAuth.instance.signOut();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      body: EpoxyBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu_rounded, size: 30, color: Color(0xFF2D2D2D)),
                            tooltip: 'Open Menu',
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(selectedCategory,
                            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.folder_open_rounded, color: Color(0xFFFF7A00)),
                          tooltip: 'Load songs from storage',
                          onPressed: importSongsFromStorage,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      children: [
                        if (hasImage)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              currentSong['image']!,
                              width: 125,
                              height: 125,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 105,
                            height: 105,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7A00).withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.music_note_rounded,
                                size: 52, color: Color(0xFFFF7A00)),
                          ),
                        const SizedBox(height: 12),
                        Text(currentSong['title']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${currentSong['artist']} • ${currentSong['genre']}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: Colors.black54)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                                onPressed: previousSong,
                                iconSize: 38,
                                icon: const Icon(Icons.skip_previous_rounded)),
                            const SizedBox(width: 14),
                            ElevatedButton(
                              onPressed: toggleMusic,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF7A00),
                                foregroundColor: Colors.white,
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(18),
                              ),
                              child: Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  size: 36),
                            ),
                            const SizedBox(width: 14),
                            IconButton(
                                onPressed: nextSong,
                                iconSize: 38,
                                icon: const Icon(Icons.skip_next_rounded)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () {
                            setState(() => isShuffle = !isShuffle);
                            if (isShuffle) nextSong();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF5E62), Color(0xFFFF8008), Color(0xFFFFC837)],
                              ),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shuffle_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  isShuffle ? 'SHUFFLE ON' : 'SHUFFLE ALL',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        final isSelected = index == currentIndex;
                        final songHasImg = song['image'] != null && song['image']!.isNotEmpty;

                        return Card(
                          color: isSelected
                              ? const Color(0xFFFF7A00).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.85),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: songHasImg
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.asset(
                                      song['image']!,
                                      width: 45,
                                      height: 45,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : CircleAvatar(
                                    backgroundColor:
                                        const Color(0xFFFF7A00).withValues(alpha: 0.14),
                                    child: Icon(
                                      isSelected && isPlaying
                                          ? Icons.equalizer_rounded
                                          : Icons.music_note_rounded,
                                      color: const Color(0xFFFF7A00),
                                    ),
                                  ),
                            title: Text(song['title']!,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${song['artist']} • ${song['genre']}'),
                            onTap: () async {
                              setState(() => currentIndex = index);
                              await playCurrentSong();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class EpoxyBackground extends StatelessWidget {
  final Widget child;
  const EpoxyBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: Colors.white),
        Positioned.fill(
          child: CustomPaint(
            painter: EpoxySpillPainter(),
          ),
        ),
        child,
      ],
    );
  }
}

class EpoxySpillPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final topPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF5E62), Color(0xFFFF8008)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.45));

    final topPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.85, 0)
      ..cubicTo(
        size.width * 0.75, size.height * 0.16,
        size.width * 0.42, size.height * 0.10,
        size.width * 0.30, size.height * 0.24,
      )
      ..cubicTo(
        size.width * 0.18, size.height * 0.36,
        size.width * 0.08, size.height * 0.28,
        0, size.height * 0.38,
      )
      ..close();

    canvas.drawPath(topPath, topPaint);

    final topGoldRibbon = Paint()
      ..color = const Color(0xFFFFB800).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final ribbonPath = Path()
      ..moveTo(0, size.height * 0.40)
      ..cubicTo(
        size.width * 0.10, size.height * 0.30,
        size.width * 0.20, size.height * 0.38,
        size.width * 0.32, size.height * 0.26,
      )
      ..cubicTo(
        size.width * 0.44, size.height * 0.12,
        size.width * 0.77, size.height * 0.18,
        size.width * 0.88, 0,
      );

    canvas.drawPath(ribbonPath, topGoldRibbon);

    final bottomPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF8008), Color(0xFFFFC837)],
      ).createShader(Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45));

    final bottomPath = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(size.width * 0.12, size.height)
      ..cubicTo(
        size.width * 0.25, size.height * 0.84,
        size.width * 0.55, size.height * 0.90,
        size.width * 0.70, size.height * 0.76,
      )
      ..cubicTo(
        size.width * 0.82, size.height * 0.64,
        size.width * 0.92, size.height * 0.70,
        size.width, size.height * 0.60,
      )
      ..close();

    canvas.drawPath(bottomPath, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
