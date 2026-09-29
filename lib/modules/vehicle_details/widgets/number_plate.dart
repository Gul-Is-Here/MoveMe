import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// A stylised registration plate: always light with dark lettering like a
/// real plate (regardless of app theme), an accent "PK" band, and screw
/// heads. [compact] is the smaller variant used for previews.
class NumberPlate extends StatelessWidget {
  const NumberPlate({super.key, required this.plate, this.compact = false});

  final String plate;
  final bool compact;

  static const _plateInk = Color(0xFF16161A);
  static const _plateFace = Color(0xFFFBFAF6);

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final empty = plate.trim().isEmpty;
    final height = compact ? 40.0 : 58.0;
    final fontSize = compact ? 18.0 : 26.0;

    Widget screw() => Container(
      width: compact ? 4 : 5,
      height: compact ? 4 : 5,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFB9B6AE),
      ),
    );

    return Semantics(
      label: empty ? 'No registration number' : 'Registration number $plate',
      child: ExcludeSemantics(
        child: Container(
          height: height,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: _plateInk,
            borderRadius: BorderRadius.circular(compact ? 8 : 11),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: compact ? 10 : 20,
                offset: Offset(0, compact ? 4 : 10),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _plateFace,
              borderRadius: BorderRadius.circular(compact ? 6 : 9),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: compact ? 22 : 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [accent, AppColors.accentDeep],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      'PK',
                      style: AppTextStyles.overline.copyWith(
                        color: Colors.white,
                        fontSize: compact ? 8.5 : 10.5,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 14,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(height: compact ? 3 : 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            screw(),
                            SizedBox(width: compact ? 6 : 10),
                            Flexible(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Text(
                                  empty ? '— — —' : plate.toUpperCase(),
                                  key: ValueKey(plate),
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: AppTextStyles.headingLg.copyWith(
                                    color: empty
                                        ? const Color(0xFFB9B6AE)
                                        : _plateInk,
                                    fontSize: fontSize,
                                    height: 1,
                                    letterSpacing: compact ? 1.2 : 2,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: compact ? 6 : 10),
                            screw(),
                          ],
                        ),
                        SizedBox(height: compact ? 3 : 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
