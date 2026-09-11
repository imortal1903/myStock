import 'package:flutter/material.dart';

import '../../models/lote.dart';
import '../../../../core/extensions/quantidade_extensions.dart';
import '../../../../core/theme/color_palette.dart';

/// Tile de lote reaproveitado por Delete, Update e Detail.
class LoteTile extends StatelessWidget {
  final Lote lote;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  const LoteTile({
    super.key,
    required this.lote,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = (lote.numeroLote?.trim().isNotEmpty ?? false)
        ? lote.numeroLote!.trim()
        : 'Sem número';
    final borda = selected ? colors.danger : colors.divider;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borda, width: selected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.layers_outlined,
                    color: colors.onPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              // Expanded evita a largura infinita que causava o overflow.
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Qtd: ${lote.quantidade.formatada}  •  Val: ${lote.validadeFormatada}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}