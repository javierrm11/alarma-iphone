# Pipo · alarma que no te deja seguir durmiendo

App de alarma personal para iPhone (iOS 26.1 o superior). Para apagarla hay que completar un reto, y si la apagas sin hacerlo vuelve a sonar cada pocos minutos.

Diseño: estilo **Compañeros**, gama **Caramelo**, con **Pipo** como personaje.

## Qué hace

- **Alarmas de verdad con AlarmKit**: suenan con el modo silencio, con Concentración y con el móvil bloqueado.
- **Retos para apagarla**, encadenables: andar pasos, escanear un código registrado, cuentas o una foto igual a una de referencia.
- **Respaldos**: si deslizas para detener sin hacer el reto, vuelve a sonar cada N minutos (2 por defecto, 15 veces).
- **¿Sigues despierto?**: a los 5 y a los 10 minutos de completar el reto. Si no respondes, vuelve a sonar.
- **Modo estricto**: en las 10 horas antes de que suene, apagar, borrar o cambiar la alarma pide 8 cuentas.
- **Progreso**: racha, minutos hasta completar el reto, respaldos que sonaron y accesorios de Pipo que se desbloquean con la racha.
- **Mensaje para mañana**: lo escribes por la noche y Pipo te lo enseña al completar el reto.
- **Aviso de caducidad**: lee la fecha de la firma y te avisa 2 días antes.

## Cómo se compila (sin Mac)

Cada `git push` a `main` lanza [.github/workflows/build-ipa.yml](.github/workflows/build-ipa.yml) en una máquina macOS de GitHub:

1. Genera el proyecto de Xcode con XcodeGen a partir de [project.yml](project.yml).
2. Compila sin firmar.
3. Empaqueta `Alarma.ipa` y lo publica en la release **latest** del repositorio (también queda como artefacto de la ejecución).

Si falla, en la pestaña **Actions** se puede descargar `xcodebuild-log` con el error.

## Cómo se instala

1. **Primera vez, desde Windows**: instala [Sideloadly](https://sideloadly.io) (con iTunes e iCloud descargados de la web de Apple, no de Microsoft Store). Conecta el iPhone, arrastra `Alarma.ipa` y entra con tu Apple ID.
2. En el iPhone: *Ajustes → Privacidad y seguridad → Modo de desarrollador* (activar) y *Ajustes → General → VPN y gestión de dispositivos* (confiar en tu Apple ID).
3. **Renovar cada 7 días**: con una Apple ID gratuita la firma caduca a la semana. Usa SideStore (renueva desde el propio iPhone) o vuelve a instalar con Sideloadly. **Si caduca, la alarma no suena.**

## Primer uso

1. Concede los permisos: **Alarmas** (imprescindible), Movimiento, Cámara y Avisos.
2. En **Retos**, registra un código de barras que esté lejos de la cama y, si quieres, una foto de referencia.
3. Crea la alarma con el **+**.
4. En **Ajustes → Probar alarma en 1 minuto** puedes comprobar que todo funciona: bloquea el móvil y espera.

Las primeras semanas, deja también una alarma del Reloj de Apple 10 minutos después, por si acaso.

## Estructura

```
Alarma/
  App/          Arranque, pestañas y pantallas a pantalla completa
  Alarm/        AlarmKit: programar alarmas y el botón "Hacer reto"
  Model/        Datos, guardado y lógica (respaldos, comprobaciones, rachas)
  Services/     Pasos, firma de la app, avisos, comparar fotos, permisos
  UI/           Tema Caramelo, Pipo y todas las pantallas
project.yml     Definición del proyecto para XcodeGen
```

## Límites conocidos

- La pantalla de la alarma con el móvil bloqueado la dibuja iOS; el diseño de Pipo aparece al pulsar **Hacer reto** o al abrir la app.
- Las alarmas principales se programan para los próximos 7 días y los respaldos para las próximas 26 horas. Se reprograman cada vez que abres la app, que es cada mañana al hacer el reto.
- Suena con el sonido de alarma del sistema (para sonidos propios hay que añadir archivos `.caf`).
- La tipografía es la redondeada del sistema (SF Rounded), parecida a Fredoka.
- Nada impide borrar la app o apagar el móvil.
