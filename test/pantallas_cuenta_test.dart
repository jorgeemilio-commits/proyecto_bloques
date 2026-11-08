import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/cuenta/servicio_cuenta.dart';
import 'package:proyecto_bloques/main.dart';
import 'package:proyecto_bloques/pantallas/cuenta.dart';
import 'package:proyecto_bloques/pantallas/inicio_sesion.dart';
import 'ayudantes.dart';
import 'consola.dart';

Finder porLlave(String llave) => find.byKey(ValueKey(llave));

Future<void> tocar(WidgetTester tester, String llave) async {
  // Si el boton quedo abajo de la pantalla, primero se hace scroll hasta el.
  await tester.ensureVisible(porLlave(llave));
  await tester.pumpAndSettle();
  await tester.tap(porLlave(llave));
  await tester.pumpAndSettle();
}

String textoDe(WidgetTester tester, String llave) =>
    tester.widget<Text>(porLlave(llave)).data ?? '';

void main() {
  testWidgets(
    'iniciar sesion muestra el error y entra con la contraseña buena',
    (tester) async {
      final servicio = ServicioDeCuenta(cliente: servidorFalso());
      await servicio.crearCuenta('Ana', 'secreta123');
      var entro = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaInicioSesion(
            servicio: servicio,
            onSesionIniciada: () => entro = true,
          ),
        ),
      );

      await tester.enterText(porLlave('campo-usuario'), 'Ana');
      await tester.enterText(porLlave('campo-contrasena'), 'equivocada');
      await tocar(tester, 'boton-entrar');
      final error = textoDe(tester, 'mensaje-error');
      final entroConLaMala = entro;

      await tester.enterText(porLlave('campo-contrasena'), 'secreta123');
      await tocar(tester, 'boton-entrar');

      expect(error, 'Usuario o contraseña incorrectos.');
      expect(entroConLaMala, isFalse);
      expect(entro, isTrue);
      expect(servicio.usuario, 'Ana');
      mostrar('Con la mala: "$error"; con la buena entra como Ana.');
    },
  );

  testWidgets(
    'crear cuenta revisa la confirmacion y entra con la cuenta nueva',
    (tester) async {
      final servicio = ServicioDeCuenta(cliente: servidorFalso());
      var entro = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaInicioSesion(
            servicio: servicio,
            onSesionIniciada: () => entro = true,
          ),
        ),
      );
      await tocar(tester, 'ir-a-crear-cuenta');

      await tester.enterText(porLlave('campo-usuario'), 'Iñaki');
      await tester.enterText(porLlave('campo-contrasena'), 'contraseña1');
      await tester.enterText(porLlave('campo-confirmacion'), 'otra cosa');
      await tocar(tester, 'boton-crear-cuenta');
      final error = textoDe(tester, 'mensaje-error');

      await tester.enterText(porLlave('campo-confirmacion'), 'contraseña1');
      await tocar(tester, 'boton-crear-cuenta');

      expect(error, 'Las contraseñas no coinciden.');
      expect(entro, isTrue);
      expect(servicio.usuario, 'Iñaki');
      // Al crearla, la pantalla de crear cuenta se cierra.
      expect(porLlave('pantalla-crear-cuenta'), findsNothing);
      mostrar(
        'Confirmacion distinta: "$error"; luego crea y entra como Iñaki.',
      );
    },
  );

  testWidgets('cuenta: muestra el historial y cerrar sesion sale', (
    tester,
  ) async {
    final servicio = ServicioDeCuenta(cliente: servidorFalso());
    await servicio.crearCuenta('Ana', 'secreta123');
    await servicio.iniciarSesion('Ana', 'secreta123');
    var salio = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaCuenta(servicio: servicio, onSalir: () => salio = true),
      ),
    );
    await tester.pumpAndSettle();
    final nombre = textoDe(tester, 'nombre-usuario');
    final estadisticas = [
      textoDe(tester, 'partidas-jugadas'),
      textoDe(tester, 'partidas-ganadas'),
      textoDe(tester, 'porcentaje-victorias'),
    ];
    final veLaPartida = find.text('Luis').evaluate().isNotEmpty;

    await tocar(tester, 'boton-cerrar-sesion');

    expect(nombre, 'Ana');
    expect(estadisticas, ['3', '1', '33%']);
    expect(veLaPartida, isTrue);
    expect(salio, isTrue);
    expect(servicio.conSesion, isFalse);
    mostrar('Cuenta de $nombre: historial $estadisticas; cerrar sesion sale.');
  });

  testWidgets('cuenta: borrar pide la contraseña', (tester) async {
    final servicio = ServicioDeCuenta(cliente: servidorFalso());
    await servicio.crearCuenta('Ana', 'secreta123');
    await servicio.iniciarSesion('Ana', 'secreta123');
    var salio = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaCuenta(servicio: servicio, onSalir: () => salio = true),
      ),
    );

    await tocar(tester, 'boton-borrar-cuenta');
    await tester.enterText(porLlave('campo-contrasena-borrar'), 'equivocada');
    await tocar(tester, 'confirmar-borrar-cuenta');
    final error = textoDe(tester, 'mensaje-error');
    final salioConLaMala = salio;

    await tester.enterText(porLlave('campo-contrasena-borrar'), 'secreta123');
    await tocar(tester, 'confirmar-borrar-cuenta');

    expect(error, 'La contraseña no es correcta.');
    expect(salioConLaMala, isFalse);
    expect(salio, isTrue);
    expect(servicio.conSesion, isFalse);
    expect(porLlave('dialogo-borrar-cuenta'), findsNothing);
    mostrar('Borrar con la mala: "$error"; con la buena se borra y sale.');
  });

  testWidgets('la app: iniciar sesion -> menu -> cuenta -> cerrar sesion', (
    tester,
  ) async {
    final servicio = ServicioDeCuenta(cliente: servidorFalso());
    await servicio.crearCuenta('Ana', 'secreta123');
    await tester.pumpWidget(ProyectoBloquesApp(servicio: servicio));

    // Sin sesion, la app empieza en el inicio de sesion.
    final empiezaEnLogin = porLlave(
      'pantalla-inicio-sesion',
    ).evaluate().isNotEmpty;
    await tester.enterText(porLlave('campo-usuario'), 'Ana');
    await tester.enterText(porLlave('campo-contrasena'), 'secreta123');
    await tocar(tester, 'boton-entrar');
    final llegaAlMenu = porLlave('menu-principal').evaluate().isNotEmpty;

    await tocar(tester, 'boton-cuenta');
    await tocar(tester, 'boton-cerrar-sesion');

    expect(empiezaEnLogin, isTrue);
    expect(llegaAlMenu, isTrue);
    expect(porLlave('pantalla-inicio-sesion'), findsOneWidget);
    expect(porLlave('pantalla-cuenta'), findsNothing);
    expect(porLlave('menu-principal'), findsNothing);
    mostrar('Inicio de sesion -> menu -> cuenta -> cerrar sesion -> inicio.');
  });
}
