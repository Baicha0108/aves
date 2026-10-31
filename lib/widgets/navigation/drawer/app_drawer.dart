import 'package:aves/model/filters/container/album_group.dart';
import 'package:aves/model/filters/covered/stored_album.dart';
import 'package:aves/model/filters/trash.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/album.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/model/source/location/country.dart';
import 'package:aves/model/source/location/place.dart';
import 'package:aves/model/source/tag.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/theme/styles.dart';
import 'package:aves/utils/android_file_utils.dart';
import 'package:aves/utils/file_utils.dart';
import 'package:aves/widgets/about/about_page.dart';
import 'package:aves/widgets/collection/collection_page.dart';
import 'package:aves/widgets/common/basic/text/outlined.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/extensions/media_query.dart';
import 'package:aves/widgets/common/identity/aves_logo.dart';
import 'package:aves/widgets/debug/app_debug_page.dart';
import 'package:aves/widgets/explorer/explorer_page.dart';
import 'package:aves/widgets/filter_grids/albums_page.dart';
import 'package:aves/widgets/filter_grids/countries_page.dart';
import 'package:aves/widgets/filter_grids/places_page.dart';
import 'package:aves/widgets/filter_grids/tags_page.dart';
import 'package:aves/widgets/home/home_page.dart';
import 'package:aves/widgets/navigation/drawer/collection_nav_tile.dart';
import 'package:aves/widgets/navigation/drawer/page_nav_tile.dart';
import 'package:aves/widgets/navigation/drawer/tile.dart';
import 'package:aves/widgets/navigation/nav_item.dart';
import 'package:aves/widgets/settings/settings_page.dart';
import 'package:aves_miuix/aves_miuix.dart';
import 'package:aves_model/aves_model.dart';
import 'package:aves_utils/aves_utils.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class const AppDrawer({
  super.key,
  final CollectionLens? currentCollection,
  final String? currentExplorerPath,
}) extends StatefulWidget {
  // collection loaded in the `CollectionPage`, if any
  // current path loaded in the `ExplorerPage`, if any
  @override
  State<AppDrawer> createState() => _AppDrawerState();

  static List<AlbumBaseFilter> _getDefaultAlbums(BuildContext context) {
    final source = context.read<CollectionSource>();
    final specialAlbums = source.rawAlbums.where((album) {
      final type = androidFileUtils.getAlbumType(album);
      return [AlbumType.camera, AlbumType.download, AlbumType.screenshots].contains(type);
    }).toList()..sort(source.compareAlbumsByName);
    return specialAlbums.map((v) => StoredAlbumFilter(v, source.getStoredAlbumDisplayName(context, v))).toList();
  }

  static List<AlbumBaseFilter>? _getCustomAlbums(BuildContext context) {
    final source = context.read<CollectionSource>();
    return settings.drawerAlbumBookmarks?.map((v) {
      if (v is StoredAlbumFilter) {
        final album = v.album;
        return StoredAlbumFilter(album, source.getStoredAlbumDisplayName(context, album));
      }
      return v;
    }).toList();
  }

  static List<AlbumBaseFilter> effectiveAlbumBookmarks(BuildContext context) {
    return _getCustomAlbums(context) ?? _getDefaultAlbums(context);
  }
}

class _AppDrawerState extends State<AppDrawer> with WidgetsBindingObserver {
  /// Radius of the Miuix drawer header buttons (rounded rectangle, not an M3 pill).
  static const double _headerButtonRadius = 12;

  // using the default controller conflicts
  // with bottom nav bar primary scroll monitoring
  final ScrollController _scrollController = ScrollController();
  late Future<List<Object>> _profileSwitchFuture;
  bool _profileSwitchPermissionRequested = false;

  CollectionLens? get currentCollection => widget.currentCollection;

  @override
  void initState() {
    super.initState();
    _initProfileSwitchFuture();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == .resumed && _profileSwitchPermissionRequested) {
      _profileSwitchPermissionRequested = false;
      _initProfileSwitchFuture();
      setState(() {});
    }
  }

  void _initProfileSwitchFuture() {
    _profileSwitchFuture = Future.wait([
      appProfileService.canRequestInteractAcrossProfiles(),
      appProfileService.canInteractAcrossProfiles(),
      appProfileService.getProfileSwitchingLabel(),
    ]);
  }

  /// Upstream (Material) drawer content: keep the exact same widget composition as
  /// upstream, `Divider`s included.
  List<Widget> _buildUpstreamItems(BuildContext context) => <Widget>[
    _buildHeader(context),
    _buildHomeLink() ?? const SizedBox(),
    ..._buildTypeLinks(),
    _buildAlbumLinks(context),
    ..._buildPageLinks(context),
    if (settings.enableBin) ...[
      const Divider(),
      binTile(context),
    ],
    if (!kReleaseMode) ...[
      const Divider(),
      debugTile,
    ],
  ];

  // baicha fork: Miuix skin → the same navigation items are grouped into rounded
  // "sections" (cards), which replace the upstream `Divider` separators. Each card sizes
  // itself to its content, so adding/removing drawer options in the settings resizes it.
  List<Widget> _buildMiuixItems(BuildContext context) {
    final homeLink = _buildHomeLink();
    final typeTiles = _buildTypeTiles();
    final pageTiles = _buildPageTiles(context);
    return <Widget>[
      _buildHeader(context),
      if (homeLink != null || typeTiles.isNotEmpty)
        AvesMiuixDrawerSection(
          // this first card follows the header, which is not a card itself
          margin: AvesMiuixDrawerSection.leadingMargin,
          children: [
            ?homeLink,
            ...typeTiles,
          ],
        ),
      _buildAlbumTiles(context, (tiles) => AvesMiuixDrawerSection(children: tiles)),
      if (pageTiles.isNotEmpty) AvesMiuixDrawerSection(children: pageTiles),
      if (settings.enableBin) AvesMiuixDrawerSection(children: [binTile(context)]),
      if (!kReleaseMode) AvesMiuixDrawerSection(children: [debugTile]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // baicha fork: Miuix skin → Miuix surfaces for the drawer, its tiles and selection
    final miuixTheme = settings.useMiuixUi ? MiuixTheme.of(context) : null;
    final drawerItems = miuixTheme != null ? _buildMiuixItems(context) : _buildUpstreamItems(context);
    return Drawer(
      backgroundColor: miuixTheme?.colors.background,
      child: ListTileTheme.merge(
        selectedColor: miuixTheme?.colors.primary ?? Theme.of(context).colorScheme.primary,
        textColor: miuixTheme?.colors.onBackground,
        iconColor: miuixTheme?.colors.onBackground,
        selectedTileColor: miuixTheme?.colors.secondaryContainer,
        // baicha fork: Miuix-only — the selected tile is a rounded, inset pill: `shape`
        // rounds the highlight (and the splash) while `contentPadding` keeps the tile
        // content away from the pill edge.
        shape: miuixTheme != null ? AvesMiuixDrawerSection.selectionShape : null,
        contentPadding: miuixTheme != null ? AvesMiuixDrawerSection.itemContentPadding : null,
        horizontalTitleGap: 20,
        visualDensity: VisualDensity.comfortable,
        child: Selector<MediaQueryData, double>(
          selector: (context, mq) => mq.safeBottomPadding,
          builder: (context, safeBottomPadding, child) {
            final textScaler = MediaQuery.textScalerOf(context);
            final iconTheme = IconTheme.of(context);
            return SingleChildScrollView(
              controller: _scrollController,
              // key is expected by test driver
              key: const Key('drawer-scrollview'),
              padding: EdgeInsets.only(bottom: safeBottomPadding),
              child: IconTheme(
                data: iconTheme.copyWith(
                  size: textScaler.scale(iconTheme.size!),
                ),
                child: Column(
                  children: drawerItems,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = context.l10n;
    final appName = l10n.appName;

    Future<void> goTo(String routeName, WidgetBuilder pageBuilder) async {
      Navigator.maybeOf(context)?.pop();
      await Future.pause(ADurations.drawerTransitionLoose);
      await Navigator.maybeOf(context)?.push(
        MaterialPageRoute(
          settings: RouteSettings(name: routeName),
          builder: pageBuilder,
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final miuixColors = settings.useMiuixUi ? MiuixTheme.of(context).colors : null;
    final onPrimary = miuixColors?.onPrimary ?? colorScheme.onPrimary;

    final drawerButtonStyle = ButtonStyle(
      padding: WidgetStateProperty.all(const EdgeInsetsDirectional.only(start: 12, end: 16)),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: miuixColors == null ? colorScheme.primary : null,
      // baicha fork: Miuix-only — the drawer header stays full-bleed (the accent color
      // still fills the status bar area) but gets rounded bottom corners, matching the
      // radius of the cards below it.
      decoration: miuixColors == null
          ? null
          : BoxDecoration(
              color: miuixColors.primary,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AvesMiuixDrawerSection.defaultCornerRadius)),
            ),
      child: SafeArea(
        bottom: false,
        child: OutlinedButtonTheme(
          data: OutlinedButtonThemeData(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.all<Color>(onPrimary),
              overlayColor: WidgetStateProperty.all<Color>(onPrimary.withValues(alpha: .12)),
              iconColor: WidgetStateProperty.all<Color>(onPrimary),
              side: WidgetStateProperty.all<BorderSide>(BorderSide(width: 1, color: onPrimary.withValues(alpha: .24))),
              // baicha fork: Miuix-only — the header buttons (关于/设置/切换用户) are
              // rounded rectangles instead of the Material 3 pill (`StadiumBorder`).
              shape: miuixColors == null
                  ? null
                  : WidgetStateProperty.all<OutlinedBorder>(
                      const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(_headerButtonRadius))),
                    ),
            ),
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              const SizedBox(height: 6),
              Align(
                alignment: .centerStart,
                child: Wrap(
                  spacing: 16,
                  crossAxisAlignment: .center,
                  children: [
                    const AvesLogo(size: 48),
                    OutlinedText(
                      textSpans: [
                        TextSpan(
                          text: appName,
                          style: AStyles.appNameStyle(context, appName).copyWith(
                            color: Colors.white,
                            fontSize: miuixColors != null ? 32 : 38,
                            fontWeight: miuixColors != null ? .w400 : .w300,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    // key is expected by test driver
                    key: const Key('drawer-about-button'),
                    onPressed: () => goTo(AboutPage.routeName, (_) => const AboutPage()),
                    style: drawerButtonStyle,
                    icon: const Icon(AIcons.info),
                    label: Text(l10n.drawerAboutButton),
                  ),
                  OutlinedButton.icon(
                    // key is expected by test driver
                    key: const Key('drawer-settings-button'),
                    onPressed: () => goTo(SettingsPage.routeName, (_) => const SettingsPage()),
                    style: drawerButtonStyle,
                    icon: const Icon(AIcons.settings),
                    label: Text(l10n.drawerSettingsButton),
                  ),
                ],
              ),
              FutureBuilder<List<Object>>(
                future: _profileSwitchFuture,
                builder: (context, snapshot) {
                  final flags = snapshot.data;
                  if (flags == null) return const SizedBox();

                  final canRequestInteractAcrossProfiles = flags[0] as bool;
                  final canSwitchProfile = flags[1] as bool;
                  final profileSwitchingLabel = flags[2] as String;
                  if ((!canRequestInteractAcrossProfiles && !canSwitchProfile) || profileSwitchingLabel.isEmpty) return const SizedBox();

                  return OutlinedButton(
                    onPressed: () async {
                      if (canSwitchProfile) {
                        await appProfileService.switchProfile();
                      } else {
                        _profileSwitchPermissionRequested = await appProfileService.requestInteractAcrossProfiles();
                      }
                    },
                    child: Text(profileSwitchingLabel),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// The customizable home link, if any: `null` when the home page is not a bookmark.
  Widget? _buildHomeLink() {
    // route name used for display purposes, no actual routing
    const displayRoute = HomePage.routeName;
    const leading = DrawerPageIcon(route: displayRoute);
    const title = DrawerPageTitle(route: displayRoute);

    switch (settings.homeNavItem.route) {
      case CollectionPage.routeName:
        final filters = settings.homeCustomCollection;
        if (filters.isNotEmpty) {
          return CollectionNavTile(
            leading: leading,
            title: title,
            filters: filters,
            isSelected: () => setEquals(currentCollection?.filters, filters),
          );
        }
      case ExplorerPage.routeName:
        final path = settings.homeCustomExplorerPath;
        if (path != null) {
          return PageNavTile(
            leading: leading,
            title: title,
            navItem: AvesNavItem(route: ExplorerPage.routeName, path: path),
            isSelected: () => widget.currentExplorerPath == path,
          );
        }
    }
    return null;
  }

  List<Widget> _buildTypeTiles() {
    final hiddenFilters = settings.hiddenFilters;
    final typeBookmarks = settings.drawerTypeBookmarks;
    final currentFilters = currentCollection?.filters;
    return typeBookmarks
        .where((filter) => !hiddenFilters.contains(filter))
        .map(
          (filter) => CollectionNavTile(
            // key is expected by test driver
            key: Key('drawer-type-${filter?.key}'),
            leading: DrawerFilterIcon(filter: filter),
            title: DrawerFilterTitle(filter: filter),
            filters: {filter},
            isSelected: () {
              if (currentFilters == null || currentFilters.length > 1) return false;
              return currentFilters.firstOrNull == filter;
            },
          ),
        )
        .toList();
  }

  List<Widget> _buildTypeLinks() {
    final tiles = _buildTypeTiles();
    return [
      if (tiles.isNotEmpty) const SizedBox(height: 8),
      ...tiles,
    ];
  }

  Widget _buildAlbumTiles(BuildContext context, Widget Function(List<Widget> tiles) builder) {
    final source = context.read<CollectionSource>();
    final currentFilters = currentCollection?.filters;
    return StreamBuilder<AlbumsChangedEvent>(
      stream: source.eventBus.on<AlbumsChangedEvent>(),
      builder: (context, _) {
        final albums = AppDrawer.effectiveAlbumBookmarks(context);
        if (albums.isEmpty) return const SizedBox();
        return builder(
          albums
              .map(
                (filter) => AlbumNavTile(
                  filter: filter,
                  isSelected: () {
                    if (currentFilters == null || currentFilters.length != 1) return false;
                    return currentFilters.firstOrNull == filter;
                  },
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildAlbumLinks(BuildContext context) => _buildAlbumTiles(context, (tiles) => Column(children: [const Divider(), ...tiles]));

  List<Widget> _buildPageTiles(BuildContext context) {
    final pageBookmarks = settings.drawerPageBookmarks;
    if (pageBookmarks.isEmpty) return [];

    final source = context.read<CollectionSource>();
    final itemCountFormatter = settings.avesLocale.decimalNumberFormat();
    return pageBookmarks.map((route) {
      Widget? trailing;
      switch (route) {
        case AlbumListPage.routeName:
          trailing = StreamBuilder<AlbumsChangedEvent>(
            stream: source.eventBus.on<AlbumsChangedEvent>(),
            builder: (context, _) => Text(itemCountFormatter.format(source.rawAlbums.length)),
          );
        case CountryListPage.routeName:
          trailing = StreamBuilder<CountriesChangedEvent>(
            stream: source.eventBus.on<CountriesChangedEvent>(),
            builder: (context, _) => Text(itemCountFormatter.format(source.sortedCountries.length)),
          );
        case PlaceListPage.routeName:
          trailing = StreamBuilder<PlacesChangedEvent>(
            stream: source.eventBus.on<PlacesChangedEvent>(),
            builder: (context, _) => Text(itemCountFormatter.format(source.sortedPlaces.length)),
          );
        case TagListPage.routeName:
          trailing = StreamBuilder<TagsChangedEvent>(
            stream: source.eventBus.on<TagsChangedEvent>(),
            builder: (context, _) => Text(itemCountFormatter.format(source.sortedTags.length)),
          );
      }

      return PageNavTile(
        // key is expected by test driver
        key: Key('drawer-page-$route'),
        trailing: trailing,
        navItem: AvesNavItem(route: route),
      );
    }).toList();
  }

  List<Widget> _buildPageLinks(BuildContext context) {
    final tiles = _buildPageTiles(context);
    return [
      if (tiles.isNotEmpty) const Divider(),
      ...tiles,
    ];
  }

  Widget binTile(BuildContext context) {
    final source = context.read<CollectionSource>();
    final trashSize = source.trashedEntries.map((entry) => entry.sizeBytes).sum;

    const filter = TrashFilter.instance;
    return CollectionNavTile(
      leading: const DrawerFilterIcon(filter: filter),
      title: const DrawerFilterTitle(filter: filter),
      trailing: Text(formatFileSize(settings.avesLocale, trashSize, round: 0)),
      filters: {filter},
      isSelected: () => currentCollection?.filters.contains(filter) ?? false,
    );
  }

  Widget get debugTile => const PageNavTile(
    // key is expected by test driver
    key: Key('drawer-debug'),
    navItem: AvesNavItem(route: AppDebugPage.routeName),
  );
}
