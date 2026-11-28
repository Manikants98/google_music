import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/song_model.dart';

export 'track_tile.dart';

/// Expressive squircle album artwork with fallback, dynamic glow, and responsive auto-sizing.
class M3EAlbumArt extends StatelessWidget {
  /// Image URL string.
  final String imageUrl;

  /// Default dimension when width or height is not explicitly provided.
  final double size;

  /// Optional explicit width override. Can be a fixed double, null, or [double.infinity] to fill parent width.
  final double? width;

  /// Optional explicit height override. If null, falls back to [size] or computed from [aspectRatio].
  final double? height;

  /// Optional aspect ratio (width / height).
  final double? aspectRatio;

  /// Corner radius (defaults to Google standard 4dp).
  final double radius;

  /// Optional shadow elevation.
  final double elevation;

  /// Optional accent glow color.
  final Color? glowColor;

  /// Creates M3E album art.
  const M3EAlbumArt({
    super.key,
    required this.imageUrl,
    this.size = 56,
    this.width,
    this.height,
    this.aspectRatio,
    this.radius = 4,
    this.elevation = 0,
    this.glowColor,
  });

  /// Builds an expressive, glowing vinyl disc placeholder styled with active dynamic theme colors.
  Widget _buildPlaceholder(
    BuildContext context,
    double effectiveWidth,
    double effectiveHeight,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = glowColor ?? colorScheme.primary;

    final double iconSize = (effectiveWidth * 0.18).clamp(20.0, 52.0);
    final double centerCircleSize = (effectiveWidth * 0.36).clamp(36.0, 100.0);
    final double outerCircleSize = (effectiveWidth * 0.68).clamp(64.0, 200.0);

    return Container(
      width: effectiveWidth,
      height: effectiveHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              accent.withValues(alpha: isDark ? 0.20 : 0.14),
              colorScheme.surfaceContainerHighest,
            ),
            Color.alphaBlend(
              accent.withValues(alpha: isDark ? 0.08 : 0.05),
              colorScheme.surfaceContainer,
            ),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (effectiveWidth >= 80)
            Container(
              width: outerCircleSize,
              height: outerCircleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: isDark ? 0.08 : 0.05),
              ),
            ),
          Container(
            width: centerCircleSize,
            height: centerCircleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: isDark ? 0.20 : 0.14),
              boxShadow: effectiveWidth >= 100
                  ? <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: isDark ? 0.25 : 0.15),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                Icons.music_note_rounded,
                size: iconSize,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double targetWidth = width ?? double.infinity;
        final double effectiveWidth;

        if (targetWidth == double.infinity) {
          /// Safely fill parent if width is bounded; fallback to [size] inside unconstrained Row/Flex.
          effectiveWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : size;
        } else {
          effectiveWidth = targetWidth;
        }

        final double effectiveHeight;
        if (height != null) {
          effectiveHeight = height!;
        } else if (aspectRatio != null && aspectRatio! > 0) {
          effectiveHeight = effectiveWidth / aspectRatio!;
        } else {
          effectiveHeight = size;
        }

        final BoxShadow? shadow = elevation > 0
            ? BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: elevation * 2,
                offset: Offset(0, elevation * 0.5),
              )
            : null;

        if (imageUrl.trim().isEmpty) {
          return Container(
            width: effectiveWidth,
            height: effectiveHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: shadow != null ? <BoxShadow>[shadow] : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: _buildPlaceholder(context, effectiveWidth, effectiveHeight),
            ),
          );
        }

        return Container(
          width: effectiveWidth,
          height: effectiveHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: shadow != null ? <BoxShadow>[shadow] : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: CachedNetworkImage(
              imageUrl: SongModel.getHighResThumbnail(imageUrl),
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildPlaceholder(
                context,
                effectiveWidth,
                effectiveHeight,
              ),
              errorWidget: (context, url, error) {
                final fallbackUrl = url.contains('hq720.jpg')
                    ? url.replaceAll('hq720.jpg', 'hqdefault.jpg')
                    : url;
                if (fallbackUrl != url) {
                  return CachedNetworkImage(
                    imageUrl: fallbackUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _buildPlaceholder(
                      context,
                      effectiveWidth,
                      effectiveHeight,
                    ),
                    errorWidget: (context, url, error) => _buildPlaceholder(
                      context,
                      effectiveWidth,
                      effectiveHeight,
                    ),
                  );
                }
                return _buildPlaceholder(
                  context,
                  effectiveWidth,
                  effectiveHeight,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Mini animated audio waveform bars for now-playing tiles.
class M3EWaveformBars extends StatefulWidget {
  /// Color of bouncing bars.
  final Color color;

  /// Creates waveform bars.
  const M3EWaveformBars({super.key, this.color = const Color(0xFFFF4E4E)});

  @override
  State<M3EWaveformBars> createState() => _M3EWaveformBarsState();
}

class _M3EWaveformBarsState extends State<M3EWaveformBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List<Widget>.generate(4, (index) {
            final t = (_anim.value + (index * 0.25)) % 1.0;
            final height =
                6.0 + 14.0 * (0.5 + 0.5 * (index % 2 == 0 ? t : 1.0 - t));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Shimmer container providing a pulsing gradient highlight across placeholder skeleton widgets.
class M3EShimmer extends StatefulWidget {
  /// The skeleton layout to animate.
  final Widget child;

  /// Optional base color for shimmer gradient.
  final Color? baseColor;

  /// Optional highlight color for shimmer sweep.
  final Color? highlightColor;

  /// Creates shimmer effect.
  const M3EShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<M3EShimmer> createState() => _M3EShimmerState();
}

class _M3EShimmerState extends State<M3EShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final base = widget.baseColor ?? colorScheme.surfaceContainerHigh;
    final highlight =
        widget.highlightColor ??
        Color.alphaBlend(colorScheme.onSurface.withValues(alpha: 0.16), base);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              colors: <Color>[base, highlight, base],
              stops: const <double>[0.1, 0.5, 0.9],
              transform: _SlidingGradientTransform(
                slidePercent: _controller.value,
              ),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Helper gradient transform sliding linear gradient smoothly across the screen width.
class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2 - 1),
      0.0,
      0.0,
    );
  }
}

/// Rounded skeleton placeholder box dynamically styled with active theme colors.
class M3ESkeletonBox extends StatelessWidget {
  /// Width dimension.
  final double? width;

  /// Height dimension.
  final double height;

  /// Corner radius.
  final double radius;

  /// Optional explicit color override (defaults to theme surfaceContainerHigh).
  final Color? color;

  /// Creates skeleton box.
  const M3ESkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 4,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? Theme.of(context).colorScheme.surfaceContainerHigh;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Full-screen expressive skeleton loader matching Google Music home layout and theme colors.
class HomeScreenSkeleton extends StatelessWidget {
  /// Creates home screen skeleton.
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: M3EShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                M3ESkeletonBox(
                  width: 110,
                  height: 11,
                  radius: 3,
                  color: colorScheme.surfaceContainerHigh,
                ),
                const SizedBox(height: 6),
                M3ESkeletonBox(
                  width: 150,
                  height: 22,
                  radius: 4,
                  color: colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: M3EShimmer(
              child: Column(
                children: List<Widget>.generate(5, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: <Widget>[
                        M3ESkeletonBox(
                          width: 42,
                          height: 42,
                          radius: 4,
                          color: colorScheme.surfaceContainerHigh,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              M3ESkeletonBox(
                                width: 160,
                                height: 14,
                                radius: 3,
                                color: colorScheme.surfaceContainerHigh,
                              ),
                              const SizedBox(height: 6),
                              M3ESkeletonBox(
                                width: 100,
                                height: 11,
                                radius: 3,
                                color: colorScheme.surfaceContainerHigh,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 26, 16, 14),
          child: M3EShimmer(
            child: M3ESkeletonBox(
              width: 160,
              height: 22,
              radius: 4,
              color: colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        SizedBox(
          height: 190,
          child: M3EShimmer(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    M3ESkeletonBox(
                      width: 136,
                      height: 136,
                      radius: 6,
                      color: colorScheme.surfaceContainerHighest,
                    ),
                    const SizedBox(height: 8),
                    M3ESkeletonBox(
                      width: 110,
                      height: 13,
                      radius: 3,
                      color: colorScheme.surfaceContainerHigh,
                    ),
                    const SizedBox(height: 4),
                    M3ESkeletonBox(
                      width: 70,
                      height: 11,
                      radius: 3,
                      color: colorScheme.surfaceContainerHigh,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 14),
          child: M3EShimmer(
            child: M3ESkeletonBox(
              width: 140,
              height: 20,
              radius: 4,
              color: colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: M3EShimmer(
              child: Column(
                children: List<Widget>.generate(3, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: <Widget>[
                        M3ESkeletonBox(
                          width: 42,
                          height: 42,
                          radius: 4,
                          color: colorScheme.surfaceContainerHigh,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              M3ESkeletonBox(
                                width: 150,
                                height: 14,
                                radius: 3,
                                color: colorScheme.surfaceContainerHigh,
                              ),
                              const SizedBox(height: 6),
                              M3ESkeletonBox(
                                width: 90,
                                height: 11,
                                radius: 3,
                                color: colorScheme.surfaceContainerHigh,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        M3ESkeletonBox(
                          width: 16,
                          height: 16,
                          radius: 4,
                          color: colorScheme.surfaceContainerHigh,
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Type of skeleton layout to display based on the active search filter.
enum SearchSkeletonType {
  /// Both songs and playlists preview skeleton.
  all,

  /// Full songs list skeleton.
  songs,

  /// Grid of playlists skeleton.
  playlists,
}

/// Search results skeleton loader styled with active theme colors.
class SearchScreenSkeleton extends StatelessWidget {
  /// Horizontal padding matching app standard.
  final double horizontalPadding;

  /// Layout type to display.
  final SearchSkeletonType type;

  /// Whether running in desktop mode.
  final bool isDesktop;

  /// Creates search screen skeleton.
  const SearchScreenSkeleton({
    super.key,
    this.horizontalPadding = 12.0,
    this.type = SearchSkeletonType.all,
    this.isDesktop = false,
  });

  Widget _buildSongRow(
    BuildContext context,
    ColorScheme colorScheme,
    int index,
    bool isLast,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: <Widget>[
          M3ESkeletonBox(
            width: 44,
            height: 44,
            radius: 8,
            color: colorScheme.surfaceContainerHigh,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                M3ESkeletonBox(
                  width: (index % 2 == 0) ? 160 : 130,
                  height: 13,
                  radius: 4,
                  color: colorScheme.surfaceContainerHigh,
                ),
                const SizedBox(height: 6),
                M3ESkeletonBox(
                  width: (index % 2 == 0) ? 95 : 75,
                  height: 10,
                  radius: 3,
                  color: colorScheme.surfaceContainerHigh,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          M3ESkeletonBox(
            width: 18,
            height: 18,
            radius: 9,
            color: colorScheme.surfaceContainerHigh,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistSkeletonCard(
    BuildContext context,
    ColorScheme colorScheme,
    int index, {
    double? width,
  }) {
    return SizedBox(
      width: width,
      child: M3EShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 1.0,
              child: M3ESkeletonBox(
                width: double.infinity,
                height: double.infinity,
                radius: 12,
                color: colorScheme.surfaceContainerHigh,
              ),
            ),
            const SizedBox(height: 8),
            M3ESkeletonBox(
              width: (index % 2 == 0) ? 100 : 80,
              height: 13,
              radius: 4,
              color: colorScheme.surfaceContainerHigh,
            ),
            const SizedBox(height: 5),
            M3ESkeletonBox(
              width: (index % 2 == 0) ? 65 : 50,
              height: 10,
              radius: 3,
              color: colorScheme.surfaceContainerHigh,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (type == SearchSkeletonType.playlists) {
      return GridView.builder(
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 120),
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isDesktop ? 4 : 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 14,
          childAspectRatio: isDesktop ? 0.8 : 0.75,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return _buildPlaylistSkeletonCard(context, colorScheme, index);
        },
      );
    }

    if (type == SearchSkeletonType.songs) {
      return ListView(
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 120),
        physics: const BouncingScrollPhysics(),
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: M3EShimmer(
              child: Column(
                children: List<Widget>.generate(8, (index) {
                  return _buildSongRow(context, colorScheme, index, index == 7);
                }),
              ),
            ),
          ),
        ],
      );
    }

    // Default: SearchSkeletonType.all
    return ListView(
      padding:
          EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 120),
      physics: const BouncingScrollPhysics(),
      children: <Widget>[
        // Songs section title skeleton
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: M3EShimmer(
            child: M3ESkeletonBox(
              width: 64,
              height: 16,
              radius: 4,
              color: colorScheme.surfaceContainerHighest,
            ),
          ),
        ),

        // Songs list container skeleton
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: M3EShimmer(
            child: Column(
              children: List<Widget>.generate(5, (index) {
                return _buildSongRow(context, colorScheme, index, index == 4);
              }),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Playlists section title skeleton
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: M3EShimmer(
            child: M3ESkeletonBox(
              width: 76,
              height: 16,
              radius: 4,
              color: colorScheme.surfaceContainerHighest,
            ),
          ),
        ),

        // Horizontal Playlists Cards skeleton
        SizedBox(
          height: 205,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (_, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _buildPlaylistSkeletonCard(
                context,
                colorScheme,
                index,
                width: 135,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Auto-scrolling marquee text that smoothly animates horizontally when text overflows available width.
class M3EMarqueeText extends StatefulWidget {
  /// The string of text to display.
  final String text;

  /// The text style to apply.
  final TextStyle? style;

  /// Pixels per second scrolling speed.
  final double velocity;

  /// Initial and loop pause duration at rest position.
  final Duration pauseDuration;

  /// Blank spacing between repeated copies in the continuous ticker.
  final double blankSpace;

  /// Creates a marquee text widget.
  const M3EMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.velocity = 25.0,
    this.pauseDuration = const Duration(milliseconds: 1800),
    this.blankSpace = 64.0,
  });

  @override
  State<M3EMarqueeText> createState() => _M3EMarqueeTextState();
}

class _M3EMarqueeTextState extends State<M3EMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _lastDistance = 0.0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant M3EMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _controller.stop();
      _controller.value = 0.0;
      _isAnimating = false;
      _lastDistance = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleAnimation(double distance) {
    if (!mounted) return;
    if (_isAnimating && (_lastDistance - distance).abs() < 1.0) return;

    _lastDistance = distance;
    _isAnimating = true;

    final travelMs = ((distance / widget.velocity) * 1000).round();
    final totalMs = widget.pauseDuration.inMilliseconds + travelMs;

    _controller.duration = Duration(milliseconds: totalMs);
    _controller.repeat();
  }

  void _stopAnimation() {
    if (_isAnimating) {
      _isAnimating = false;
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  Size _calculateTextSize(
    String text,
    TextStyle? style,
    TextScaler textScaler,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: textScaler,
    )..layout();
    return textPainter.size;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = defaultStyle.merge(widget.style);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        if (!availableWidth.isFinite) {
          return Text(
            widget.text,
            style: effectiveStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        final textScaler = MediaQuery.textScalerOf(context);
        final textSize = _calculateTextSize(
          widget.text,
          effectiveStyle,
          textScaler,
        );
        final textWidth = textSize.width;
        final textHeight = textSize.height > 0 ? textSize.height : 24.0;

        if (textWidth <= availableWidth) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _stopAnimation();
          });
          return Text(
            widget.text,
            style: effectiveStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        final distance = textWidth + widget.blankSpace;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scheduleAnimation(distance);
        });

        final travelMs = ((distance / widget.velocity) * 1000).round();
        final totalMs = widget.pauseDuration.inMilliseconds + travelMs;
        final pauseRatio = totalMs > 0
            ? widget.pauseDuration.inMilliseconds / totalMs
            : 0.0;

        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: <double>[0.0, 0.04, 0.94, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final offset = t <= pauseRatio
                  ? 0.0
                  : ((t - pauseRatio) / (1.0 - pauseRatio)) * distance;

              return SizedBox(
                width: availableWidth,
                height: textHeight,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 0.0,
                    maxWidth: double.infinity,
                    minHeight: textHeight,
                    maxHeight: textHeight,
                    child: Transform.translate(
                      offset: Offset(-offset, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(widget.text, style: effectiveStyle, maxLines: 1),
                          SizedBox(width: widget.blankSpace),
                          Text(widget.text, style: effectiveStyle, maxLines: 1),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
