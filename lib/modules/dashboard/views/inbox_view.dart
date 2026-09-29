import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/bound_view.dart';
import '../../../app/widgets/dot_grid_background.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/shimmer.dart';
import '../controllers/inbox_controller.dart';
import '../models/message_thread_model.dart';
import '../widgets/inbox_thread_card.dart';

/// The resident's conversation list.
///
/// Ordering is not done here — `watchOwnerConversations` already returns
/// conversations by `lastMessageAt` descending, and it is a live Firestore
/// listener, so a new message re-sorts the list to the top on its own.
/// Search and filtering run over the summaries already in memory, so they
/// cost nothing per keystroke.
class InboxView extends BoundView<InboxController> {
  const InboxView({super.key});

  @override
  Widget buildWith(BuildContext context, InboxController controller) {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(child: _Header(controller: controller)),
        ),
        SliverPadding(
          // The bottom inset clears the floating nav dock, which the
          // dashboard lets content scroll behind.
          padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.paddingOf(context).bottom),
          sliver: Obx(() {
            if (controller.hasError.value) {
              return SliverToBoxAdapter(child: _ErrorState(controller: controller));
            }
            if (controller.isLoading.value) {
              return const SliverToBoxAdapter(child: _LoadingState());
            }

            final threads = controller.visibleThreads;
            final sent = controller.visibleSentThreads;

            if (threads.isEmpty && sent.isEmpty) {
              return SliverToBoxAdapter(
                child: controller.query.value.isNotEmpty || controller.filter.value != InboxFilter.all
                    ? const _NoMatchesState()
                    : const _EmptyState(),
              );
            }

            return SliverList(
              delegate: SliverChildListDelegate([
                if (threads.isNotEmpty && sent.isNotEmpty)
                  const _SectionLabel(icon: Icons.inbox_rounded, title: 'Received'),
                for (var i = 0; i < threads.length; i++) ...[
                  _row(controller, threads[i], i),
                  if (i != threads.length - 1) const SizedBox(height: 10),
                ],
                if (sent.isNotEmpty)
                  _SentSection(
                    hasInbox: threads.isNotEmpty,
                    children: [
                      for (var i = 0; i < sent.length; i++) ...[
                        _row(controller, sent[i], threads.length + i),
                        if (i != sent.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  ),
                if (threads.any((t) => t.unreadCount > 0) || sent.any((t) => t.unreadCount > 0))
                  const _SwipeHint(),
              ]),
            );
          }),
        ),
      ],
    );
  }

  /// Keyed by conversation, so a row keeps its state as the list re-sorts
  /// and only genuinely new conversations play the entrance.
  Widget _row(InboxController controller, MessageThreadModel thread, int index) {
    return RiseIn(
      key: ValueKey('row-${thread.viewerRole.name}-${thread.conversationId}'),
      order: index.clamp(0, 6) + 2,
      child: InboxThreadCard(
        thread: thread,
        onMarkRead: () => controller.markThreadRead(thread),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

/// Title, search/mark-all actions, the live unread status card, search,
/// and the filter bar. The filters map onto real conversation fields —
/// there is no mute/archive/pin flag in Firestore to filter on, so none
/// is offered.
class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final InboxController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RiseIn(
          order: 0,
          child: Obx(() {
            final unreadThreads = controller.unreadThreadCount;
            return Row(
              children: [
                Expanded(
                  child: Text(
                    'Inbox',
                    style: AppTextStyles.headingLg.copyWith(color: AppColors.ink, fontSize: 28),
                  ),
                ),
                if (unreadThreads > 0) ...[
                  _MarkAllReadButton(onTap: controller.markAllRead),
                  const SizedBox(width: 8),
                ],
                _SearchToggle(
                  active: controller.isSearching.value,
                  onTap: controller.toggleSearch,
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 14),
        RiseIn(order: 1, child: _StatusCard(controller: controller)),
        Obx(
          () => AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: controller.isSearching.value
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _SearchField(controller: controller),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
        const SizedBox(height: 14),
        RiseIn(order: 2, child: _FilterBar(controller: controller)),
      ],
    );
  }
}

class _MarkAllReadButton extends StatelessWidget {
  const _MarkAllReadButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return Pressable(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all_rounded, size: 16, color: accent),
            const SizedBox(width: 6),
            Text(
              'Mark all read',
              style: AppTextStyles.label.copyWith(
                color: accent,
                letterSpacing: 0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchToggle extends StatelessWidget {
  const _SearchToggle({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return Semantics(
      button: true,
      label: active ? 'Close search' : 'Search conversations',
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? accent.withValues(alpha: 0.12) : AppColors.surface,
            border: Border.all(color: active ? accent.withValues(alpha: 0.4) : AppColors.border),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween(begin: 0.75, end: 1.0).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              active ? Icons.close_rounded : Icons.search_rounded,
              key: ValueKey(active),
              size: 19,
              color: active ? accent : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The unread summary as a card: an accent gradient with a pulsing chat
/// icon while anything is waiting, a calm "caught up" card otherwise. The
/// pulse plays a few times whenever the unread count rises, then rests.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.controller});

  final InboxController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final unreadThreads = controller.unreadThreadCount;
      final unreadMessages = controller.unreadMessageCount;
      // Vehicles that actually have something unread — previously this
      // counted every vehicle, so "2 unread across 3 vehicles" could name
      // a vehicle with nothing waiting on it.
      final vehicleCount = controller.threads
          .where((t) => t.unreadCount > 0)
          .map((t) => t.plateNumber)
          .toSet()
          .length;
      final caughtUp = unreadThreads == 0;
      final summary = caughtUp
          ? "You're all caught up"
          : '$unreadMessages unread message${unreadMessages == 1 ? '' : 's'}'
                '${vehicleCount == 0 ? '' : ' across $vehicleCount vehicle${vehicleCount == 1 ? '' : 's'}'}';

      return _StatusCardBody(
        caughtUp: caughtUp,
        unreadMessages: unreadMessages,
        summary: summary,
      );
    });
  }
}

class _StatusCardBody extends StatefulWidget {
  const _StatusCardBody({
    required this.caughtUp,
    required this.unreadMessages,
    required this.summary,
  });

  final bool caughtUp;
  final int unreadMessages;
  final String summary;

  @override
  State<_StatusCardBody> createState() => _StatusCardBodyState();
}

class _StatusCardBodyState extends State<_StatusCardBody> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _started = false;

  void _play() {
    if (widget.caughtUp || MediaQuery.of(context).disableAnimations) return;
    _pulse.repeat(count: 3);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _play();
  }

  @override
  void didUpdateWidget(_StatusCardBody old) {
    super.didUpdateWidget(old);
    if (widget.unreadMessages > old.unreadMessages) _play();
    if (widget.caughtUp) _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final caughtUp = widget.caughtUp;
    final fg = caughtUp ? AppColors.ink : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: caughtUp ? AppColors.surface : null,
        gradient: caughtUp
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, AppColors.accentDeep],
              ),
        border: caughtUp ? Border.all(color: AppColors.border) : null,
        boxShadow: [
          BoxShadow(
            color: caughtUp ? Colors.black.withValues(alpha: 0.05) : accent.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (!caughtUp)
            const Positioned.fill(
              child: DotGridBackground(
                color: Colors.white,
                center: Alignment(0.9, 0),
                radius: 1.2,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 52,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) => CustomPaint(
                      painter: _PulsePainter(
                        progress: _pulse.isAnimating ? _pulse.value : 0,
                        color: Colors.white,
                      ),
                      child: child,
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: caughtUp
                              ? AppColors.success.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.2),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            caughtUp ? Icons.done_all_rounded : Icons.mark_chat_unread_rounded,
                            key: ValueKey(caughtUp),
                            size: 21,
                            color: caughtUp ? AppColors.success : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caughtUp ? 'INBOX ZERO' : 'NEEDS YOUR ATTENTION',
                        style: AppTextStyles.overline.copyWith(
                          color: caughtUp ? AppColors.success : Colors.white.withValues(alpha: 0.85),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.summary,
                        style: AppTextStyles.headingSm.copyWith(color: fg, fontSize: 16, height: 1.25),
                      ),
                      if (caughtUp) ...[
                        const SizedBox(height: 2),
                        Text(
                          'New messages from scans land here instantly.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ],
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

/// Two expanding rings, half a cycle apart.
class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final center = size.center(Offset.zero);
    for (final offset in const [0.0, 0.5]) {
      final p = (progress + offset) % 1;
      canvas.drawCircle(
        center,
        20 + p * 14,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.5 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) => old.progress != progress || old.color != color;
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.controller});

  final InboxController controller;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _focused ? accent : AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: _focused ? 0.16 : 0), blurRadius: 16),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 19, color: _focused ? accent : AppColors.faint),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                autofocus: true,
                onChanged: widget.controller.setQuery,
                cursorColor: accent,
                style: AppTextStyles.fieldValue.copyWith(color: AppColors.ink, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search name, plate or message',
                  hintStyle: AppTextStyles.subtitle.copyWith(color: AppColors.faint, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented All / Unread / Resolved control with a sliding highlight and
/// a live count per filter (conversations, not messages).
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller});

  final InboxController controller;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return Obx(() {
      final active = controller.filter.value;
      final all = [...controller.threads, ...controller.sentThreads];
      int countFor(InboxFilter f) => switch (f) {
        InboxFilter.all => all.length,
        InboxFilter.unread => all.where((t) => t.unreadCount > 0).length,
        InboxFilter.resolved => all.where((t) => t.isResolved).length,
      };
      const filters = InboxFilter.values;

      return Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segment = constraints.maxWidth / filters.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutBack,
                  left: filters.indexOf(active) * segment,
                  width: segment,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(colors: [accent, AppColors.accentDeep]),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final f in filters)
                      Expanded(
                        child: _FilterSegment(
                          label: switch (f) {
                            InboxFilter.all => 'All',
                            InboxFilter.unread => 'Unread',
                            InboxFilter.resolved => 'Resolved',
                          },
                          count: countFor(f),
                          selected: f == active,
                          onTap: () => controller.setFilter(f),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    });
  }
}

class _FilterSegment extends StatelessWidget {
  const _FilterSegment({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.muted;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: AppTextStyles.label.copyWith(
                    color: fg,
                    letterSpacing: 0,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                  child: Text(label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: AppTextStyles.overline.copyWith(
                      color: fg,
                      fontSize: 9.5,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List sections
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.yellow),
              const SizedBox(width: 7),
              Text(title, style: AppTextStyles.headingSm.copyWith(color: AppColors.ink, fontSize: 16)),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppTextStyles.caption.copyWith(color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}

class _SentSection extends StatelessWidget {
  const _SentSection({required this.hasInbox, required this.children});

  final bool hasInbox;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: hasInbox ? 28 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel(
            icon: Icons.send_rounded,
            title: 'Sent',
            subtitle: 'Conversations you started by messaging other cars.',
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swipe_right_alt_rounded, size: 16, color: AppColors.faint),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Swipe an unread conversation right to mark it read',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.faint, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading / empty / error
// ---------------------------------------------------------------------------

/// Mirrors the thread card's geometry so real rows drop in without a jump.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          for (var i = 0; i < 4; i++) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 48, height: 48, radius: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 120, height: 13),
                        SizedBox(height: 9),
                        ShimmerBox(width: 78, height: 18, radius: 8),
                        SizedBox(height: 9),
                        ShimmerBox(height: 11),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i != 3) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const _StateBlock(
      art: _ChatBubblesArt(),
      title: 'No messages yet',
      subtitle:
          "When someone scans your car's QR sticker, their message lands here — "
          'and anyone you message shows up under Sent.',
    );
  }
}

class _NoMatchesState extends StatelessWidget {
  const _NoMatchesState();

  @override
  Widget build(BuildContext context) {
    return const _StateBlock(
      art: _IconArt(icon: Icons.search_off_rounded),
      title: 'No conversations match',
      subtitle: 'Try a different name, plate number or word from the message.',
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.controller});

  final InboxController controller;

  @override
  Widget build(BuildContext context) {
    return _StateBlock(
      art: const _IconArt(icon: Icons.wifi_off_rounded),
      title: 'Unable to load messages',
      subtitle: 'Check your connection and try again.',
      action: Pressable(
        onTap: controller.retry,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.yellow, AppColors.accentDeep]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded, size: 17, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'Retry',
                style: AppTextStyles.buttonLabel.copyWith(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateBlock extends StatelessWidget {
  const _StateBlock({required this.art, required this.title, required this.subtitle, this.action});

  final Widget art;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return RiseIn(
      order: 0,
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            art,
            const SizedBox(height: 20),
            Text(title, style: AppTextStyles.headingSm.copyWith(color: AppColors.ink, fontSize: 17)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitle.copyWith(color: AppColors.muted, fontSize: 13, height: 1.45),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}

class _IconArt extends StatelessWidget {
  const _IconArt({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.yellow.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.yellow.withValues(alpha: 0.25)),
      ),
      child: Icon(icon, size: 32, color: AppColors.yellow),
    );
  }
}

/// Two chat bubbles gently bobbing out of phase — a few cycles, then rest.
class _ChatBubblesArt extends StatefulWidget {
  const _ChatBubblesArt();

  @override
  State<_ChatBubblesArt> createState() => _ChatBubblesArtState();
}

class _ChatBubblesArtState extends State<_ChatBubblesArt> with SingleTickerProviderStateMixin {
  late final _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.of(context).disableAnimations) _bob.repeat(count: 4);
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    Widget bubble({required bool mine, required double width}) => Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: mine ? LinearGradient(colors: [accent, AppColors.accentDeep]) : null,
        color: mine ? null : AppColors.surface,
        border: mine ? null : Border.all(color: AppColors.border),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: (mine ? accent : Colors.black).withValues(alpha: mine ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final w in mine ? [0.8, 0.5] : [0.9, 0.6]) ...[
            FractionallySizedBox(
              widthFactor: w,
              child: Container(
                height: 6,
                margin: const EdgeInsets.symmetric(vertical: 2.5),
                decoration: BoxDecoration(
                  color: mine ? Colors.white.withValues(alpha: 0.7) : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _bob,
        builder: (context, _) {
          final phase = _bob.value * 2 * math.pi;
          return SizedBox(
            width: 180,
            height: 118,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 6 + 5 * math.sin(phase),
                  child: bubble(mine: false, width: 118),
                ),
                Positioned(
                  right: 0,
                  top: 56 + 5 * math.sin(phase + math.pi),
                  child: bubble(mine: true, width: 104),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
