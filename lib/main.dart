class MusicPlayerApp extends StatefulWidget {
  const MusicPlayerApp({super.key});

  @override
  State<MusicPlayerApp> createState() => _MusicPlayerAppState();
}

class _MusicPlayerAppState extends State<MusicPlayerApp> {
  final AudioPlayer player = AudioPlayer();
  bool isPlaying = false;
  int currentIndex = 0;

  // Put your unzipped .mp3 files into your assets/ folder and list them here!
  final List<Map<String, String>> songs = [
    {
      'title': 'Track 1',
      'artist': 'Artist Name',
      'genre': 'Bollywood / Indian',
      'file': 'song1.mp3'
    },
    {
      'title': 'Track 2',
      'artist': 'Artist Name',
      'genre': 'Hollywood / Cinematic',
      'file': 'song2.mp3'
    },
    {
      'title': 'Track 3',
      'artist': 'Artist Name',
      'genre': 'British / UK Beat',
      'file': 'song3.mp3'
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

  Future<void> playCurrentSong() async {
    try {
      await player.stop();
      await player.play(AssetSource(songs[currentIndex]['file']!));
      setState(() => isPlaying = true);
    } catch (e) {
      setState(() => isPlaying = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Upload ${songs[currentIndex]['file']} to your assets folder first!')),
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
    setState(() => currentIndex = (currentIndex + 1) % songs.length);
    await playCurrentSong();
  }

  Future<void> previousSong() async {
    setState(
        () => currentIndex = (currentIndex - 1 + songs.length) % songs.length);
    await playCurrentSong();
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = songs[currentIndex];
    return Scaffold(
      backgroundColor: Colors.white,
      body: EpoxyBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Play Music',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.logout),
                          onPressed: () async {
                            await player.stop();
                            await FirebaseAuth.instance.signOut();
                          },
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.music_note_rounded,
                            size: 55, color: Color(0xFFFF7A00)),
                        const SizedBox(height: 12),
                        Text(currentSong['title']!,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        Text(
                            '${currentSong['artist']} • ${currentSong['genre']}',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black54)),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                                onPressed: previousSong,
                                iconSize: 38,
                                icon: const Icon(Icons.skip_previous_rounded)),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: toggleMusic,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF7A00),
                                foregroundColor: Colors.white,
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(18),
                              ),
                              child: Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 36),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                                onPressed: nextSong,
                                iconSize: 38,
                                icon: const Icon(Icons.skip_next_rounded)),
                          ],
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
                        return Card(
                          color: isSelected
                              ? const Color(0xFFFF7A00).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.85),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: Icon(
                              isSelected && isPlaying
                                  ? Icons.equalizer_rounded
                                  : Icons.music_note_rounded,
                              color: const Color(0xFFFF7A00),
                            ),
                            title: Text(song['title']!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle:
                                Text('${song['artist']} • ${song['genre']}'),
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
