import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/mlb_services.dart';
import '../../../models/game.dart';
import 'package:intl/intl.dart';

class MLBHeader extends StatefulWidget {
  const MLBHeader({super.key});

  @override
  State<MLBHeader> createState() => _MLBHeaderState();
}

class _MLBHeaderState extends State<MLBHeader> {
  final MLBService _mlbService = MLBService();
  List<Game>? _games;
  late ScrollController _scrollController;
  bool _isExpanded = true;
  bool _forceExpanded = false;
  double _scrollProgress = 0.0;

  // Constants for scroll behavior
  final double _expandedHeight = 300.0;
  final double _collapsedHeight = kToolbarHeight;
  final double _overscrollThreshold = 50.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _setupScrollController();
    _fetchGames();
  }

  void _setupScrollController() {
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        _scrollController.position.isScrollingNotifier
            .addListener(_onScrollingChanged);
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final double currentScroll = _scrollController.offset;
    final double scrollRange = _expandedHeight - _collapsedHeight;

    // Handle overscroll at the top
    if (currentScroll <= 0) {
      if (!_forceExpanded) {
        setState(() {
          _forceExpanded = true;
          _isExpanded = true;
          _scrollProgress = 0.0;
        });
      }
    } else {
      // Normal scroll behavior when not overscrolling
      setState(() {
        if (_forceExpanded) {
          // Only remove force expanded when scrolling down significantly
          if (currentScroll > scrollRange * 0.3) {
            // Increased threshold
            _forceExpanded = false;
          }
        }

        if (!_forceExpanded) {
          _scrollProgress = (currentScroll / scrollRange).clamp(0.0, 1.0);
          _isExpanded = currentScroll < scrollRange / 2;
        }
      });
    }
  }

  void _onScrollingChanged() {
    final isScrolling = _scrollController.position.isScrollingNotifier.value;
    // Can add additional scroll state related animations here
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchGames() async {
    try {
      final response = await _mlbService.getSchedule();
      final dates = response['dates'] as List;
      if (dates.isNotEmpty) {
        final games = dates
            .expand((date) => (date['games'] as List))
            .map((game) => Game.fromJson(game))
            .take(4)
            .toList();
        setState(() => _games = games);
      }
    } catch (e) {
      debugPrint('Error fetching games: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: _expandedHeight,
      collapsedHeight: _collapsedHeight,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        title: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _forceExpanded ? 0.0 : _scrollProgress.clamp(0.5, 1.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isExpanded) ...[
                const SizedBox(width: 8),
                Text(
                  'MLB',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ],
          ),
        ),
        background: _games == null
            ? const _LoadingHeader()
            : _AnimatedHeader(
                games: _games!,
                isExpanded: _isExpanded || _forceExpanded,
                expandProgress: 1 - _scrollProgress,
              ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingHeader extends StatelessWidget {
  const _LoadingHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}

class _AnimatedHeader extends StatelessWidget {
  final List<Game> games;
  final bool isExpanded;
  final double expandProgress;

  const _AnimatedHeader({
    required this.games,
    required this.isExpanded,
    required this.expandProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
      ),
      child: Stack(
        children: [
          _buildBackgroundPattern(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopBar(context),
                  if (isExpanded)
                    Expanded(child: _buildExpandedContent(context))
                  else
                    _buildCollapsedContent(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundPattern() {
    return Opacity(
      opacity: 0.05,
      child: SizedBox.expand(
        child: CustomPaint(
          painter: BaseballPatternPainter(),
        ),
      ),
    );
  }

   Widget _buildTopBar(BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // MLB Logo
        Image.asset(
          'assets/images/MLB_logo.png',
          height: 55, // Increased from previous size
          width: 110,  // Set width to maintain aspect ratio
          fit: BoxFit.contain,
        ),
        // Notification Icon
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.notifications_none,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    ),
  );
}


  Widget _buildExpandedContent(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: games.length,
      itemBuilder: (context, index) => _GameCard(
        game: games[index],
      ),
    );
  }

  Widget _buildCollapsedContent(BuildContext context) {
    final featuredGame = games.first;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _FeaturedGameCard(game: featuredGame),
    );
  }
}

class _GameCard extends StatelessWidget {
  final Game game;

  const _GameCard({
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTeamInfo(
                  logo: game.team1Logo,
                  name: game.team1,
                  score: game.score1,
                  alignment: CrossAxisAlignment.start,
                ),
                Column(
                  children: [
                    const Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.blue[100],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('h:mm a').format(game.gameDate),
                            style: TextStyle(
                              color: Colors.blue[100],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _buildTeamInfo(
                  logo: game.team2Logo,
                  name: game.team2,
                  score: game.score2,
                  alignment: CrossAxisAlignment.end,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('E, MMM d').format(game.gameDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        game.venue,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamInfo({
    required String logo,
    required String name,
    String? score,
    required CrossAxisAlignment alignment,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            width: 70,
            height: 70,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SvgPicture.network(logo),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: alignment == CrossAxisAlignment.start 
                ? TextAlign.left 
                : TextAlign.right,
          ),
          if (score != null) ...[
            const SizedBox(height: 4),
            Text(
              score,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeaturedGameCard extends StatelessWidget {
  final Game game;

  const _FeaturedGameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTeamColumn(
                  context,
                  game.team1Logo,
                  game.team1,
                  game.score1,
                ),
                Column(
                  children: [
                    const Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildTeamColumn(
                  context,
                  game.team2Logo,
                  game.team2,
                  game.score2,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamColumn(
    BuildContext context,
    String logo,
    String name,
    String? score,
  ) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: SvgPicture.network(logo),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (score != null)
          Text(
            score,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }
}

class _TeamSection extends StatelessWidget {
  final String teamLogo;
  final String teamName;
  final String? score;

  const _TeamSection({
    required this.teamLogo,
    required this.teamName,
    required this.score
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.network(teamLogo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teamName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (score != null)
                  Text(
                    score!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BaseballPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final stitchPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const ballSize = 40.0;
    const spacing = 80.0;

    for (double x = 0; x < size.width + ballSize; x += spacing) {
      for (double y = 0; y < size.height + ballSize; y += spacing) {
        canvas.drawCircle(
          Offset(x, y),
          ballSize / 2,
          paint,
        );

        final path = Path()
          ..moveTo(x - 10, y)
          ..quadraticBezierTo(x, y - 5, x + 10, y)
          ..moveTo(x - 10, y)
          ..quadraticBezierTo(x, y + 5, x + 10, y);

        canvas.drawPath(path, stitchPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
