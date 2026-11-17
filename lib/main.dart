import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

late PlayMusicAudioHandler audioHandler;

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

  audioHandler = await AudioService.init(
    builder: () => PlayMusicAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.frizzymagma.play_music.channel.audio',
      androidNotificationChannelName: 'Play Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
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
class PlayMusicAudioHandler extends BaseAudioHandler {
  final AudioPlayer player = AudioPlayer();
  bool isShuffle = false;
  int currentIndex = 0;

  final List<Map<String, String>> builtInSongs = [
    {
      'title': 'Shri Durga Mahatmyam (Devi Mahatmyam)',
      'artist': 'Traditional Sanskrit Recitation',
      'genre': 'Navratri & Devotional Prayer',
      'file': 'devi_mahatmyam.mp3',
      'image': 'assets/diya.jpg',
      'source': 'asset',
    },
    {
      'title': 'Bharat Mata Namo Daya (Swatantra Janani)',
      'artist': 'Traditional Indian Vocal',
      'genre': 'Patriotic & Devotional Hymn',
      'file': 'folk_1.mp3',
      'image': 'assets/folk_devotional.jpg',
      'source': 'asset',
    },
    {
      'title': 'Soye Hue Hain Chand Aur Taare',
      'artist': 'Traditional Indian Folk',
      'genre': 'Classic Indian Folk',
      'file': 'folk_2.mp3',
      'source': 'asset',
    },
  ];

  List<Map<String, String>> songs = [];
  List<String> hiddenPaths = [];
  VoidCallback? onStateChanged;

  PlayMusicAudioHandler() {
    songs = List.from(builtInSongs);
    player.onPlayerComplete.listen((_) => skipToNext());
  }

  Future<void> loadAndScanStorageSongs() async {
    final prefs = await SharedPreferences.getInstance();
    hiddenPaths = prefs.getStringList('hidden_local_songs') ?? [];

    final savedJson = prefs.getStringList('saved_local_songs') ?? [];
    final loadedLocal = savedJson
        .map((item) => Map<String, String>.from(jsonDecode(item)))
        .where((s) => File(s['file']!).existsSync() && !hiddenPaths.contains(s['file']))
        .toList();

    songs = [...builtInSongs, ...loadedLocal];
    onStateChanged?.call();

    await Permission.notification.request();
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      status = await Permission.audio.request();
    }

    if (status.isGranted && Platform.isAndroid) {
      final foldersToScan = [
        Directory('/storage/emulated/0/Music'),
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Audio'),
        Directory('/storage/emulated/0/Recordings'),
      ];

      bool foundNew = false;
      for (final dir in foldersToScan) {
        if (await dir.exists()) {
          try {
            await for (final entity in dir.list(recursive: true, followLinks: false)) {
              if (entity is File) {
                final lower = entity.path.toLowerCase();
                if (lower.endsWith('.mp3') ||
                    lower.endsWith('.m4a') ||
                    lower.endsWith('.wav') ||
                    lower.endsWith('.ogg')) {
                  final alreadyInList = songs.any((s) => s['file'] == entity.path);
                  final isHidden = hiddenPaths.contains(entity.path);
                  if (!alreadyInList && !isHidden) {
                    final rawName = entity.uri.pathSegments.last;
                    final cleanName = rawName.replaceAll(
                        RegExp(r'\.(mp3|m4a|wav|ogg)$', caseSensitive: false), '');
                    songs.add({
                      'title': cleanName,
                      'artist': 'Device Storage',
                      'genre': 'Saved Local Audio',
                      'file': entity.path,
                      'source': 'device',
                    });
                    foundNew = true;
                  }
                }
              }
            }
          } catch (_) {}
        }
      }

      if (foundNew) {
        await saveLocalSongs();
        onStateChanged?.call();
      }
    }
  }
  Future<void> saveLocalSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final localOnly = songs.where((s) => s['source'] == 'device').toList();
    final encoded = localOnly.map((s) => jsonEncode(s)).toList();
    await prefs.setStringList('saved_local_songs', encoded);
    await prefs.setStringList('hidden_local_songs', hiddenPaths);
  }

  Future<void> removeLocalSong(String filePath) async {
    final removedIdx = songs.indexWhere((s) => s['file'] == filePath);
    if (removedIdx == -1) return;

    if (!hiddenPaths.contains(filePath)) {
      hiddenPaths.add(filePath);
    }

    if (currentIndex == removedIdx) {
      await pause();
      currentIndex = 0;
    } else if (currentIndex > removedIdx) {
      currentIndex--;
    }

    songs.removeAt(removedIdx);
    await saveLocalSongs();
    onStateChanged?.call();
  }

  void _updateSystemMediaNotification(bool playing) {
    final current = songs[currentIndex];
    mediaItem.add(MediaItem(
      id: current['file']!,
      album: current['genre'] ?? 'Play Music',
      title: current['title']!,
      artist: current['artist'] ?? 'Play Music',
    ));

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const,
      processingState: AudioProcessingState.ready,
      playing: playing,
    ));
  }

  Future<void> playIndex(int index) async {
    currentIndex = index;
    await play();
  }

  @override
  Future<void> play() async {
    final current = songs[currentIndex];
    try {
      await player.stop();
      if (current['source'] == 'device') {
        await player.play(DeviceFileSource(current['file']!));
      } else {
        await player.play(AssetSource(current['file']!));
      }
      _updateSystemMediaNotification(true);
      onStateChanged?.call();
    } catch (_) {
      _updateSystemMediaNotification(false);
      onStateChanged?.call();
    }
  }

  @override
  Future<void> pause() async {
    await player.pause();
    _updateSystemMediaNotification(false);
    onStateChanged?.call();
  }

  @override
  Future<void> skipToNext() async {
    if (isShuffle && songs.length > 1) {
      int nextIdx = currentIndex;
      while (nextIdx == currentIndex) {
        nextIdx = Random().nextInt(songs.length);
      }
      currentIndex = nextIdx;
    } else {
      currentIndex = (currentIndex + 1) % songs.length;
    }
    await play();
  }

  @override
  Future<void> skipToPrevious() async {
    currentIndex = (currentIndex - 1 + songs.length) % songs.length;
    await play();
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
  String selectedCategory = 'Music Library';

  @override
  void initState() {
    super.initState();
    audioHandler.onStateChanged = () {
      if (mounted) setState(() {});
    };
    audioHandler.loadAndScanStorageSongs();
  }

  Future<void> findSongsInStorageManually() async {
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      status = await Permission.audio.request();
    }

    try {
      final files = await FilePicker.pickFiles(type: FileType.audio);
      if (files.isNotEmpty) {
        for (var picked in files) {
          if (picked.path != null) {
            audioHandler.hiddenPaths.remove(picked.path);
            final alreadyAdded = audioHandler.songs.any((s) => s['file'] == picked.path);
            if (!alreadyAdded) {
              audioHandler.songs.add({
                'title': picked.name.replaceAll(RegExp(r'\.(mp3|m4a|wav|ogg)$', caseSensitive: false), ''),
                'artist': 'Device Storage',
                'genre': 'Saved Local Audio',
                'file': picked.path!,
                'source': 'device',
              });
            }
          }
        }
        await audioHandler.saveLocalSongs();
        setState(() => selectedCategory = 'Saved Local Songs');
        await audioHandler.playIndex(audioHandler.songs.length - 1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage picker note: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSongs = audioHandler.songs;
    final displayedSongs = selectedCategory == 'Saved Local Songs'
        ? allSongs.where((s) => s['source'] == 'device').toList()
        : allSongs;
    final currentSong = allSongs[audioHandler.currentIndex];
    final isPlaying = audioHandler.playbackState.value.playing;
    final hasImage = currentSong['image'] != null && currentSong['image']!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 22),
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
                  Icon(Icons.music_note_rounded, size: 42, color: Colors.white),
                  SizedBox(height: 8),
                  Text('Play Music',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Saved Playlists & Library',
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
              leading: const Icon(Icons.playlist_add_check_rounded, color: Color(0xFFFF5E62)),
              title: const Text('Saved Local Songs', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Your saved phone/tablet songs'),
              selected: selectedCategory == 'Saved Local Songs',
              onTap: () {
                setState(() => selectedCategory = 'Saved Local Songs');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.search_rounded, color: Color(0xFFFFB800)),
              title: const Text('Find Songs In Storage', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Browse folders if a song is missing'),
              onTap: () {
                Navigator.pop(context);
                findSongsInStorageManually();
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.black54),
              title: const Text('Sign Out'),
              onTap: () async {
                await audioHandler.pause();
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu_rounded, size: 28, color: Color(0xFF2D2D2D)),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(selectedCategory,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Color(0xFFFF7A00)),
                          tooltip: 'Rescan storage for songs',
                          onPressed: () => audioHandler.loadAndScanStorageSongs(),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            if (hasImage)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.asset(
                                  currentSong['image']!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _defaultArtBox(),
                                ),
                              )
                            else
                              _defaultArtBox(),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentSong['title']!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${currentSong['artist']} • ${currentSong['genre']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              onPressed: () => audioHandler.skipToPrevious(),
                              iconSize: 28,
                              icon: const Icon(Icons.skip_previous_rounded),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  isPlaying ? audioHandler.pause() : audioHandler.play(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF7A00),
                                foregroundColor: Colors.white,
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(12),
                              ),
                              child: Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  size: 26),
                            ),
                            IconButton(
                              onPressed: () => audioHandler.skipToNext(),
                              iconSize: 28,
                              icon: const Icon(Icons.skip_next_rounded),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() => audioHandler.isShuffle = !audioHandler.isShuffle);
                                if (audioHandler.isShuffle) audioHandler.skipToNext();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: audioHandler.isShuffle
                                        ? [const Color(0xFFFF5E62), const Color(0xFFFF8008), const Color(0xFFFFC837)]
                                        : [Colors.grey.shade400, Colors.grey.shade500],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.shuffle_rounded, color: Colors.white, size: 17),
                                    const SizedBox(width: 4),
                                    Text(
                                      audioHandler.isShuffle ? 'ON' : 'SHUFFLE',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: displayedSongs.isEmpty
                        ? const Center(
                            child: Text('No saved local songs found yet.\nOpen the menu -> Find Songs In Storage!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: displayedSongs.length,
                            itemBuilder: (context, index) {
                              final song = displayedSongs[index];
                              final realIndex = allSongs.indexOf(song);
                              final isSelected = realIndex == audioHandler.currentIndex;
                              final songHasImg =
                                  song['image'] != null && song['image']!.isNotEmpty;

                              return Card(
                                color: isSelected
                                    ? const Color(0xFFFF7A00).withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.85),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                child: ListTile(
                                  dense: true,
                                  leading: songHasImg
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.asset(
                                            song['image']!,
                                            width: 42,
                                            height: 42,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.music_note_rounded,
                                                    color: Color(0xFFFF7A00)),
                                          ),
                                        )
                                      : CircleAvatar(
                                          radius: 20,
                                          backgroundColor:
                                              const Color(0xFFFF7A00).withValues(alpha: 0.14),
                                          child: Icon(
                                            isSelected && isPlaying
                                                ? Icons.equalizer_rounded
                                                : Icons.music_note_rounded,
                                            color: const Color(0xFFFF7A00),
                                            size: 20,
                                          ),
                                        ),
                                  title: Text(song['title']!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${song['artist']} • ${song['genre']}'),
                                  trailing: song['source'] == 'device'
                                      ? PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert_rounded,
                                              color: Colors.black54),
                                          onSelected: (value) async {
                                            if (value == 'remove') {
                                              await audioHandler.removeLocalSong(song['file']!);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'remove',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline_rounded,
                                                      color: Colors.red, size: 20),
                                                  SizedBox(width: 8),
                                                  Text('Remove from library',
                                                      style: TextStyle(color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      : null,
                                  onTap: () => audioHandler.playIndex(realIndex),
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

  Widget _defaultArtBox() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFFF7A00).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.music_note_rounded, size: 32, color: Color(0xFFFF7A00)),
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
