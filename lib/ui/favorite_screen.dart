import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:refreezer/fonts/deezer_icons.dart';
import 'package:refreezer/main.dart';
import 'package:refreezer/ui/cached_image.dart';
import 'package:refreezer/ui/details_screens.dart';
import 'package:refreezer/ui/error.dart';
import 'package:refreezer/ui/library.dart';
import 'package:refreezer/ui/menu.dart';

import '../api/cache.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import '../api/download.dart';
import '../service/audio_service.dart';
import '../settings.dart';
import '../translations.i18n.dart';
import '../ui/elements.dart';

class FavoriteAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FavoriteAppBar({super.key});

  @override
  Size get preferredSize => AppBar().preferredSize;

  @override
  Widget build(BuildContext context) {
    return FreezerAppBar(
      'Favorites'.i18n,
      actions: <Widget>[
        Container(
          margin: EdgeInsets.only(right: 24),
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            border: Border.all(color: Colors.transparent),
            borderRadius: BorderRadius.circular(100),
          ),
          child: IconButton(
            icon: Icon(
              DeezerIcons.shuffle,
              color: Colors.white,
              semanticLabel: 'Shuffle'.i18n,
              size: 20.0,
            ),
            onPressed: () async {
              List<Track> tracks = await deezerAPI.libraryShuffle();
              GetIt.I<AudioPlayerHandler>().playFromTrackList(
                  tracks,
                  tracks[0].id!,
                  QueueSource(
                      id: 'libraryshuffle',
                      source: 'libraryshuffle',
                      text: 'Library shuffle'.i18n));
            },
          ),
        ),
      ],
    );
  }
}

class FavoriteScreen extends StatelessWidget {
  const FavoriteScreen({super.key});

  Playlist get favoritesPlaylist => Playlist(
      id: deezerAPI.favoritesPlaylistId,
      title: 'Favorites'.i18n,
      user: User(name: deezerAPI.userName),
      image: ImageDetails(thumbUrl: 'assets/favorites_thumb.jpg'),
      tracks: [],
      trackCount: 1,
      duration: const Duration(seconds: 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FavoriteAppBar(),
      body: ListView(padding: EdgeInsets.only(top: 12.0), children: <Widget>[
        Container(height: 24.0),
        FavoriteTracks(),
        Container(height: 24.0),
        FavoritePlaylists(),
        FreezerDivider(),
        ListTile(
            title: Text('Albums'.i18n),
            leading:
                const LeadingIcon(DeezerIcons.album, color: Color(0xff4b2e7e)),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const LibraryAlbums()));
            },
            trailing: Icon(
              Icons.chevron_right,
              color: Colors.white,
            )),
        FreezerDivider(),
        ListTile(
            title: Text('Artists'.i18n),
            leading: const LeadingIcon(Icons.recent_actors,
                color: Color(0xff384697)),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const LibraryArtists()));
            },
            trailing: Icon(
              Icons.chevron_right,
              color: Colors.white,
            )),
        FreezerDivider(),
        FutureBuilder(
            future: downloadManager.getStats(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const ErrorScreen();
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[CircularProgressIndicator()],
                  ),
                );
              }
              List<String> data = snapshot.data!;
              return ListTile(
                title: Text('Downloaded tracks'.i18n),
                leading: const LeadingIcon(DeezerIcons.download_fill,
                    color: Color(0xffbe3266)),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const LibraryTracks()));
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(data[0],
                        style: TextStyle(color: Settings.secondaryText)),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                    )
                  ],
                ),
              );
            }),
        Padding(
            padding: EdgeInsets.only(
                bottom: GetIt.I<AudioPlayerHandler>().mediaItem.value != null
                    ? 80
                    : 0)),
      ]),
    );
  }
}

class FavoriteTracks extends StatefulWidget {
  const FavoriteTracks({super.key});

  @override
  _FavoriteTracksState createState() => _FavoriteTracksState();
}

class _FavoriteTracksState extends State<FavoriteTracks> {
  bool _loading = false;
  Playlist? favoritePlaylist;
  List<Track> tracks = [];
  List<Track> allTracks = [];
  List<Track> randomTracks = [];
  int? trackCount;

  //Get 3 random favorite titles
  void selectRandom3(List<Track> trackList) {
    List<Track> tcopy = [];
    for (int i = 0; i < min(trackList.length, 3); i++) {
      int track = Random().nextInt(trackList.length);
      if (tcopy.contains(trackList[track])) {
        i--;
      } else {
        tcopy.add(trackList[track]);
      }
    }

    setState(() {
      randomTracks = List.from(tcopy);
      _loading = false;
    });
  }

  //Load all tracks
  Future _load() async {
    if (mounted) setState(() => _loading = true);

    //Already loaded
    if (trackCount != null && (tracks.length >= (trackCount ?? 0))) {
      //Update favorite tracks cache when fully loaded
      if (cache.libraryTracks?.length != trackCount) {
        if (mounted) {
          setState(() {
            cache.libraryTracks = tracks.map((t) => t.id!).toList();
          });
          await cache.save();
        }
      }
      selectRandom3(tracks);
      return;
    }

    //if favorite Playlist is offline
    Playlist? p = await downloadManager
        .getOfflinePlaylist(deezerAPI.favoritesPlaylistId ?? '');
    if (mounted) {
      setState(() {
        tracks = p?.tracks ?? [];
        trackCount = p?.tracks!.length;
        favoritePlaylist = p;
        selectRandom3(tracks);
      });
    }

    List<ConnectivityResult> connectivity =
        await Connectivity().checkConnectivity();
    if (connectivity.isNotEmpty &&
        !connectivity.contains(ConnectivityResult.none)) {
      //Load tracks as a playlist
      Playlist? favPlaylist;
      try {
        favPlaylist =
            await deezerAPI.playlist(deezerAPI.favoritesPlaylistId ?? '');
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
      //Error loading
      if (favPlaylist == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      //Update
      if (mounted) {
        setState(() {
          trackCount = favPlaylist!.trackCount;
          if (tracks.isEmpty) tracks = favPlaylist.tracks!;
          _makeFavorite();
          favoritePlaylist = favPlaylist;
        });
        selectRandom3(tracks);
        return;
      }
    } else {
      if (randomTracks.isEmpty) {
        List<Track> tracks = await downloadManager.allOfflineTracks();
        if (mounted) {
          setState(() {
            allTracks = tracks;
            trackCount = tracks.length;
            favoritePlaylist = Playlist(
              id: null,
              title: 'Offline Tracks',
              tracks: tracks,
              trackCount: tracks.length,
            );
            selectRandom3(allTracks);
          });
        }
      }
    }
  }

  void _makeFavorite() {
    for (int i = 0; i < tracks.length; i++) {
      tracks[i].favorite = true;
    }
  }

  @override
  void initState() {
    _load();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Column(children: [
        SizedBox(
          height: 200,
          child: ListTile(
            leading: Icon(
              DeezerIcons.heart_fill,
              color: Theme.of(context).primaryColor,
            ),
            title: Text(
              'Favorite tracks'.i18n,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            trailing: Transform.scale(
                scale: 0.5, // Adjust the scale to 75% of the original size
                child: CircularProgressIndicator(
                  color: Theme.of(context).primaryColor,
                )),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => PlaylistDetails(favoritePlaylist!))),
          ),
        ),
      ]);
    } else {
      return SizedBox(
        height: 200,
        child: Column(
          children: [
            SizedBox(
              height: 46,
              child: ListTile(
                leading: Icon(
                  DeezerIcons.heart_fill,
                  color: Theme.of(context).primaryColor,
                ),
                title: Text(
                  'Favorite tracks'.i18n,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text((trackCount ?? 0).toString(),
                        style: TextStyle(color: Settings.secondaryText)),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                    )
                  ],
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => PlaylistDetails(favoritePlaylist!))),
              ),
            ),
            if (randomTracks.isNotEmpty)
              SizedBox(
                height: 48.0,
                child: ListTile(
                  leading: CachedImage(
                    url: randomTracks[0].albumArt?.full ?? '',
                    height: 40,
                    width: 40,
                  ),
                  title: Text(randomTracks[0].title ?? '',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(randomTracks[0].artistString ?? '',
                      style: TextStyle(
                          color: Settings.secondaryText, fontSize: 12)),
                  trailing: PlayerMenuButton(randomTracks[0]),
                  onTap: () {
                    GetIt.I<AudioPlayerHandler>().playFromTrackList(
                        tracks,
                        randomTracks[0].id ?? '',
                        QueueSource(
                            id: deezerAPI.favoritesPlaylistId,
                            text: 'Favorites'.i18n,
                            source: 'playlist'));
                  },
                  onLongPress: () {
                    MenuSheet m = MenuSheet();
                    m.defaultTrackMenu(randomTracks[0], context: context);
                  },
                ),
              ),
            if (randomTracks.length > 1)
              SizedBox(
                height: 44,
                child: ListTile(
                  leading: CachedImage(
                    url: randomTracks[1].albumArt?.full ?? '',
                    height: 40,
                    width: 40,
                  ),
                  title: Text(randomTracks[1].title ?? '',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(randomTracks[1].artistString ?? '',
                      style: TextStyle(
                          color: Settings.secondaryText, fontSize: 12)),
                  trailing: PlayerMenuButton(randomTracks[1]),
                  onTap: () {
                    GetIt.I<AudioPlayerHandler>().playFromTrackList(
                        tracks,
                        randomTracks[1].id ?? '',
                        QueueSource(
                            id: deezerAPI.favoritesPlaylistId,
                            text: 'Favorites'.i18n,
                            source: 'playlist'));
                  },
                  onLongPress: () {
                    MenuSheet m = MenuSheet();
                    m.defaultTrackMenu(randomTracks[1], context: context);
                  },
                ),
              ),
            if (randomTracks.length > 2)
              SizedBox(
                height: 44,
                child: ListTile(
                  leading: CachedImage(
                    url: randomTracks[2].albumArt?.full ?? '',
                    height: 40,
                    width: 40,
                  ),
                  title: Text(randomTracks[2].title ?? '',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(randomTracks[2].artistString ?? '',
                      style: TextStyle(
                          color: Settings.secondaryText, fontSize: 12)),
                  trailing: PlayerMenuButton(randomTracks[2]),
                  onTap: () {
                    GetIt.I<AudioPlayerHandler>().playFromTrackList(
                        tracks,
                        randomTracks[2].id ?? '',
                        QueueSource(
                            id: deezerAPI.favoritesPlaylistId,
                            text: 'Favorites'.i18n,
                            source: 'playlist'));
                  },
                  onLongPress: () {
                    MenuSheet m = MenuSheet();
                    m.defaultTrackMenu(randomTracks[2], context: context);
                  },
                ),
              ),
          ],
        ),
      );
    }
  }
}

class FavoritePlaylists extends StatefulWidget {
  const FavoritePlaylists({super.key});

  @override
  _FavoritePlaylistsState createState() => _FavoritePlaylistsState();
}

class _FavoritePlaylistsState extends State<FavoritePlaylists> {
  List<Playlist>? _playlists;
  bool _loading = false;

  Future _load() async {
    setState(() => _loading = true);

    //load offline playlists
    List<Playlist> playlists = await downloadManager.getOfflinePlaylists();
    if (mounted) {
      setState(() {
        _playlists = playlists;
        _loading = false;
      });
    }

    //update if online
    List<ConnectivityResult> connectivity =
        await Connectivity().checkConnectivity();
    if (connectivity.isNotEmpty &&
        !connectivity.contains(ConnectivityResult.none)) {
      try {
        List<Playlist> playlists = await deezerAPI.getPlaylists();
        if (mounted) setState(() => _playlists = playlists);
      } catch (e) {
        Logger.root.severe('Error loading playlists: $e');
      }
    }
    _loading = false;
  }

  @override
  void initState() {
    _load();
    super.initState();
  }

  Playlist get favoritesPlaylist => Playlist(
      id: deezerAPI.favoritesPlaylistId,
      title: 'Favorites'.i18n,
      user: User(name: deezerAPI.userName),
      image: ImageDetails(thumbUrl: 'assets/favorites_thumb.jpg'),
      tracks: [],
      trackCount: 1,
      duration: const Duration(seconds: 0));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: 300,
        child: ListTile(
          leading: Icon(
            DeezerIcons.heart_fill,
            color: Theme.of(context).primaryColor,
          ),
          title: Text(
            'Playlists'.i18n,
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          trailing: Transform.scale(
              scale: 0.5, // Adjust the scale to 75% of the original size
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              )),
          onTap: () => {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const LibraryPlaylists()))
          },
        ),
      );
    } else {
      return SizedBox(
          height: 300,
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  DeezerIcons.heart_fill,
                  color: Theme.of(context).primaryColor,
                ),
                title: Text(
                  'Playlists'.i18n,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(_playlists!.length.toString(),
                        style: TextStyle(color: Settings.secondaryText)),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                    )
                  ],
                ),
                onTap: () => {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const LibraryPlaylists()))
                },
              ),
              ListView(
                  scrollDirection: Axis.horizontal,
                  physics: ClampingScrollPhysics(),
                  shrinkWrap: true,
                  children: [
                    Container(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          PlaylistDetails(favoritesPlaylist))),
                              onLongPress: () {
                                MenuSheet m = MenuSheet();
                                m.defaultPlaylistMenu(favoritesPlaylist,
                                    context: context);
                              },
                              child: Container(
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.transparent),
                                    borderRadius: BorderRadius.circular(10)),
                                child: SizedBox(
                                  height: 180,
                                  width: 180,
                                  child: Container(
                                    color: Colors.deepOrange.shade100,
                                    child: Icon(DeezerIcons.heart_fill,
                                        color: Colors.deepOrange.shade400,
                                        size: 100.0),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4.0, vertical: 6.0),
                              child: Text('Favorite tracks'.i18n,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text(
                                  'By '.i18n + (deezerAPI.userName ?? ''),
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                      color: Settings.secondaryText,
                                      fontSize: 8)),
                            )
                          ],
                        )),
                    for (int i = 0; i < _playlists!.length; i++)
                      if (_playlists?[i] != null)
                        Container(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              PlaylistDetails(_playlists![i]))),
                                  onLongPress: () {
                                    MenuSheet m = MenuSheet();
                                    m.defaultPlaylistMenu(_playlists![i],
                                        context: context);
                                  },
                                  child: Container(
                                    clipBehavior: Clip.hardEdge,
                                    decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.transparent),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: CachedImage(
                                      url: _playlists?[i].image?.fullUrl ?? '',
                                      height: 180,
                                      width: 180,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 2.0, vertical: 6.0),
                                  child: Text(_playlists?[i].title ?? '',
                                      maxLines: 1,
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ),
                                if (_playlists?[i].user?.name != null &&
                                    _playlists?[i].user?.name != '')
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 4.0),
                                    child: Text(
                                        'By '.i18n +
                                            (_playlists?[i].user?.name ?? ''),
                                        maxLines: 1,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                            color: Settings.secondaryText,
                                            fontSize: 8)),
                                  ),
                                if (_playlists?[i].user?.name == null ||
                                    _playlists?[i].user?.name == '')
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 4.0),
                                    child: Text(
                                        'By '.i18n + (deezerAPI.userName ?? ''),
                                        maxLines: 1,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                            color: Settings.secondaryText,
                                            fontSize: 8)),
                                  )
                              ],
                            ))
                  ])
            ],
          ));
    }
  }
}

class PlayerMenuButton extends StatelessWidget {
  final Track track;
  const PlayerMenuButton(this.track, {super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        DeezerIcons.more_vert,
        color: Colors.white,
        semanticLabel: 'Options'.i18n,
      ),
      onPressed: () {
        MenuSheet m = MenuSheet();
        m.defaultTrackMenu(track, context: context);
      },
    );
  }
}