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
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animacion, _) {
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
                  child: _menuRadial(dialogContext, animacion),
                ),
              ],
            );
          },
        );
      },
      // La animacion la hace el propio menu (abanico), no el dialogo.
      transitionBuilder: (_, _, _, child) => child,
    );
  }

  // Cierra el menu solo si sigue abierto; evita cerrar la pantalla principal
  // si el usuario ya lo cerro tocando fuera durante el pulso.
  void _cerrarMenu(BuildContext dialogContext) {
    if (ModalRoute.of(dialogContext)?.isCurrent ?? false) {
      Navigator.of(dialogContext).pop();
    }
  }

  Widget _menuRadial(BuildContext dialogContext, Animation<double> animacion) {
    // Al abrir, los botones salen del centro con un pequeño rebote;
    // al cerrar, regresan al centro.
    final abanico = CurvedAnimation(
      parent: animacion,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    return SizedBox(
      width: 190,
      height: 190,
      child: AnimatedBuilder(
        animation: abanico,
        builder: (context, _) {
          final progreso = abanico.value;

          return Stack(
            alignment: Alignment.center,
            children: [
              for (var numero = 1; numero <= 6; numero++)
                _botonRadial(dialogContext, numero, progreso),
              Opacity(
                opacity: animacion.value,
                child: IconButton(
                  tooltip: 'Borrar',
                  onPressed: () {
                    widget.bloc.add(const NumeroCeldaBorrado());
                    _cerrarMenu(dialogContext);
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(40, 40, 40, 0.92),
                  ),
                  icon: Icon(
                    Icons.backspace_outlined,
                    color: Colors.grey.shade300,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _botonRadial(BuildContext dialogContext, int numero, double progreso) {
    const radio = 66.0;
    final angulo = -math.pi / 2 + (numero - 1) * (math.pi * 2 / 6);

    return Transform.translate(
      offset: Offset(
        radio * progreso * math.cos(angulo),
        radio * progreso * math.sin(angulo),
      ),
      child: Transform.scale(
        scale: 0.5 + 0.5 * progreso,
        child: Opacity(
          opacity: progreso.clamp(0.0, 1.0),
          child: _BotonNumero(
            numero: numero,
            onSeleccionado: () {
              widget.bloc.add(NumeroCeldaSeleccionado(numero));
              _cerrarMenu(dialogContext);
            },
          ),
        ),
      ),
    );
  }
}

// Boton circular de un numero que hace un pulso antes de confirmar la seleccion.
class _BotonNumero extends StatefulWidget {
  final int numero;
  final VoidCallback onSeleccionado;

  const _BotonNumero({required this.numero, required this.onSeleccionado});

  @override
  State<_BotonNumero> createState() => _BotonNumeroState();
}

class _BotonNumeroState extends State<_BotonNumero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  // Crece hasta 1.25 y regresa a su tamaño normal.
  late final Animation<double> _escala = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.25)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.25, end: 1.0)
          .chain(CurveTween(curve: Curves.easeIn)),
      weight: 1,
    ),
  ]).animate(_pulso);

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  Future<void> _seleccionar() async {
    // Ignora toques repetidos mientras el pulso esta en curso.
    if (_pulso.isAnimating) {
      return;
    }

    await _pulso.forward(from: 0);
    if (mounted) {
      widget.onSeleccionado();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _escala,
      child: SizedBox(
        width: 56,
        height: 56,
        child: TextButton(
          onPressed: _seleccionar,
          style: TextButton.styleFrom(
            backgroundColor: const Color.fromRGBO(40, 40, 40, 0.92),
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            side: const BorderSide(
              color: Color.fromRGBO(140, 140, 140, 0.8),
              width: 2,
            ),
            elevation: 2,
          ),
          child: Text(
            widget.numero.toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
