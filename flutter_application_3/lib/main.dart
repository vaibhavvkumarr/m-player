import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'music.player.channel',
    androidNotificationChannelName: 'Music Playback',
    androidNotificationOngoing: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SongListPage(),
    );
  }
}

// ---------------- SONG LIST ----------------
class SongListPage extends StatelessWidget {
  const SongListPage({super.key});

  static final songs = [
    {
      'title': 'Activate Chakras',
      'artist': 'Mr Informative',
      'url': 'https://yourdomain.com/audio/music-1.mp3?token=SECURE',
      'cover': 'assets/images/music-1.jpg',
    },
    {
      'title': 'Astral Travel',
      'artist': 'Mr Informative',
      'url': 'https://yourdomain.com/audio/music-2.mp3?token=SECURE',
      'cover': 'assets/images/music-2.jpg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Binaural Beats')),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (_, index) {
          final song = songs[index];
          return ListTile(
            leading: Image.asset(song['cover']!, width: 50),
            title: Text(song['title']!),
            subtitle: Text(song['artist']!),
            trailing: const Icon(Icons.download),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlayerPage(
                    songs: songs,
                    index: index,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------- PLAYER ----------------
class PlayerPage extends StatefulWidget {
  final List<Map<String, String>> songs;
  final int index;

  const PlayerPage({super.key, required this.songs, required this.index});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final AudioPlayer _player = AudioPlayer();
  double progress = 0;
  late int index;

  @override
  void initState() {
    super.initState();
    index = widget.index;
    _restoreLastState();
  }

  Future<void> _restoreLastState() async {
    final prefs = await SharedPreferences.getInstance();
    index = prefs.getInt('lastIndex') ?? index;
    final position = prefs.getInt('lastPosition') ?? 0;
    await _loadSong();
    _player.seek(Duration(seconds: position));
  }

  Future<File> _downloadAudio(String url, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');

    if (!file.existsSync()) {
      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();
      final contentLength = response.contentLength ?? 1;

      List<int> bytes = [];
      int received = 0;

      response.stream.listen((chunk) {
        bytes.addAll(chunk);
        received += chunk.length;
        setState(() => progress = received / contentLength);
      });

      await response.stream.drain();
      await file.writeAsBytes(bytes);
    }

    return file;
  }

  Future<void> _loadSong() async {
    final song = widget.songs[index];
    final file = await _downloadAudio(song['url']!, 'song_$index.mp3');

    await _player.setAudioSource(
      AudioSource.file(
        file.path,
        tag: MediaItem(
          id: '$index',
          title: song['title']!,
          artist: song['artist']!,
        ),
      ),
    );

    _player.play();

    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('lastIndex', index);

    _player.positionStream.listen((pos) {
      prefs.setInt('lastPosition', pos.inSeconds);
    });
  }

  void _next() {
    if (index < widget.songs.length - 1) {
      index++;
      progress = 0;
      _loadSong();
    }
  }

  void _prev() {
    if (index > 0) {
      index--;
      progress = 0;
      _loadSong();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.songs[index];

    return Scaffold(
      appBar: AppBar(title: Text(song['title']!)),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(song['cover']!, height: 250),
          const SizedBox(height: 20),
          Text(song['title']!, style: const TextStyle(fontSize: 22)),
          Text(song['artist']!, style: const TextStyle(color: Colors.grey)),

          if (progress > 0 && progress < 1)
            Padding(
              padding: const EdgeInsets.all(12),
              child: LinearProgressIndicator(value: progress),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.skip_previous), onPressed: _prev),
              IconButton(
                icon: Icon(
                    _player.playing ? Icons.pause : Icons.play_arrow, size: 36),
                onPressed: () =>
                    _player.playing ? _player.pause() : _player.play(),
              ),
              IconButton(icon: const Icon(Icons.skip_next), onPressed: _next),
            ],
          ),
        ],
      ),
    );
  }
}
