import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Element;
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:ncldoc/ncl_document.dart';
import 'package:nclui/base_widget.dart';
import 'package:nclui/nclui_plugins.dart';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';
import 'package:xml/xml.dart';

import 'plugin_base.dart';
import 'ncl360_math.dart';

enum Ncl360Projection {
  auto,
  equirectangular,
  eac;

  static Ncl360Projection fromString(String? val) {
    if (val == null) return Ncl360Projection.auto;
    final lower = val.toLowerCase().trim();
    if (lower == 'eac' ||
        lower == 'sbs' ||
        lower == 'cubemap' ||
        lower == 'equiangularcubemap') {
      return Ncl360Projection.eac;
    }
    if (lower == 'equirectangular' || lower == 'equirect' || lower == 'erp') {
      return Ncl360Projection.equirectangular;
    }
    return Ncl360Projection.auto;
  }
}

class Ncl360Hotspot {
  final String id;
  final SphericalCoordinate coordinate;
  final String? label;
  final double width;
  final double height;
  final Color color;
  final Color? backgroundColor;
  final IconData icon;
  final String? targetComponent;
  final String? mediaSrc;
  final String? mediaType;
  bool inView;

  Ncl360Hotspot({
    required this.id,
    required this.coordinate,
    this.label,
    this.width = 44.0,
    this.height = 44.0,
    this.color = Colors.cyanAccent,
    this.backgroundColor,
    this.icon = Icons.place,
    this.targetComponent,
    this.mediaSrc,
    this.mediaType,
    this.inView = false,
  });
}

Color? _parseColor(String? colorStr) {
  if (colorStr == null || colorStr.trim().isEmpty) return null;
  final s = colorStr.trim();
  if (s.startsWith('#')) {
    final hex = s.substring(1);
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    } else if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
  }
  switch (s.toLowerCase()) {
    case 'gray':
    case 'grey':
      return Colors.grey;
    case 'red':
      return Colors.red;
    case 'green':
      return Colors.green;
    case 'blue':
      return Colors.blue;
    case 'yellow':
      return Colors.yellow;
    case 'black':
      return Colors.black;
    case 'white':
      return Colors.white;
    case 'cyan':
      return Colors.cyan;
    case 'transparent':
      return Colors.transparent;
    default:
      return null;
  }
}

class Ncl360MediaPlugin implements NclMediaPlugin, PluginBase {
  @override
  PluginType get type => PluginType.optional;

  @override
  bool canHandle(String src, String? mimeType) {
    final lowerSrc = src.toLowerCase();
    if (lowerSrc.endsWith('.360.jpg') ||
        lowerSrc.endsWith('.360.jpeg') ||
        lowerSrc.endsWith('.360.png') ||
        lowerSrc.endsWith('.360.webp') ||
        lowerSrc.endsWith('.360.mp4') ||
        lowerSrc.endsWith('pano.mp4') ||
        lowerSrc.endsWith('.pano') ||
        lowerSrc.endsWith('.360') ||
        lowerSrc.endsWith('.ncl360') ||
        lowerSrc.contains('.360.')) {
      return true;
    }
    if (mimeType == 'image/360' ||
        mimeType == 'video/360' ||
        mimeType == 'video/mp4;profile=360' ||
        mimeType == 'application/x-ginga-360' ||
        mimeType == 'application/x-ncl-360' ||
        mimeType == 'application/x-ncl360') {
      return true;
    }
    return false;
  }

  @override
  Widget buildWidget({
    Key? key,
    required String src,
    String? mimeType,
    Media? media,
    NclDocument? document,
    FocusNode? focusNode,
  }) {
    return Scene360Widget(
      key: key,
      src: src,
      mimeType: mimeType,
      media: media,
      document: document,
      focusNode: focusNode,
    );
  }
}

class Scene360Widget extends BaseWidget {
  final String? mimeType;
  final FocusNode? focusNode;

  const Scene360Widget({
    super.key,
    required super.src,
    this.mimeType,
    super.media,
    super.document,
    this.focusNode,
  });

  @override
  State<Scene360Widget> createState() => _Scene360WidgetState();
}

class _Scene360WidgetState extends MediaState<Scene360Widget> {
  double yaw = 0.0;
  double pitch = 0.0;
  double roll = 0.0;
  double fieldOfView = 90.0;

  ui.Image? _loadedImage;
  VideoPlayerController? _videoController;
  bool _isVideo = false;
  bool _isVideoInitialized = false;
  Ncl360Projection _projection = Ncl360Projection.auto;

  bool _isLoading = true;
  String? _errorMessage;
  final List<Ncl360Hotspot> _hotspots = [];

  @override
  void initState() {
    super.initState();
    _extractInitialProperties();
    _extractHotspots();
    _initMediaSource();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkHotspotsView();
      }
    });
  }

  void _extractInitialProperties() {
    final m = widget.media;
    if (m == null) return;

    String? rawYaw;
    String? rawPitch;
    String? rawRoll;
    String? rawFov;
    String? rawProjection;

    for (final prop in m.getProperties()) {
      if (prop.name == 'yaw') {
        rawYaw = prop.value;
      }
      if (prop.name == 'pitch') {
        rawPitch = prop.value;
      }
      if (prop.name == 'roll') {
        rawRoll = prop.value;
      }
      if (prop.name == 'fieldOfView' || prop.name == 'fov') {
        rawFov = prop.value;
      }
      if (prop.name == 'projection' || prop.name == 'format') {
        rawProjection = prop.value;
      }
    }

    rawYaw ??= m.rawAttributes['yaw'];
    rawPitch ??= m.rawAttributes['pitch'];
    rawRoll ??= m.rawAttributes['roll'];
    rawFov ??= m.rawAttributes['fieldOfView'] ?? m.rawAttributes['fov'];
    rawProjection ??=
        m.rawAttributes['projection'] ?? m.rawAttributes['format'];

    final desc = widget.document?.getDescriptorForMedia(m);
    if (desc != null) {
      for (final param in desc.children.whereType<DescriptorParam>()) {
        if (param.name == 'yaw') rawYaw ??= param.value;
        if (param.name == 'pitch') rawPitch ??= param.value;
        if (param.name == 'roll') rawRoll ??= param.value;
        if (param.name == 'fieldOfView' || param.name == 'fov') {
          rawFov ??= param.value;
        }
        if (param.name == 'projection' || param.name == 'format') {
          rawProjection ??= param.value;
        }
      }
      rawProjection ??=
          desc.rawAttributes['projection'] ?? desc.rawAttributes['format'];
    }

    if (rawProjection != null) {
      _projection = Ncl360Projection.fromString(rawProjection);
    }

    if (rawYaw != null) {
      yaw = double.tryParse(rawYaw) ?? yaw;
    }
    if (rawPitch != null) {
      pitch = double.tryParse(rawPitch) ?? pitch;
    }
    if (rawRoll != null) {
      roll = double.tryParse(rawRoll) ?? roll;
    }
    if (rawFov != null) {
      fieldOfView = double.tryParse(rawFov) ?? fieldOfView;
    }

    yaw = SphericalCoordinate.normalizeDegrees(yaw);
    pitch = pitch.clamp(-85.0, 85.0);
    fieldOfView = fieldOfView.clamp(30.0, 120.0);
  }

  void _extractHotspots() {
    _hotspots.clear();
    final m = widget.media;
    if (m == null) return;

    for (final child in m.children.whereType<Area>()) {
      final areaId = child.id ?? child.rawAttributes['id'];
      if (areaId == null || areaId.isEmpty) continue;

      final rawPolar = child.rawAttributes['polar'];
      final rawAzimuthal = child.rawAttributes['azimuthal'];
      final rawRadius = child.rawAttributes['radius'];
      final rawPin = child.rawAttributes['pin'];
      final label =
          child.rawAttributes['label'] ?? child.rawAttributes['title'];
      final target =
          child.rawAttributes['target'] ?? child.rawAttributes['component'];

      if (rawPolar != null || rawAzimuthal != null) {
        final polarVal = double.tryParse(rawPolar ?? '0') ?? 0.0;
        final azVal = double.tryParse(rawAzimuthal ?? '0') ?? 0.0;
        final radVal = double.tryParse(rawRadius ?? '1') ?? 1.0;
        final pinType = PinType.fromString(rawPin);

        _hotspots.add(
          Ncl360Hotspot(
            id: areaId,
            coordinate: SphericalCoordinate(
              polar: polarVal,
              azimuthal: azVal,
              radius: radVal,
              pin: pinType,
            ),
            label: label,
            targetComponent: target,
          ),
        );
      }
    }

    for (final prop in m.getProperties()) {
      if (prop.name == 'hotspot' && prop.value != null) {
        final pairs = prop.value!.split(',');
        String? spotId;
        double polarVal = 0.0;
        double azVal = 0.0;
        double radVal = 1.0;
        PinType pinType = PinType.environment;
        String? spotLabel;
        String? spotTarget;

        for (final pair in pairs) {
          final parts = pair.split('=');
          if (parts.length != 2) continue;
          final key = parts[0].trim().toLowerCase();
          final val = parts[1].trim();
          if (key == 'id') spotId = val;
          if (key == 'polar') polarVal = double.tryParse(val) ?? 0.0;
          if (key == 'azimuthal') azVal = double.tryParse(val) ?? 0.0;
          if (key == 'radius') radVal = double.tryParse(val) ?? 1.0;
          if (key == 'pin') pinType = PinType.fromString(val);
          if (key == 'label') spotLabel = val;
          if (key == 'target') spotTarget = val;
        }

        if (spotId != null && spotId.isNotEmpty) {
          _hotspots.add(
            Ncl360Hotspot(
              id: spotId,
              coordinate: SphericalCoordinate(
                polar: polarVal,
                azimuthal: azVal,
                radius: radVal,
                pin: pinType,
              ),
              label: spotLabel,
              targetComponent: spotTarget,
            ),
          );
        }
      }
    }
  }

  bool _isHotspotActive(Ncl360Hotspot spot) {
    final lowerMime = widget.mimeType?.toLowerCase() ?? '';
    final lowerSrc = widget.src.toLowerCase();
    final isNcl360 =
        (lowerMime == 'application/x-ncl360' || lowerSrc.endsWith('.ncl360'));
    if (!isNcl360) return true;

    final mediaNode = widget.media;
    if (mediaNode == null) return true;
    final areas =
        mediaNode.children.whereType<Area>().where((a) => a.id == spot.id);
    if (areas.isEmpty) return true;
    final areaEvt = mediaNode.getAreaNclEvent(spot.id);
    if (widget.document != null &&
        widget.document!.body.children.whereType<Link>().isEmpty) {
      return true;
    }
    return areaEvt.state == NclStateType.occurring;
  }

  void _checkHotspotsView() {
    final doc = widget.document;

    for (final hotspot in _hotspots) {
      if (!_isHotspotActive(hotspot)) {
        if (hotspot.inView) {
          hotspot.inView = false;
          if (doc != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              doc.handleViewTransition(
                widget.media?.id ?? hotspot.id,
                false,
                hotspot.id,
              );
            });
          }
        }
        continue;
      }

      final inViewNow = hotspot.coordinate.isInView(
        cameraYaw: yaw,
        cameraPitch: pitch,
        fov: fieldOfView,
      );

      if (inViewNow != hotspot.inView) {
        hotspot.inView = inViewNow;
        final doc = widget.document;
        if (doc != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            doc.handleViewTransition(
              widget.media?.id ?? hotspot.id,
              inViewNow,
              hotspot.id,
            );
            doc
                .getNodeById(hotspot.id)
                ?.setPropertyValue('inView', inViewNow ? 'true' : 'false');
          });
        }
      }
    }
  }

  void _syncPropertiesToNcl() {
    widget.media?.setPropertyValue('yaw', yaw.toStringAsFixed(2));
    widget.media?.setPropertyValue('pitch', pitch.toStringAsFixed(2));
    widget.media?.setPropertyValue('roll', roll.toStringAsFixed(2));
    widget.media?.setPropertyValue('fov', fieldOfView.toStringAsFixed(2));
    widget.media
        ?.setPropertyValue('fieldOfView', fieldOfView.toStringAsFixed(2));
  }

  void _initMediaSource() {
    final lowerSrc = widget.src.toLowerCase();
    final lowerMime = widget.mimeType?.toLowerCase() ?? '';

    if (lowerSrc.endsWith('.ncl360') || lowerMime == 'application/x-ncl360') {
      _initNcl360Doc();
      return;
    }

    final pathLower =
        (Uri.tryParse(widget.src)?.path ?? widget.src).toLowerCase();
    _isVideo = pathLower.endsWith('.mp4') ||
        pathLower.endsWith('.360.mp4') ||
        pathLower.endsWith('.mpeg') ||
        pathLower.endsWith('.webm') ||
        lowerSrc.contains('.mp4') ||
        lowerMime.startsWith('video/');

    if (_isVideo) {
      _initVideo();
    } else {
      _loadImage();
    }
  }

  Future<void> _initNcl360Doc() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? xmlText;
      String effectiveDocPath = widget.src;

      final parsedUri = widget.privateBase.resolveUri(widget.src);
      final fileName = path
          .basename(parsedUri.path.isNotEmpty ? parsedUri.path : widget.src);

      final candidates = [
        widget.src,
        if (parsedUri.isScheme('file')) parsedUri.toFilePath(),
        path.join('examples', widget.src),
        path.join(Directory.current.path, 'examples', widget.src),
        fileName,
        path.join('examples', 'video360', fileName),
        path.join('examples', 'video360', widget.src),
        path.join(Directory.current.path, fileName),
        path.join(Directory.current.path, 'examples', 'video360', fileName),
      ];

      for (final cand in candidates) {
        final f = File(cand);
        if (f.existsSync()) {
          xmlText = await f.readAsString();
          effectiveDocPath = f.path;
          break;
        }
      }

      if (xmlText == null &&
          (widget.src.startsWith('http://') ||
              widget.src.startsWith('https://'))) {
        final resp = await http.get(Uri.parse(widget.src));
        if (resp.statusCode == 200) {
          xmlText = resp.body;
        }
      }

      if (xmlText == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load NCL360 document: ${widget.src}';
        });
        return;
      }

      final doc = XmlDocument.parse(xmlText);
      final docDir = path.dirname(effectiveDocPath);

      final regions = <String, Map<String, dynamic>>{};
      for (final reg in doc.findAllElements('region')) {
        final id = reg.getAttribute('id');
        if (id == null) continue;
        regions[id] = {
          'polar': _parseUnit(reg.getAttribute('polar')),
          'azimuthal': _parseUnit(reg.getAttribute('azimuthal')),
          'radius': _parseUnit(reg.getAttribute('radius')) ?? 1.0,
          'pin': reg.getAttribute('pin') ?? 'environment',
          'width': _parseUnit(reg.getAttribute('width')) ?? 44.0,
          'height': _parseUnit(reg.getAttribute('height')) ?? 44.0,
          'label': reg.getAttribute('label') ?? reg.getAttribute('title'),
          'background': reg.getAttribute('background'),
        };
      }

      final descriptors = <String, Map<String, dynamic>>{};
      for (final desc in doc.findAllElements('descriptor')) {
        final id = desc.getAttribute('id');
        if (id == null) continue;
        String? descBg = desc.getAttribute('background');
        for (final param in desc.findElements('descriptorParam')) {
          if (param.getAttribute('name') == 'background') {
            descBg ??= param.getAttribute('value');
          }
        }
        descriptors[id] = {
          'region': desc.getAttribute('region'),
          'volume':
              double.tryParse(desc.getAttribute('volume') ?? '1.0') ?? 1.0,
          'soundType': desc.getAttribute('soundType'),
          'projection':
              desc.getAttribute('projection') ?? desc.getAttribute('format'),
          'background': descBg,
        };
      }

      String? skyboxSrc;

      for (final m in doc.findAllElements('media')) {
        final mediaId = m.getAttribute('id');
        final mediaSrc = m.getAttribute('src');
        final descId = m.getAttribute('descriptor');
        if (mediaId == null || mediaSrc == null) continue;

        final desc = descriptors[descId];
        final regionId = desc?['region'] as String?;
        final resolvedSrc = _resolveSubMediaSrc(mediaSrc, docDir);

        if (regionId == 'default.sky' || regionId == 'sky') {
          skyboxSrc = resolvedSrc;
          final rawProj = m.getAttribute('projection') ??
              m.getAttribute('format') ??
              desc?['projection'] as String?;
          if (rawProj != null) {
            _projection = Ncl360Projection.fromString(rawProj);
          }
        } else {
          final reg = regions[regionId];
          final polarVal = (reg?['polar'] as double?) ?? 0.0;
          final azVal = (reg?['azimuthal'] as double?) ?? 0.0;
          final radVal = (reg?['radius'] as double?) ?? 1.0;
          final pinStr = (reg?['pin'] as String?) ?? 'environment';
          final labelVal = m.getAttribute('label') ??
              m.getAttribute('title') ??
              (reg?['label'] as String?) ??
              mediaId;

          String? mediaBg = m.getAttribute('background');
          for (final prop in m.findElements('property')) {
            if (prop.getAttribute('name') == 'background') {
              mediaBg ??= prop.getAttribute('value');
            }
          }
          mediaBg ??= desc?['background'] as String?;
          mediaBg ??= reg?['background'] as String?;
          final bgColor = _parseColor(mediaBg);

          _hotspots.add(
            Ncl360Hotspot(
              id: mediaId,
              coordinate: SphericalCoordinate(
                polar: polarVal,
                azimuthal: azVal,
                radius: radVal,
                pin: PinType.fromString(pinStr),
              ),
              label: labelVal,
              mediaSrc: resolvedSrc,
              backgroundColor: bgColor,
            ),
          );
        }
      }

      if (skyboxSrc != null) {
        final pathLower =
            (Uri.tryParse(skyboxSrc)?.path ?? skyboxSrc).toLowerCase();
        if (pathLower.endsWith('.mp4') ||
            pathLower.endsWith('.webm') ||
            pathLower.endsWith('.mpeg') ||
            skyboxSrc.toLowerCase().contains('.mp4')) {
          _isVideo = true;
          await _initVideo(skyboxSrc);
        } else {
          _isVideo = false;
          _loadImage(skyboxSrc);
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }

      _checkHotspotsView();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  double? _parseUnit(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final match = RegExp(r'([-+]?[0-9]*\.?[0-9]+)').firstMatch(val);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  String _resolveSubMediaSrc(String rawSrc, String docDir) {
    if (rawSrc.startsWith('http://') || rawSrc.startsWith('https://')) {
      return rawSrc;
    }

    final fileName = path.basename(Uri.tryParse(rawSrc)?.path ?? rawSrc);
    final ext = path.extension(fileName);
    final baseWithoutExt = path.withoutExtension(fileName);
    final equirectFileName = '$baseWithoutExt.equirect$ext';

    if (_projection != Ncl360Projection.eac) {
      final equirectCandidates = [
        path.join(docDir, equirectFileName),
        path.join(docDir, 'media', equirectFileName),
        path.join('examples', 'video360', 'media', equirectFileName),
        path.join('media', equirectFileName),
        equirectFileName,
      ];
      for (final cand in equirectCandidates) {
        final f = File(cand);
        if (f.existsSync()) return f.absolute.path;
      }
    }

    final candidates = [
      rawSrc,
      path.join(docDir, rawSrc),
      path.join(docDir, fileName),
      path.join(docDir, 'media', fileName),
      path.join('examples', 'video360', 'media', fileName),
      path.join('media', fileName),
      fileName,
    ];
    for (final cand in candidates) {
      final f = File(cand);
      if (f.existsSync()) return f.absolute.path;
    }
    if (fileName == 'pano.mp4') {
      return 'https://threejs.org/examples/textures/pano.mp4';
    }
    return rawSrc;
  }

  Future<void> _initVideo([String? targetSrc]) async {
    String videoSrc = targetSrc ?? widget.src;
    if (videoSrc.trim().isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final isRemoteUrl =
        videoSrc.startsWith('http://') || videoSrc.startsWith('https://');

    if (!isRemoteUrl &&
        _projection != Ncl360Projection.eac &&
        !videoSrc.contains('.equirect.')) {
      final dir = path.dirname(videoSrc);
      final base = path.basenameWithoutExtension(videoSrc);
      final ext = path.extension(videoSrc);
      final equirectCand = path.join(dir, '$base.equirect$ext');
      if (File(equirectCand).existsSync()) {
        videoSrc = equirectCand;
        _projection = Ncl360Projection.equirectangular;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final parsedUri = widget.privateBase.resolveUri(videoSrc);
      final VideoPlayerController controller;

      final File directFile = File(videoSrc);
      if (!isRemoteUrl && directFile.existsSync()) {
        controller = VideoPlayerController.file(directFile.absolute);
      } else if (kIsWeb ||
          isRemoteUrl ||
          (parsedUri.hasScheme && parsedUri.scheme != 'file')) {
        controller = VideoPlayerController.networkUrl(parsedUri);
      } else if (parsedUri.isScheme('file')) {
        controller = VideoPlayerController.file(File(parsedUri.toFilePath()));
      } else {
        controller = VideoPlayerController.file(
          File(Uri.decodeComponent(parsedUri.path)),
        );
      }

      _videoController = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(soundLevel);
      await controller.play();

      final ar = controller.value.aspectRatio;
      if (_projection == Ncl360Projection.auto) {
        if (videoSrc.contains('.equirect.') || (ar >= 1.6 && ar <= 2.4)) {
          _projection = Ncl360Projection.equirectangular;
        } else if (ar > 0 && ar < 1.4) {
          _projection = Ncl360Projection.eac;
        } else {
          _projection = Ncl360Projection.equirectangular;
        }
      }

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (isRemoteUrl) {
        final fileName =
            path.basename(Uri.tryParse(videoSrc)?.path ?? videoSrc);
        final localCandidates = [
          path.join(path.dirname(widget.src), fileName),
          path.join('examples', '360_panorama', fileName),
          fileName,
        ];
        for (final cand in localCandidates) {
          final f = File(cand);
          if (f.existsSync()) {
            await _initVideo(f.absolute.path);
            return;
          }
        }
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _loadImage([String? targetSrc]) {
    final imgSrc = targetSrc ?? widget.src;
    if (imgSrc.trim().isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final parsedUri = widget.privateBase.resolveUri(imgSrc);

      ImageProvider provider;
      final localFile = File(imgSrc);
      if (localFile.existsSync()) {
        provider = FileImage(localFile);
      } else if (kIsWeb ||
          parsedUri.scheme == 'http' ||
          parsedUri.scheme == 'https' ||
          parsedUri.scheme == 'data') {
        provider = NetworkImage(parsedUri.toString());
      } else {
        final filePath = parsedUri.isScheme('file')
            ? parsedUri.toFilePath()
            : parsedUri.path;
        final file = File(filePath);
        if (file.existsSync()) {
          provider = FileImage(file);
        } else {
          provider = AssetImage(imgSrc);
        }
      }

      final stream = provider.resolve(ImageConfiguration.empty);
      stream.addListener(
        ImageStreamListener(
          (info, _) {
            if (mounted) {
              setState(() {
                _loadedImage = info.image;
                _isLoading = false;
              });
            }
          },
          onError: (dynamic error, StackTrace? stackTrace) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      yaw = (yaw - details.delta.dx * 0.3) % 360.0;
      if (yaw < 0) yaw += 360.0;
      pitch = (pitch + details.delta.dy * 0.3).clamp(-85.0, 85.0);
      _checkHotspotsView();
      _syncPropertiesToNcl();
    });
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() {
        fieldOfView = (fieldOfView + (event.scrollDelta.dy > 0 ? 3.0 : -3.0))
            .clamp(30.0, 120.0);
        _checkHotspotsView();
        _syncPropertiesToNcl();
      });
    }
  }

  void _handleHotspotTap(Ncl360Hotspot hotspot) {
    widget.document?.setFocus(hotspot.id);
    widget.document?.handleSelection(hotspot.id);
    if (hotspot.targetComponent != null) {
      widget.document?.handleSelection(hotspot.targetComponent!);
    }
  }

  @override
  void pause() {
    super.pause();
    _videoController?.pause();
  }

  @override
  void resume() {
    super.resume();
    _videoController?.play();
  }

  @override
  void didUpdateWidget(Scene360Widget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) {
      _videoController?.dispose();
      _videoController = null;
      _isVideoInitialized = false;
      _loadedImage = null;
      _initMediaSource();
    }
  }

  @override
  void parseProperties([Media? targetMedia]) {
    super.parseProperties(targetMedia);
    _extractInitialProperties();
    _videoController?.setVolume(soundLevel);
    if (mounted) {
      setState(() {});
      _checkHotspotsView();
    }
  }

  @override
  bool handleKeyPress(String keyCode) {
    return false;
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Widget _buildVideoPanorama(Size size) {
    final controller = _videoController;
    if (controller == null || !_isVideoInitialized) {
      return Container(color: Colors.black);
    }

    final bool isEacSBS = _projection == Ncl360Projection.eac;
    final double rawVideoAspect =
        controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 2.0;
    final double effectiveAspect =
        isEacSBS ? (rawVideoAspect * 0.5) : rawVideoAspect;

    final double panoWidth = size.width * (360.0 / fieldOfView);
    final double panoHeight = math.max(
      isEacSBS
          ? (panoWidth / (effectiveAspect * 2.0))
          : (panoWidth / effectiveAspect),
      size.height * 2.0,
    );

    final double normalizedYaw = ((yaw % 360.0) + 360.0) % 360.0;
    final double span =
        (panoWidth > size.width) ? (panoWidth - size.width) : 0.0;
    final double mainLeft = span > 0
        ? -(normalizedYaw / 360.0) * span
        : (size.width - panoWidth) / 2.0;

    final double baseTop = (size.height / 2.0) -
        (0.5 * panoHeight) +
        (pitch * (panoHeight / 180.0));
    final double clampedTop = panoHeight > size.height
        ? baseTop.clamp(size.height - panoHeight, 0.0)
        : (size.height - panoHeight) / 2.0;

    final Widget videoWidget = isEacSBS
        ? ClipRect(
            child: SizedBox(
              width: panoWidth,
              height: panoHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 0.5,
                child: SizedBox(
                  width: panoWidth * 2.0,
                  height: panoHeight,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: controller.value.size.width > 0
                          ? controller.value.size.width
                          : panoWidth * 2.0,
                      height: controller.value.size.height > 0
                          ? controller.value.size.height
                          : panoHeight,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
              ),
            ),
          )
        : SizedBox(
            width: panoWidth,
            height: panoHeight,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: controller.value.size.width > 0
                    ? controller.value.size.width
                    : panoWidth,
                height: controller.value.size.height > 0
                    ? controller.value.size.height
                    : panoHeight,
                child: VideoPlayer(controller),
              ),
            ),
          );

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: mainLeft,
            top: clampedTop,
            width: panoWidth,
            height: panoHeight,
            child: videoWidget,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHotspotsWidgets(Size size) {
    final widgets = <Widget>[];

    for (final spot in _hotspots) {
      if (!_isHotspotActive(spot)) continue;

      if (spot.coordinate.pin == PinType.camera) {
        Widget? imgWidget;
        if (spot.mediaSrc != null) {
          final f = File(spot.mediaSrc!);
          if (f.existsSync()) {
            imgWidget =
                Image.file(f, width: 140, height: 90, fit: BoxFit.contain);
          } else if (spot.mediaSrc!.startsWith('http')) {
            imgWidget = Image.network(spot.mediaSrc!,
                width: 140, height: 90, fit: BoxFit.contain);
          }
        }
        widgets.add(
          Positioned(
            right: 16.0,
            bottom: 16.0,
            child: GestureDetector(
              onTap: () => _handleHotspotTap(spot),
              child: imgWidget ??
                  (spot.label != null
                      ? Text(
                          spot.label!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.0,
                          ),
                        )
                      : const SizedBox.shrink()),
            ),
          ),
        );
        continue;
      }

      if (!spot.inView) continue;

      final projectedOffset = spot.coordinate.projectToViewport(
        cameraYaw: yaw,
        cameraPitch: pitch,
        cameraRoll: roll,
        fov: fieldOfView,
        viewportSize: size,
      );

      if (projectedOffset == null) continue;

      final left = projectedOffset.dx - (spot.width / 2.0);
      final top = projectedOffset.dy - (spot.height / 2.0);

      if (left < -spot.width ||
          left > size.width ||
          top < -spot.height ||
          top > size.height) {
        continue;
      }

      Widget? thumbWidget;
      String? infoText;

      if (spot.mediaSrc != null) {
        final lower = spot.mediaSrc!.toLowerCase();
        if (lower.endsWith('.jpg') ||
            lower.endsWith('.png') ||
            lower.endsWith('.jpeg')) {
          final f = File(spot.mediaSrc!);
          if (f.existsSync()) {
            thumbWidget = Image.file(f, fit: BoxFit.contain);
          } else if (spot.mediaSrc!.startsWith('http')) {
            thumbWidget = Image.network(spot.mediaSrc!, fit: BoxFit.contain);
          }
        } else if (lower.endsWith('.txt')) {
          final f = File(spot.mediaSrc!);
          if (f.existsSync()) {
            infoText = f.readAsStringSync().trim();
          }
        }
      }

      final Widget contentWidget;
      if (infoText != null && infoText.isNotEmpty) {
        contentWidget = Text(
          infoText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.0,
            height: 1.3,
          ),
        );
      } else if (thumbWidget != null) {
        contentWidget = thumbWidget;
      } else if (spot.label != null && spot.label!.isNotEmpty) {
        contentWidget = Text(
          spot.label!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.0,
          ),
        );
      } else {
        contentWidget = const SizedBox.shrink();
      }

      Widget finalWidget = contentWidget;
      if (contentWidget is! SizedBox &&
          spot.backgroundColor != null &&
          spot.backgroundColor != Colors.transparent) {
        finalWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          color: spot.backgroundColor,
          child: contentWidget,
        );
      }

      widgets.add(
        Positioned(
          left: left,
          top: top,
          child: GestureDetector(
            onTap: () => _handleHotspotTap(spot),
            child: finalWidget,
          ),
        ),
      );
    }

    return widgets;
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            '360 Media Error: $_errorMessage',
            style: const TextStyle(color: Colors.redAccent, fontSize: 14.0),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Listener(
          onPointerSignal: _handlePointerSignal,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: _handlePanUpdate,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                if (_isVideo)
                  _buildVideoPanorama(size)
                else
                  CustomPaint(
                    painter: EquirectangularPainter(
                      image: _loadedImage,
                      yaw: yaw,
                      pitch: pitch,
                      roll: roll,
                      fov: fieldOfView,
                    ),
                  ),
                ..._buildHotspotsWidgets(size),
                Positioned(
                  left: 8.0,
                  bottom: 8.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      '360° | Yaw: ${yaw.toStringAsFixed(1)}° | Pitch: ${pitch.toStringAsFixed(1)}° | FoV: ${fieldOfView.toStringAsFixed(1)}°',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.0,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class EquirectangularPainter extends CustomPainter {
  final ui.Image? image;
  final double yaw;
  final double pitch;
  final double roll;
  final double fov;

  EquirectangularPainter({
    required this.image,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.fov,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) {
      final bgPaint = Paint()..color = const Color(0xFF101015);
      canvas.drawRect(Offset.zero & size, bgPaint);
      _drawGrid(canvas, size);
      return;
    }

    final img = image!;
    final imgW = img.width.toDouble();
    final imgH = img.height.toDouble();

    final visibleNormalizedW = (fov / 360.0).clamp(0.1, 1.0);
    final visibleNormalizedH = (fov / 180.0).clamp(0.1, 1.0);

    final normYaw = ((yaw % 360.0) + 360.0) % 360.0 / 360.0;
    final normPitch = ((-pitch + 90.0).clamp(0.0, 180.0)) / 180.0;

    final srcCenterX = normYaw * imgW;
    final srcCenterY = normPitch * imgH;

    final srcW = visibleNormalizedW * imgW;
    final srcH = visibleNormalizedH * imgH;

    final srcLeft = srcCenterX - srcW / 2.0;
    final srcTop = (srcCenterY - srcH / 2.0).clamp(0.0, imgH - srcH);

    final destRect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (srcLeft < 0) {
      final leftPartWidth = -srcLeft;
      final rightPartWidth = srcW - leftPartWidth;

      final src1 =
          Rect.fromLTWH(imgW - leftPartWidth, srcTop, leftPartWidth, srcH);
      final dest1 = Rect.fromLTWH(
        0,
        0,
        size.width * (leftPartWidth / srcW),
        size.height,
      );
      canvas.drawImageRect(img, src1, dest1, Paint());

      final src2 = Rect.fromLTWH(0, srcTop, rightPartWidth, srcH);
      final dest2 = Rect.fromLTWH(
        dest1.width,
        0,
        size.width * (rightPartWidth / srcW),
        size.height,
      );
      canvas.drawImageRect(img, src2, dest2, Paint());
    } else if (srcLeft + srcW > imgW) {
      final leftPartWidth = imgW - srcLeft;
      final rightPartWidth = srcW - leftPartWidth;

      final src1 = Rect.fromLTWH(srcLeft, srcTop, leftPartWidth, srcH);
      final dest1 = Rect.fromLTWH(
        0,
        0,
        size.width * (leftPartWidth / srcW),
        size.height,
      );
      canvas.drawImageRect(img, src1, dest1, Paint());

      final src2 = Rect.fromLTWH(0, srcTop, rightPartWidth, srcH);
      final dest2 = Rect.fromLTWH(
        dest1.width,
        0,
        size.width * (rightPartWidth / srcW),
        size.height,
      );
      canvas.drawImageRect(img, src2, dest2, Paint());
    } else {
      final srcRect = Rect.fromLTWH(srcLeft, srcTop, srcW, srcH);
      canvas.drawImageRect(img, srcRect, destRect, Paint());
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF2E3345)
      ..strokeWidth = 1.0;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var x = 0.0; x < size.width; x += 40.0) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 40.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    textPainter.text = TextSpan(
      text:
          '360 Panoramic Viewport (Equirectangular Projection)\nYaw: ${yaw.toStringAsFixed(1)}° | Pitch: ${pitch.toStringAsFixed(1)}° | FoV: ${fov.toStringAsFixed(1)}°',
      style: const TextStyle(color: Color(0xFF8892B0), fontSize: 13.0),
    );
    textPainter.layout(maxWidth: size.width - 32.0);
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2.0,
        (size.height - textPainter.height) / 2.0,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant EquirectangularPainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.roll != roll ||
        oldDelegate.fov != fov ||
        oldDelegate.image != image;
  }
}

class Ncl360ParserPlugin implements NclParserPlugin, PluginBase {
  @override
  PluginType get type => PluginType.experimental;

  @override
  String get targetTag => 'ncl360';

  @override
  Element? parseTag(XmlElement node, NclParser parser) {
    if (node.name.local != targetTag) return null;
    final mId = node.getAttribute('id') ?? 'scene360';
    final src = node.getAttribute('src') ?? '';
    final media = Media(rawAttributes: {
      'id': mId,
      'src': src,
      'type': 'application/x-ncl360',
      if (node.getAttribute('descriptor') != null)
        'descriptor': node.getAttribute('descriptor')!,
    });
    for (final child in node.findAllElements('media')) {
      final childId = child.getAttribute('id');
      if (childId != null && childId.isNotEmpty) {
        final area = Area(rawAttributes: {
          'id': childId,
          'label': child.getAttribute('descriptor') ?? childId,
        });
        area.parent = media;
        media.children.add(area);
      }
    }
    return media;
  }

  @override
  (Head, Body)? parseDocument(XmlElement root, NclParser parser) {
    if (root.name.local != targetTag) return null;

    final effectiveSrc =
        (parser.docUri != null && parser.docUri!.isScheme('file')
                ? parser.docUri!.toFilePath()
                : parser.docUri?.toString()) ??
            parser.document?.appSrc ??
            root.getAttribute('id') ??
            'scene.ncl360';

    final Head head = [];
    final reg = Region(rawAttributes: const {
      'id': 'rg_ncl360_root',
      'left': '0%',
      'top': '0%',
      'width': '100%',
      'height': '100%',
      'zIndex': '1',
    });
    final desc = Descriptor(rawAttributes: const {
      'id': 'desc_ncl360_root',
      'region': 'rg_ncl360_root',
    });
    head.add(reg);
    head.add(desc);

    final body = Context(rawAttributes: const {'id': 'body'});
    final port = Port(rawAttributes: const {
      'id': 'p_ncl360_root',
      'component': 'scene360_root',
    });
    port.parent = body;
    body.children.add(port);

    final sceneMedia = Media(rawAttributes: {
      'id': 'scene360_root',
      'src': effectiveSrc,
      'type': 'application/x-ncl360',
      'descriptor': 'desc_ncl360_root',
    });
    sceneMedia.parent = body;

    for (final child in root.findAllElements('media')) {
      final mId = child.getAttribute('id');
      if (mId != null && mId.isNotEmpty) {
        final area = Area(rawAttributes: {
          'id': mId,
          'label': child.getAttribute('descriptor') ?? mId,
        });
        area.parent = sceneMedia;
        sceneMedia.children.add(area);
      }
    }

    body.children.add(sceneMedia);
    return (head, body);
  }
}
