import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../numero_celda_bloc.dart';

class MenuCasillaWidget extends StatefulWidget {
  final Widget child;
  final bool esInsertable;
  final NumeroCeldaBloc bloc;
  final VoidCallback? onTap;

  const MenuCasillaWidget({
    super.key,
    required this.child,
    required this.esInsertable,
    required this.bloc,
    this.onTap,
  });

  @override
  State<MenuCasillaWidget> createState() => _MenuCasillaWidgetState();
}

class _MenuCasillaWidgetState extends State<MenuCasillaWidget> {
  final GlobalKey _anclaKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: widget.esInsertable
          ? () {
              widget.onTap?.call();
              _mostrarMenu();
            }
          : null,
      child: KeyedSubtree(
        key: _anclaKey,
        child: widget.child,
      ),
    );
  }

  Future<void> _mostrarMenu() async {
    final renderObject = _anclaKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }

    final centroDeLaCasilla = renderObject.localToGlobal(
      renderObject.size.center(Offset.zero),
    );

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar selector de numero',
      barrierColor: Colors.transparent,
      pageBuilder: (dialogContext, _, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            const tamanoMenu = 190.0;
            final left = (centroDeLaCasilla.dx - tamanoMenu / 2).clamp(
              8.0,
              constraints.maxWidth - tamanoMenu - 8,
            );
            final top = (centroDeLaCasilla.dy - tamanoMenu / 2).clamp(
              8.0,
              constraints.maxHeight - tamanoMenu - 8,
            );

            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  child: _menuRadial(dialogContext),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _menuRadial(BuildContext dialogContext) {
    return SizedBox(
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var numero = 1; numero <= 6; numero++)
            _botonRadial(dialogContext, numero),
          IconButton(
            tooltip: 'Borrar',
            onPressed: () {
              widget.bloc.add(const NumeroCeldaBorrado());
              Navigator.of(dialogContext).pop();
            },
            icon: Icon(
              Icons.backspace_outlined,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonRadial(BuildContext dialogContext, int numero) {
    const radio = 66.0;
    final angulo = -math.pi / 2 + (numero - 1) * (math.pi * 2 / 6);

    return Transform.translate(
      offset: Offset(radio * math.cos(angulo), radio * math.sin(angulo)),
      child: SizedBox(
        width: 56,
        height: 56,
        child: TextButton(
          onPressed: () {
            widget.bloc.add(NumeroCeldaSeleccionado(numero));
            Navigator.of(dialogContext).pop();
          },
          style: TextButton.styleFrom(
            backgroundColor: const Color.fromRGBO(210, 210, 210, 0.72),
            foregroundColor: Colors.grey.shade900,
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            side: const BorderSide(
              color: Color.fromRGBO(120, 120, 120, 0.72),
              width: 2,
            ),
            elevation: 2,
          ),
          child: Text(
            numero.toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
