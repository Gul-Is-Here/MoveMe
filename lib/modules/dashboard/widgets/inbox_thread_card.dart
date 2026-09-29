import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/motion.dart';
import '../models/message_thread_model.dart';

/// One conversation row in the Inbox.
///
/// Deliberately shows only what a `conversations/{id}` document actually
/// carries: counterpart name, plate + colour, last message text, the time
/// of that message, resolved state, and whether it is unread. There is no
/// avatar image, presence, delivery receipt or message-type field in the
/// data model, so none of those are rendered — an initials avatar stands
/// in for the picture rather than a fake photo.
///
/// With [onMarkRead] set and the thread unread, swiping the row to the
/// right marks it read; the row springs back rather than leaving the list.
class InboxThreadCard extends StatelessWidget {
  const InboxThreadCard({super.key, required this.thread, this.onMarkRead});

  final MessageThreadModel thread;
  final VoidCallback? onMarkRead;

  /// The person on the other side: from the owner's Inbox that's whoever
  /// scanned the sticker; from the "Sent" list it's the car's owner.
  String get _counterpartName {
    if (thread.viewerRole == ThreadViewerRole.owner) return thread.scannerName;
    return thread.ownerName.isEmpty ? 'Car owner' : thread.ownerName;
  }

  @override
  Widget build(BuildContext context) {
    final unread = thread.unreadCount > 0;
    final card = Pressable(
      scale: 0.98,
      onTap: () => Get.toNamed(AppRoutes.chatThread, arguments: thread),
      child: _CardBody(thread: thread, name: _counterpartName, unread: unread),
    );

    if (!unread || onMarkRead == null) return card;

    return Dismissible(
      key: ValueKey('swipe-${thread.conversationId}'),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {DismissDirection.startToEnd: 0.3},
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        onMarkRead!();
        return false;
      },
      background: const _SwipeBackground(),
      child: card,
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.thread, required this.name, required this.unread});

  final MessageThreadModel thread;
  final String name;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppColors.surface,
        gradient: unread
            ? LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color.alphaBlend(accent.withValues(alpha: 0.09), AppColors.surface),
                  AppColors.surface,
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: unread ? accent.withValues(alpha: 0.4) : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: unread ? accent.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06),
            blurRadius: unread ? 20 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          children: [
            // Accent edge marking the row as unread (paired with the bold
            // text and the count, so it's never carried by colour alone).
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: unread ? 0 : -4,
              top: 18,
              bottom: 18,
              width: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ThreadAvatar(name: name, unread: unread, anonymous: thread.isAnonymous),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.fieldValue.copyWith(
                                  color: AppColors.ink,
                                  fontSize: 15.5,
                                  fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              thread.timeLabel,
                              style: AppTextStyles.caption.copyWith(
                                color: unread ? accent : AppColors.faint,
                                fontSize: 11.5,
                                fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Flexible(child: _PlateChip(thread: thread)),
                            if (thread.isResolved) ...[
                              const SizedBox(width: 6),
                              const _ResolvedChip(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                thread.lastMessagePreview.isEmpty
                                    ? 'No messages yet'
                                    : thread.lastMessagePreview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.subtitle.copyWith(
                                  color: unread ? AppColors.ink : AppColors.muted,
                                  fontSize: 13.5,
                                  height: 1.35,
                                  fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // No exit animation on purpose: once read, the
                            // count disappears in the same frame.
                            if (unread)
                              _UnreadBadge(count: thread.unreadCount)
                            else
                              Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.faint),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [AppColors.success, AppColors.success.withValues(alpha: 0.55)],
        ),
      ),
      padding: const EdgeInsets.only(left: 22),
      alignment: Alignment.centerLeft,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all_rounded, color: Colors.white, size: 22),
          SizedBox(width: 8),
          Text(
            'Mark as read',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

/// Initials on a gradient picked from the name, so each person keeps the
/// same colour across the list; unread threads get an accent ring.
class ThreadAvatar extends StatelessWidget {
  const ThreadAvatar({
    super.key,
    required this.name,
    required this.unread,
    required this.anonymous,
    this.size = 48,
  });

  final String name;
  final bool unread;
  final bool anonymous;
  final double size;

  static const _palettes = [
    [Color(0xFFFF8A5B), Color(0xFFE4572E)],
    [Color(0xFF5B9DFF), Color(0xFF3E6FB0)],
    [Color(0xFF34C3A0), Color(0xFF1F8A70)],
    [Color(0xFFB07CFF), Color(0xFF7C4DDB)],
    [Color(0xFFFFB547), Color(0xFFE08A12)],
    [Color(0xFFFF6F91), Color(0xFFD1456A)],
  ];

  /// Up to two initials from the counterpart's name. Anonymous scanners
  /// (the default for someone who messaged from the public web page
  /// without giving a name) get an icon instead of the letter "A", which
  /// would read as a real initial.
  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  List<Color> get _colors {
    if (anonymous) return const [Color(0xFF9A9A94), Color(0xFF6B6B66)];
    final hash = name.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff);
    return _palettes[hash % _palettes.length];
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: unread ? accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _colors,
          ),
        ),
        child: Center(
          child: anonymous
              ? Icon(Icons.person_outline_rounded, size: size * 0.42, color: Colors.white)
              : Text(
                  _initials,
                  style: AppTextStyles.fieldValue.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: size * 0.32,
                  ),
                ),
        ),
      ),
    );
  }
}

class _PlateChip extends StatelessWidget {
  const _PlateChip({required this.thread});

  final MessageThreadModel thread;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: thread.vehicleColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              thread.plateNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.overline.copyWith(color: AppColors.muted, letterSpacing: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolvedChip extends StatelessWidget {
  const _ResolvedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.successSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.successBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 11, color: AppColors.success),
          const SizedBox(width: 4),
          Text(
            'RESOLVED',
            style: AppTextStyles.overline.copyWith(
              color: AppColors.success,
              letterSpacing: 0.4,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The number of unread messages in this conversation, popping in when it
/// appears.
///
/// Conversations written before the per-message counters existed have only
/// the old boolean, which reads back as 1 — so those threads still show a
/// badge rather than silently losing it.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return Semantics(
      label: '$count unread message${count == 1 ? '' : 's'}',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: Container(
          constraints: const BoxConstraints(minWidth: 22),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [accent, AppColors.accentDeep]),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 8),
            ],
          ),
          child: Text(
            // Past 99 the exact number stops being useful and starts
            // stretching the row.
            count > 99 ? '99+' : '$count',
            textAlign: TextAlign.center,
            style: AppTextStyles.overline.copyWith(
              color: Colors.white,
              fontSize: 10.5,
              letterSpacing: 0,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
