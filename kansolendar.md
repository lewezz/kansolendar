Kansolendar — Fase 1: documentación y arquitectura

Quiero que trabajes como arquitecto de software senior especializado en aplicaciones nativas de macOS, Swift y seguridad/privacidad.

Vamos a construir una aplicación de calendario para macOS llamada Kansolendar.

Tu trabajo en esta fase NO es programar la aplicación.

Tu objetivo es analizar el proyecto y producir una documentación técnica completa de su arquitectura, de forma que posteriormente podamos utilizar esa documentación como base para implementar el proyecto de manera ordenada.

1. Objetivo del producto

Kansolendar será una aplicación de calendario nativa para macOS.

El objetivo principal del proyecto es:

Crear un calendario local, extremadamente privado, que funcione como una aplicación macOS convencional y que no dependa de servidores, cuentas, sincronización ni servicios externos.

La aplicación debe poder instalarse y ejecutarse como cualquier otra aplicación de macOS.

El resultado final será una aplicación .app nativa que pueda colocarse en /Applications y ejecutarse desde Finder, Dock o Spotlight.

No queremos una aplicación web empaquetada, Electron, Python, Node.js ni ningún runtime externo.

2. Stack tecnológico CERRADO

Estas decisiones están tomadas y NO debes sustituirlas salvo que encuentres un problema técnico crítico que haga inviable alguna de ellas.

Lenguaje

Swift 6

UI

SwiftUI

Persistencia

SQLite

ORM / capa de persistencia

No utilizar SwiftData inicialmente.

No introducir un ORM salvo que posteriormente exista una justificación técnica muy fuerte.

Criptografía

CryptoKit

Security / Keychain de macOS

No implementar criptografía propia.

Concurrencia

Swift Concurrency

async/await

actors cuando corresponda

Arquitectura

MVVM

Domain layer

Services

Repositories

Persistence layer

La arquitectura debe evitar sobreingeniería innecesaria.

Testing

Swift Testing

XCTest cuando sea necesario para determinadas integraciones

Build

Xcode

Swift Package Manager

Formato de intercambio

iCalendar / .ics

Red

Ninguna.

La aplicación no debe depender de Internet para funcionar.

Telemetría

Ninguna.

Analytics

Ninguno.

Backend

Ninguno.

Sincronización

Ninguna.

Dependencias externas

Cero inicialmente.

Priorizar siempre APIs nativas de Apple.

3. Requisito fundamental de privacidad

La privacidad no debe tratarse como una funcionalidad adicional.

Debe ser un principio arquitectónico.

La aplicación debe diseñarse bajo el principio:

Local-first, offline-only y privacy-by-design.

Debemos minimizar deliberadamente la superficie de ataque y la cantidad de componentes que pueden acceder a los datos.

No queremos depender de "confiar" en que un servidor no hará algo con los datos.

El diseño debe hacer que los datos permanezcan localmente en el dispositivo.

4. Modelo de amenazas

Antes de definir la arquitectura definitiva, crea un modelo de amenazas.

Analiza como mínimo:

atacante con acceso físico al Mac;

robo del Mac;

acceso a la cuenta de usuario de macOS;

copia de los archivos de la aplicación;

copia de la base de datos;

acceso a backups;

archivos temporales;

logs;

crash reports;

memory dumps;

swap;

archivos de configuración;

notificaciones;

Spotlight;

Quick Look;

permisos de macOS;

procesos externos;

malware con acceso al usuario;

malware con permisos adicionales;

acceso a Keychain;

ingeniería inversa;

extracción de información de la base de datos;

recuperación de archivos eliminados;

errores de implementación;

filtraciones accidentales de datos mediante debugging.

No hace falta resolver todos estos problemas en esta fase.

Clasifícalos y explica:

amenaza;

impacto;

probabilidad aproximada;

mitigación propuesta;

qué queda fuera del alcance;

qué decisiones arquitectónicas afectan a cada amenaza.

No inventes garantías de seguridad que macOS no pueda proporcionar.

5. Arquitectura

Diseña la arquitectura completa del proyecto.

Documenta claramente:

capas;

responsabilidades;

dependencias entre capas;

flujo de datos;

ciclo de vida de la aplicación;

gestión del estado;

persistencia;

seguridad;

manejo de errores;

concurrencia;

importación/exportación;

testing.

Quiero diagramas ASCII cuando sean útiles.

Por ejemplo:

UI
 │
 ▼
ViewModel
 │
 ▼
Domain / Services
 │
 ▼
Repositories
 │
 ▼
SQLite


Pero no asumas esta estructura literalmente: evalúala y modifícala si existe una arquitectura mejor dentro del stack definido.

6. Estructura del proyecto

Propón una estructura de carpetas/módulos razonable.

Por ejemplo:

Kansolendar/
├── App/
├── Features/
├── Domain/
├── Persistence/
├── Security/
├── Services/
├── UI/
└── Tests/


Pero analiza si esta organización es realmente adecuada.

Explica la responsabilidad de cada módulo.

También determina qué debería ser:

target principal;

Swift Package;

módulo interno;

componente independiente;

test target.

No crees una estructura excesivamente fragmentada.

7. Modelo de dominio

Diseña el modelo conceptual de:

Calendar

Event

Event recurrence

Reminder

Attendee, si procede

Location

Time zone

Date/time

Tags, si consideras que deben existir

Attachments, si consideras que deben existir

No implementes estos modelos.

Define:

entidades;

value objects;

relaciones;

invariantes;

identificadores;

reglas de negocio.

Presta especial atención a:

zonas horarias;

eventos de día completo;

eventos recurrentes;

cambios de horario;

DST;

calendarios gregorianos;

eventos que atraviesan medianoche;

eventos históricos;

fechas inválidas.

Si alguna funcionalidad debería quedar fuera del MVP, indícalo.

8. Base de datos SQLite

Diseña el esquema inicial de SQLite.

Documenta:

tablas;

columnas;

tipos;

claves primarias;

foreign keys;

índices;

constraints;

migraciones;

estrategia de versionado.

Incluye un diagrama ER textual.

Analiza especialmente:

cómo almacenar fechas;

cómo almacenar zonas horarias;

cómo representar recurrencias;

cómo evitar inconsistencias;

cómo buscar eventos eficientemente.

No escribas todavía las migraciones ni código SQL de producción.

9. Cifrado y almacenamiento seguro

Diseña una estrategia concreta para proteger los datos.

Analiza:

cifrado de la base de datos;

generación de claves;

almacenamiento de claves;

Keychain;

CryptoKit;

ciclo de vida de las claves;

desbloqueo;

bloqueo;

cambio de contraseña, si aplica;

recuperación;

pérdida de claves;

backups;

exportaciones;

archivos temporales.

Es muy importante distinguir:

protección del dispositivo mediante FileVault;

protección de la aplicación;

protección de la base de datos;

protección de las claves.

No afirmes que una capa sustituye a otra.

Si SQLite necesita una solución adicional para cifrado a nivel de base de datos, analiza las alternativas compatibles con nuestro requisito de cero dependencias externas y explica sus ventajas y limitaciones.

Si el requisito "SQLite cifrada" entra en conflicto con alguna decisión del stack, señálalo claramente en lugar de ocultarlo.

10. Keychain

Documenta exactamente qué secretos deberían vivir en Keychain.

Por ejemplo:

clave de cifrado;

secretos derivados;

tokens, si algún día existieran.

Pero recuerda:

Actualmente NO habrá cuentas, tokens ni sincronización.

Explica también qué elementos NO deberían guardarse en Keychain.

11. Privacidad del sistema

Analiza qué mecanismos de macOS pueden provocar filtraciones indirectas.

Como mínimo:

Spotlight;

Quick Look;

Notifications;

Recent Documents;

App state restoration;

crash reports;

logs;

temporary files;

clipboard;

screenshots;

accessibility;

backups;

autosave;

window state;

menu items.

Para cada uno:

riesgo;

comportamiento por defecto;

configuración recomendada;

si debemos deshabilitarlo;

limitaciones que macOS impone.

12. Permisos

La aplicación debe pedir el mínimo número de permisos posible.

Determina qué entitlements y permisos necesita realmente una aplicación de este tipo.

Partimos de:

La aplicación NO necesita acceso al calendario del sistema de Apple.

Es un calendario independiente.

Si para alguna funcionalidad futura fuera necesario un permiso adicional, documentarlo como futuro y no incorporarlo ahora.

13. Red

Quiero que analices cómo garantizar arquitectónicamente que la aplicación sea offline-only.

Determina:

si la aplicación necesita Network.framework;

si debe existir algún entitlement relacionado con red;

cómo evitar dependencias indirectas;

cómo auditar que ninguna dependencia haga networking;

cómo testear que la aplicación no realiza conexiones.

No añadas una capa de red "por si acaso".

14. Importación y exportación

Analiza el soporte .ics.

Define:

importación;

exportación;

validación;

errores;

eventos recurrentes;

zonas horarias;

caracteres especiales;

UID;

compatibilidad;

privacidad.

Todo debe funcionar localmente.

No necesitamos sincronización.

15. Backups

Analiza cómo debería comportarse la aplicación con:

Time Machine;

copias manuales;

duplicación de la base de datos;

exportaciones;

restauración.

Explica qué ocurre con las claves de cifrado cuando se restaura una copia.

Este apartado es importante porque cifrar una base de datos no sirve de mucho si accidentalmente dejamos una copia legible en otro archivo.

16. Gestión de errores y logs

Diseña una política de logging orientada a privacidad.

Regla general:

Nunca registrar contenido de eventos, títulos, notas, ubicaciones, asistentes ni otros datos personales.

Define:

qué se puede registrar;

qué no;

niveles de logging;

logging de desarrollo;

logging de producción;

manejo de errores.

17. Testing

Diseña una estrategia de testing.

Debe incluir:

Unit tests

Domain

fechas

recurrencias

validaciones

búsquedas

Persistence tests

CRUD

migraciones

integridad

concurrencia

Security tests

cifrado;

descifrado;

gestión de claves;

bloqueo;

corrupción de datos;

recuperación de errores.

Privacy tests

Especialmente:

ningún request de red;

ningún dominio externo;

ningún analytics SDK;

ningún dato sensible en logs;

ningún archivo temporal sensible innecesario.

UI tests

Para las funcionalidades críticas.

18. Distribución

Documenta posteriormente cómo debería convertirse el proyecto en:

Kansolendar.app


y potencialmente:

Kansolendar.dmg


Analiza:

code signing;

notarization;

sandbox;

entitlements;

distribución directa;

distribución mediante Mac App Store como posibilidad futura.

No necesitamos implementar esto todavía.

19. Seguridad del código

Analiza:

gestión de memoria;

Sendable;

actors;

aislamiento;

concurrencia;

acceso a SQLite;

race conditions;

validación de entradas;

corrupción de base de datos;

archivos .ics maliciosos;

ataques mediante datos importados.

El .ics debe considerarse input no confiable.

20. Decisiones y ADRs

Crea una sección de Architecture Decision Records.

Como mínimo, prepara ADRs para:

SwiftUI;

SQLite frente a SwiftData;

ausencia de backend;

ausencia de sincronización;

ausencia de analytics;

estrategia de cifrado;

Keychain;

arquitectura MVVM;

Swift Concurrency;

.ics.

Para cada ADR:

Context
Decision
Alternatives
Consequences
Status

21. Roadmap

Después de analizar la arquitectura, crea un roadmap por fases.

Por ejemplo:

Phase 0 — Architecture
Phase 1 — Project skeleton
Phase 2 — Persistence
Phase 3 — Domain
Phase 4 — Calendar UI
Phase 5 — Event management
Phase 6 — Security
Phase 7 — Import/export
Phase 8 — Privacy audit
Phase 9 — Testing
Phase 10 — Distribution


Pero no asumas estas fases sin analizarlas.

Define dependencias entre ellas.

22. MVP

Define claramente qué entra y qué NO entra en el primer MVP.

El MVP debe ser pequeño y funcional.

No debemos construir:

sincronización;

cuentas;

servidor;

colaboración;

funciones sociales;

integración con Google Calendar;

integración con Outlook;

integración con iCloud.

Si alguna de estas cosas aparece en la documentación, debe quedar explícitamente como fuera de alcance.

23. Documentación que debes crear

Quiero que produzcas, como mínimo:

docs/
├── architecture.md
├── security.md
├── privacy.md
├── threat-model.md
├── data-model.md
├── database.md
├── key-management.md
├── testing.md
├── distribution.md
├── roadmap.md
└── adr/
    ├── 0001-swiftui.md
    ├── 0002-sqlite.md
    ├── 0003-local-only.md
    ├── 0004-encryption.md
    └── ...


Puedes modificar esta estructura si encuentras una organización mejor.

24. Regla muy importante: NO CODIFICAR TODAVÍA

En esta fase:

NO implementes funcionalidades.

No quiero que empieces a crear:

vistas;

modelos Swift definitivos;

tablas de producción;

servicios;

criptografía;

migraciones;

UI;

tests de implementación.

La única excepción es si necesitas crear una estructura mínima de documentación para organizar el trabajo.

La prioridad absoluta ahora es:

pensar, analizar, cuestionar y documentar.

25. Cuestiona mis decisiones

No quiero que aceptes automáticamente todas mis decisiones.

Si detectas:

una contradicción;

una vulnerabilidad;

una limitación de macOS;

una API que no es adecuada;

un problema con SQLite;

una dificultad relacionada con cifrado;

una incompatibilidad con Swift 6;

una decisión que aumente innecesariamente la superficie de ataque;

debes señalarla explícitamente.

Pero no cambies el stack silenciosamente.

Utiliza una sección:

Open Questions / Architectural Concerns


y explica:

problema;

impacto;

alternativas;

recomendación técnica;

decisión pendiente.

26. Criterio de calidad

La arquitectura debe priorizar, en este orden:

Seguridad y privacidad.

Corrección de los datos.

Fiabilidad.

Mantenibilidad.

Simplicidad.

Rendimiento.

Funcionalidades.

No sacrifiques seguridad por comodidad.

Tampoco quiero sobreingeniería: una aplicación local de calendario no necesita una arquitectura de una gran plataforma distribuida.

27. Resultado final esperado

Cuando termines esta fase quiero poder leer la documentación y responder con claridad a estas preguntas:

¿Cómo está estructurada la aplicación?

¿Dónde viven los datos?

¿Cómo se cifran?

¿Dónde están las claves?

¿Qué puede acceder a los datos?

¿Qué permisos necesita?

¿Puede conectarse a Internet?

¿Qué ocurre si alguien copia la base de datos?

¿Qué ocurre con los backups?

¿Cómo funcionan las migraciones?

¿Cómo se representan los eventos?

¿Cómo se gestionan las recurrencias?

¿Cómo se importan/exportan calendarios?

¿Cómo se prueba la privacidad?

¿Cómo se distribuye el .app?

¿Qué queda fuera del MVP?

¿Qué decisiones arquitectónicas siguen abiertas?

Al terminar, presenta también un resumen ejecutivo con:

arquitectura propuesta;

principales riesgos;

decisiones tomadas;

decisiones pendientes;

roadmap;

siguiente paso recomendado.

No empieces a implementar la aplicación hasta que esta documentación esté completa y revisada.
